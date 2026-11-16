#include "INFINITYAPKArchive.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#define APK_MAX_ENTRY_BYTES (16u * 1024u * 1024u)
#define APK_EOCD_SIGNATURE 0x06054b50u
#define APK_CENTRAL_SIGNATURE 0x02014b50u
#define APK_LOCAL_SIGNATURE 0x04034b50u

static uint16_t apk_u16(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}
static uint32_t apk_u32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static int apk_range(size_t length, size_t offset, size_t amount) {
    return offset <= length && amount <= length - offset;
}
void infinity_apk_free(void *pointer) { free(pointer); }

int infinity_apk_extract_entry(const uint8_t *archive, size_t archive_length,
                               const char *entry_name,
                               uint8_t **output, size_t *output_length) {
    if (!archive || !entry_name || !output || !output_length) return 1;
    *output = NULL;
    *output_length = 0;
    if (archive_length < 22) return 1;

    size_t lower = archive_length > 65557u ? archive_length - 65557u : 0;
    size_t eocd = (size_t)-1;
    for (size_t p = archive_length - 22;; --p) {
        if (apk_range(archive_length, p, 22) &&
            apk_u32(archive + p) == APK_EOCD_SIGNATURE) {
            uint16_t comment = apk_u16(archive + p + 20);
            if (apk_range(archive_length, p, 22u + comment) &&
                p + 22u + comment == archive_length) {
                eocd = p;
                break;
            }
        }
        if (p == lower) break;
    }
    if (eocd == (size_t)-1) return 1;

    uint16_t disk = apk_u16(archive + eocd + 4);
    uint16_t directory_disk = apk_u16(archive + eocd + 6);
    uint16_t disk_entries = apk_u16(archive + eocd + 8);
    uint16_t total_entries = apk_u16(archive + eocd + 10);
    uint32_t directory_size = apk_u32(archive + eocd + 12);
    uint32_t directory_offset = apk_u32(archive + eocd + 16);
    if (disk || directory_disk || disk_entries != total_entries) return 2;
    if (total_entries == 0xffffu || directory_size == 0xffffffffu ||
        directory_offset == 0xffffffffu) return 3;
    if (!apk_range(archive_length, directory_offset, directory_size)) return 1;

    size_t cursor = directory_offset;
    size_t directory_end = cursor + directory_size;
    size_t wanted_length = strlen(entry_name);
    uint32_t local_offset = 0, compressed_size = 0, uncompressed_size = 0, expected_crc = 0;
    uint16_t method = 0, flags = 0;
    int found = 0;

    for (uint32_t i = 0; i < total_entries; ++i) {
        if (!apk_range(directory_end, cursor, 46) ||
            apk_u32(archive + cursor) != APK_CENTRAL_SIGNATURE) return 1;
        flags = apk_u16(archive + cursor + 8);
        uint16_t candidate_method = apk_u16(archive + cursor + 10);
        uint32_t candidate_compressed = apk_u32(archive + cursor + 20);
        uint32_t candidate_uncompressed = apk_u32(archive + cursor + 24);
        uint16_t name_length = apk_u16(archive + cursor + 28);
        uint16_t extra_length = apk_u16(archive + cursor + 30);
        uint16_t comment_length = apk_u16(archive + cursor + 32);
        size_t record_length = 46u + name_length + extra_length + comment_length;
        if (!name_length || !apk_range(directory_end, cursor, record_length)) return 1;
        const uint8_t *name = archive + cursor + 46;
        if (name_length == wanted_length &&
            memcmp(name, entry_name, wanted_length) == 0) {
            if (flags & 1u) return 4;
            if (candidate_compressed == 0xffffffffu ||
                candidate_uncompressed == 0xffffffffu) return 3;
            method = candidate_method;
            compressed_size = candidate_compressed;
            uncompressed_size = candidate_uncompressed;
            expected_crc = apk_u32(archive + cursor + 16);
            local_offset = apk_u32(archive + cursor + 42);
            found = 1;
            break;
        }
        cursor += record_length;
    }
    if (!found) return 5;
    if (uncompressed_size > APK_MAX_ENTRY_BYTES ||
        compressed_size > APK_MAX_ENTRY_BYTES) return 6;
    if (!apk_range(archive_length, local_offset, 30) ||
        apk_u32(archive + local_offset) != APK_LOCAL_SIGNATURE) return 1;

    uint16_t local_flags = apk_u16(archive + local_offset + 6);
    uint16_t local_method = apk_u16(archive + local_offset + 8);
    uint16_t local_name = apk_u16(archive + local_offset + 26);
    uint16_t local_extra = apk_u16(archive + local_offset + 28);
    if ((local_flags & 1u) || local_method != method ||
        local_name != wanted_length ||
        !apk_range(archive_length, (size_t)local_offset + 30u, local_name) ||
        memcmp(archive + (size_t)local_offset + 30u, entry_name, wanted_length) != 0) return 1;
    size_t data_offset = (size_t)local_offset + 30u + local_name + local_extra;
    if (!apk_range(archive_length, data_offset, compressed_size)) return 1;

    uint8_t *result = (uint8_t *)malloc(uncompressed_size ? uncompressed_size : 1u);
    if (!result) return 7;
    if (method == 0) {
        if (compressed_size != uncompressed_size) { free(result); return 1; }
        if (uncompressed_size) memcpy(result, archive + data_offset, uncompressed_size);
    } else if (method == 8) {
        z_stream stream;
        memset(&stream, 0, sizeof(stream));
        stream.next_in = (Bytef *)(archive + data_offset);
        stream.avail_in = (uInt)compressed_size;
        stream.next_out = result;
        stream.avail_out = (uInt)uncompressed_size;
        if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) { free(result); return 8; }
        int status = inflate(&stream, Z_FINISH);
        int valid = status == Z_STREAM_END &&
                    stream.total_out == uncompressed_size &&
                    stream.total_in == compressed_size;
        inflateEnd(&stream);
        if (!valid) { free(result); return 8; }
    } else {
        free(result);
        return 9;
    }
    if ((uint32_t)crc32(0L, result, (uInt)uncompressed_size) != expected_crc) {
        free(result);
        return 8;
    }
    *output = result;
    *output_length = uncompressed_size;
    return 0;
}
