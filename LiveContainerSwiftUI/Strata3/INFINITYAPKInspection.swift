import Foundation

/// Read-only APK ZIP inventory. This deliberately does not extract or execute APK content.
struct INFINITYAPKInspection: Sendable {
    struct Entry: Sendable {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: UInt64
        let uncompressedSize: UInt64
    }

    enum InspectionError: LocalizedError {
        case unreadable
        case notZip
        case missingEndRecord
        case multiDiskArchive
        case zip64NotSupported
        case invalidDirectory
        case invalidEntry
        case encryptedEntry
        case unsafePath
        case tooManyEntries

        var errorDescription: String? {
            switch self {
            case .unreadable: return "The selected file could not be read."
            case .notZip: return "This file is not a valid ZIP-based APK archive."
            case .missingEndRecord: return "The APK ZIP end record is missing or damaged."
            case .multiDiskArchive: return "Multi-disk ZIP archives are not supported."
            case .zip64NotSupported: return "This APK uses ZIP64, which this inspector does not support yet."
            case .invalidDirectory: return "The APK central directory is invalid or truncated."
            case .invalidEntry: return "The APK contains a malformed ZIP directory entry."
            case .encryptedEntry: return "Encrypted ZIP entries are not supported in APK packages."
            case .unsafePath: return "The APK contains an unsafe archive path and was rejected."
            case .tooManyEntries: return "The APK contains too many entries for safe inspection."
            }
        }
    }

    let fileName: String
    let archiveBytes: UInt64
    let entries: [Entry]
    let hasManifest: Bool
    let dexFiles: [String]
    let nativeLibraries: [String]
    let detectedABIs: [String]
    let storedEntryCount: Int
    let deflatedEntryCount: Int
    let otherCompressionCount: Int
    let totalUncompressedBytes: UInt64

    var isStructurallyRecognizableAPK: Bool {
        hasManifest && !dexFiles.isEmpty
    }

    var summary: String {
        let manifest = hasManifest ? "AndroidManifest.xml found" : "AndroidManifest.xml missing"
        let dex = dexFiles.isEmpty ? "No DEX files found" : "\(dexFiles.count) DEX file(s)"
        let abis = detectedABIs.isEmpty ? "No native ABI folders found" : detectedABIs.joined(separator: ", ")
        return "\(manifest) · \(dex) · ABI: \(abis)"
    }

    static func inspect(url: URL) throws -> INFINITYAPKInspection {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true,
              let fileSize = values?.fileSize,
              fileSize >= 22 else {
            throw InspectionError.unreadable
        }

        // Memory mapping avoids eagerly copying large APKs into the app's heap.
        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw InspectionError.unreadable
        }
        guard data.count >= 22 else { throw InspectionError.notZip }

        func u16(_ offset: Int) -> UInt16? {
            guard offset >= 0, offset <= data.count - 2 else { return nil }
            return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }
        func u32(_ offset: Int) -> UInt32? {
            guard offset >= 0, offset <= data.count - 4 else { return nil }
            return UInt32(data[offset])
                | (UInt32(data[offset + 1]) << 8)
                | (UInt32(data[offset + 2]) << 16)
                | (UInt32(data[offset + 3]) << 24)
        }

        let signature: UInt32 = 0x06054b50
        let lowerBound = max(0, data.count - 65_557)
        var endRecord: Int?
        if data.count >= 22 {
            for offset in stride(from: data.count - 22, through: lowerBound, by: -1) {
                if u32(offset) == signature {
                    let commentLength = Int(u16(offset + 20) ?? UInt16.max)
                    if offset + 22 + commentLength == data.count {
                        endRecord = offset
                        break
                    }
                }
            }
        }
        guard let end = endRecord else { throw InspectionError.missingEndRecord }

        let diskNumber = u16(end + 4) ?? UInt16.max
        let directoryDisk = u16(end + 6) ?? UInt16.max
        let diskEntries = u16(end + 8) ?? UInt16.max
        let totalEntries = u16(end + 10) ?? UInt16.max
        let directorySize = u32(end + 12) ?? UInt32.max
        let directoryOffset = u32(end + 16) ?? UInt32.max

        guard diskNumber == 0, directoryDisk == 0, diskEntries == totalEntries else {
            throw InspectionError.multiDiskArchive
        }
        guard totalEntries != UInt16.max,
              directorySize != UInt32.max,
              directoryOffset != UInt32.max else {
            throw InspectionError.zip64NotSupported
        }
        guard totalEntries <= 50_000 else { throw InspectionError.tooManyEntries }

        let start = Int(directoryOffset)
        let length = Int(directorySize)
        guard start >= 0, length >= 0, start <= data.count,
              length <= data.count - start else {
            throw InspectionError.invalidDirectory
        }

        var cursor = start
        let directoryEnd = start + length
        var parsed: [Entry] = []
        parsed.reserveCapacity(Int(totalEntries))
        var stored = 0
        var deflated = 0
        var other = 0
        var totalUncompressed: UInt64 = 0

        for _ in 0..<Int(totalEntries) {
            guard cursor <= directoryEnd - 46,
                  u32(cursor) == 0x02014b50 else {
                throw InspectionError.invalidDirectory
            }
            let flags = u16(cursor + 8) ?? 0
            let method = u16(cursor + 10) ?? UInt16.max
            let compressed = UInt64(u32(cursor + 20) ?? UInt32.max)
            let uncompressed = UInt64(u32(cursor + 24) ?? UInt32.max)
            let nameLength = Int(u16(cursor + 28) ?? 0)
            let extraLength = Int(u16(cursor + 30) ?? 0)
            let commentLength = Int(u16(cursor + 32) ?? 0)
            let recordLength = 46 + nameLength + extraLength + commentLength
            guard nameLength > 0, recordLength >= 46,
                  cursor <= directoryEnd, recordLength <= directoryEnd - cursor else {
                throw InspectionError.invalidEntry
            }
            guard flags & 0x0001 == 0 else { throw InspectionError.encryptedEntry }

            let nameStart = cursor + 46
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            guard let path = String(data: nameData, encoding: .utf8) else {
                throw InspectionError.invalidEntry
            }
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.hasPrefix("/"),
                  !path.contains("\\"),
                  !components.contains(".."),
                  !path.unicodeScalars.contains(where: { $0.value == 0 }) else {
                throw InspectionError.unsafePath
            }

            if !path.hasSuffix("/") {
                parsed.append(Entry(path: path, compressionMethod: method,
                                    compressedSize: compressed, uncompressedSize: uncompressed))
                totalUncompressed = totalUncompressed.addingReportingOverflow(uncompressed).overflow
                    ? UInt64.max : totalUncompressed &+ uncompressed
                switch method {
                case 0: stored += 1
                case 8: deflated += 1
                default: other += 1
                }
            }
            cursor += recordLength
        }

        let manifest = parsed.contains { $0.path == "AndroidManifest.xml" }
        let dex = parsed.map(\.path).filter {
            $0 == "classes.dex" || ($0.hasPrefix("classes") && $0.hasSuffix(".dex"))
        }.sorted()
        let libraries = parsed.map(\.path).filter {
            $0.hasPrefix("lib/") && $0.hasSuffix(".so")
        }.sorted()
        let knownABIs = ["arm64-v8a", "armeabi-v7a", "armeabi", "x86_64", "x86"]
        let abis = knownABIs.filter { abi in
            libraries.contains { $0.hasPrefix("lib/\(abi)/") }
        }

        return INFINITYAPKInspection(
            fileName: url.lastPathComponent,
            archiveBytes: UInt64(data.count),
            entries: parsed,
            hasManifest: manifest,
            dexFiles: dex,
            nativeLibraries: libraries,
            detectedABIs: abis,
            storedEntryCount: stored,
            deflatedEntryCount: deflated,
            otherCompressionCount: other,
            totalUncompressedBytes: totalUncompressed
        )
    }
}
