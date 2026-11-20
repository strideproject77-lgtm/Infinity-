// Linux-only declaration shim for the C API imported by the app's Objective-C bridging header.
// Keep these signatures synchronized with INFINITYAPKArchive.h. The real Swift/C ABI is
// checked separately by the manual macOS iPhoneOS-SDK bridge smoke job.
@_silgen_name("infinity_apk_extract_entry")
func infinity_apk_extract_entry(
    _ archive: UnsafePointer<UInt8>?,
    _ archiveLength: Int,
    _ entryName: UnsafePointer<CChar>?,
    _ output: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    _ outputLength: UnsafeMutablePointer<Int>?
) -> Int32

@_silgen_name("infinity_apk_free")
func infinity_apk_free(_ pointer: UnsafeMutableRawPointer?)
