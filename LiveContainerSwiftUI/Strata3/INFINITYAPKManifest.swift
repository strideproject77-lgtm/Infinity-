import Foundation

struct INFINITYAPKManifest: Sendable {
    let packageName: String
    let versionName: String?
    let versionCode: UInt64?
    let applicationLabel: String?
    let applicationIconResource: UInt32?
    let launchActivity: String?

    enum ManifestError: LocalizedError {
        case notBinaryXML
        case malformedChunk
        case missingStringPool
        case invalidStringIndex
        case malformedAttribute
        case unsupportedEncoding

        var errorDescription: String? {
            switch self {
            case .notBinaryXML: return "AndroidManifest.xml is not Android binary XML."
            case .malformedChunk: return "The Android manifest contains an invalid or truncated chunk."
            case .missingStringPool: return "The Android manifest has no valid string pool."
            case .invalidStringIndex: return "The Android manifest references an invalid string."
            case .malformedAttribute: return "The Android manifest contains a malformed attribute."
            case .unsupportedEncoding: return "The Android manifest uses an unsupported string encoding."
            }
        }
    }

    private enum Value {
        case string(String)
        case integer(UInt32)
        case reference(UInt32)
        case other(UInt32)
    }

    static func decode(_ data: Data) throws -> INFINITYAPKManifest {
        guard data.count >= 8, readU16(data, 0) == 0x0003 else {
            throw ManifestError.notBinaryXML
        }
        let totalSize = Int(readU32(data, 4))
        guard totalSize >= 8, totalSize <= data.count else { throw ManifestError.malformedChunk }

        var strings: [String] = []
        var packageName: String?
        var versionName: String?
        var versionCode: UInt64?
        var label: String?
        var icon: UInt32?
        var currentActivity: String?
        var launchActivity: String?
        var inIntentFilter = false
        var hasMainAction = false
        var hasLauncherCategory = false
        var offset = 8
        var foundStringPool = false

        while offset < totalSize {
            guard offset <= totalSize - 8 else { throw ManifestError.malformedChunk }
            let type = readU16(data, offset)
            let headerSize = Int(readU16(data, offset + 2))
            let chunkSize = Int(readU32(data, offset + 4))
            guard headerSize >= 8, chunkSize >= headerSize,
                  offset <= totalSize, chunkSize <= totalSize - offset else {
                throw ManifestError.malformedChunk
            }

            if type == 0x0001 {
                strings = try parseStringPool(data, offset: offset, headerSize: headerSize, chunkSize: chunkSize)
                foundStringPool = true
            } else if type == 0x0102 {
                guard foundStringPool, headerSize >= 16, chunkSize >= 36 else {
                    throw ManifestError.malformedChunk
                }
                let nameIndex = Int(readU32(data, offset + 20))
                let elementName = try stringAt(strings, nameIndex)
                let attributeStart = Int(readU16(data, offset + 24))
                let attributeSize = Int(readU16(data, offset + 26))
                let attributeCount = Int(readU16(data, offset + 28))
                guard attributeSize >= 20, attributeCount <= 4096 else {
                    throw ManifestError.malformedAttribute
                }
                let attributesBase = offset + 16 + attributeStart
                guard attributesBase >= offset + headerSize,
                      attributesBase <= offset + chunkSize,
                      attributeCount <= (offset + chunkSize - attributesBase) / attributeSize else {
                    throw ManifestError.malformedAttribute
                }

                var attributes: [String: Value] = [:]
                for index in 0..<attributeCount {
                    let at = attributesBase + index * attributeSize
                    let attrName = try stringAt(strings, Int(readU32(data, at + 4)))
                    let rawIndex = readU32(data, at + 8)
                    let valueType = data[at + 15]
                    let valueData = readU32(data, at + 16)
                    let value: Value
                    if rawIndex != UInt32.max {
                        value = .string(try stringAt(strings, Int(rawIndex)))
                    } else {
                        switch valueType {
                        case 0x03: value = .string(try stringAt(strings, Int(valueData)))
                        case 0x01: value = .reference(valueData)
                        case 0x10, 0x11: value = .integer(valueData)
                        default: value = .other(valueData)
                        }
                    }
                    attributes[attrName] = value
                }

                switch elementName {
                case "manifest":
                    packageName = attributes["package"]?.stringValue
                    versionName = attributes["versionName"]?.stringValue
                    versionCode = attributes["versionCode"]?.uint64Value
                case "application":
                    label = attributes["label"]?.stringValue
                    icon = attributes["icon"]?.uint32Value
                case "activity", "activity-alias":
                    currentActivity = attributes["name"]?.stringValue
                case "intent-filter":
                    inIntentFilter = true
                    hasMainAction = false
                    hasLauncherCategory = false
                case "action":
                    if inIntentFilter, attributes["name"]?.stringValue == "android.intent.action.MAIN" {
                        hasMainAction = true
                    }
                case "category":
                    if inIntentFilter, attributes["name"]?.stringValue == "android.intent.category.LAUNCHER" {
                        hasLauncherCategory = true
                    }
                default:
                    break
                }
            } else if type == 0x0103 {
                guard headerSize >= 16, chunkSize >= 24 else { throw ManifestError.malformedChunk }
                let nameIndex = Int(readU32(data, offset + 20))
                let elementName = try stringAt(strings, nameIndex)
                if elementName == "intent-filter" {
                    if hasMainAction && hasLauncherCategory && launchActivity == nil {
                        launchActivity = currentActivity
                    }
                    inIntentFilter = false
                } else if elementName == "activity" || elementName == "activity-alias" {
                    currentActivity = nil
                }
            }
            offset += chunkSize
        }

        guard foundStringPool else { throw ManifestError.missingStringPool }
        guard let packageName, !packageName.isEmpty else { throw ManifestError.malformedAttribute }
        let resolvedActivity: String?
        if let launchActivity, launchActivity.hasPrefix(".") {
            resolvedActivity = packageName + launchActivity
        } else if let launchActivity, !launchActivity.contains(".") {
            resolvedActivity = packageName + "." + launchActivity
        } else {
            resolvedActivity = launchActivity
        }
        return INFINITYAPKManifest(packageName: packageName,
                                   versionName: versionName,
                                   versionCode: versionCode,
                                   applicationLabel: label,
                                   applicationIconResource: icon,
                                   launchActivity: resolvedActivity)
    }

    private static func parseStringPool(_ data: Data, offset: Int, headerSize: Int, chunkSize: Int) throws -> [String] {
        guard headerSize >= 28, chunkSize >= headerSize else { throw ManifestError.malformedChunk }
        let stringCount = Int(readU32(data, offset + 8))
        let styleCount = Int(readU32(data, offset + 12))
        let flags = readU32(data, offset + 16)
        let stringsStart = Int(readU32(data, offset + 20))
        guard stringCount <= 100_000, styleCount <= 100_000,
              stringsStart >= headerSize, stringsStart <= chunkSize,
              headerSize + (stringCount + styleCount) * 4 <= chunkSize else {
            throw ManifestError.malformedChunk
        }
        let utf8 = flags & 0x100 != 0
        var result: [String] = []
        result.reserveCapacity(stringCount)
        for index in 0..<stringCount {
            let relative = Int(readU32(data, offset + headerSize + index * 4))
            let position = offset + stringsStart + relative
            guard relative >= 0, position >= offset + stringsStart,
                  position < offset + chunkSize else { throw ManifestError.malformedChunk }
            if utf8 {
                let (_, p1) = try length8(data, position, limit: offset + chunkSize)
                let (byteLength, p2) = try length8(data, p1, limit: offset + chunkSize)
                guard p2 <= offset + chunkSize, byteLength <= offset + chunkSize - p2 else {
                    throw ManifestError.malformedChunk
                }
                guard let value = String(data: data.subdata(in: p2..<(p2 + byteLength)), encoding: .utf8) else {
                    throw ManifestError.unsupportedEncoding
                }
                result.append(value)
            } else {
                let (unitLength, p1) = try length16(data, position, limit: offset + chunkSize)
                let byteLength = unitLength.multipliedReportingOverflow(by: 2)
                guard !byteLength.overflow, p1 <= offset + chunkSize,
                      byteLength.partialValue <= offset + chunkSize - p1 else {
                    throw ManifestError.malformedChunk
                }
                var units: [UInt16] = []
                units.reserveCapacity(unitLength)
                for n in 0..<unitLength { units.append(readU16(data, p1 + n * 2)) }
                result.append(String(decoding: units, as: UTF16.self))
            }
        }
        return result
    }

    private static func length8(_ data: Data, _ offset: Int, limit: Int) throws -> (Int, Int) {
        guard offset < limit else { throw ManifestError.malformedChunk }
        let first = Int(data[offset])
        if first & 0x80 == 0 { return (first, offset + 1) }
        guard offset + 1 < limit else { throw ManifestError.malformedChunk }
        return (((first & 0x7f) << 8) | Int(data[offset + 1]), offset + 2)
    }

    private static func length16(_ data: Data, _ offset: Int, limit: Int) throws -> (Int, Int) {
        guard offset <= limit - 2 else { throw ManifestError.malformedChunk }
        let first = Int(readU16(data, offset))
        if first & 0x8000 == 0 { return (first, offset + 2) }
        guard offset <= limit - 4 else { throw ManifestError.malformedChunk }
        return (((first & 0x7fff) << 16) | Int(readU16(data, offset + 2)), offset + 4)
    }

    private static func stringAt(_ strings: [String], _ index: Int) throws -> String {
        guard index >= 0, index < strings.count else { throw ManifestError.invalidStringIndex }
        return strings[index]
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) |
        (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}

private extension INFINITYAPKManifest.Value {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        if case .reference(let value) = self { return String(format: "@0x%08x", value) }
        return nil
    }
    var uint64Value: UInt64? {
        if case .integer(let value) = self { return UInt64(value) }
        return nil
    }
    var uint32Value: UInt32? {
        if case .integer(let value) = self { return value }
        if case .reference(let value) = self { return value }
        return nil
    }
}
