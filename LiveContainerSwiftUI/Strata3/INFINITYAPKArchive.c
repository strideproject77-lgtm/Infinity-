#include "INFINITYAPKArchive.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

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


/* Stream one ZIP entry to disk so XAPK/APKS/APKM containers do not require
   allocating an entire embedded APK in memory. The caller supplies a private
   staging path; the output is removed on every failure. ZIP64 is rejected. */
int infinity_apk_extract_entry_to_file(const char *archive_path,
                                       const char *entry_name,
                                       const char *output_path) {
    if (!archive_path || !entry_name || !output_path) return 1;
    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) return 1;
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 22) { close(fd); return 1; }
    size_t length = (size_t)st.st_size;
    const uint8_t *data = (const uint8_t *)mmap(NULL, length, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (data == MAP_FAILED) return 1;

    int result = 1;
    size_t lower = length > 65557u ? length - 65557u : 0;
    size_t eocd = (size_t)-1;
    for (size_t p = length - 22;; --p) {
        if (apk_range(length, p, 22) && apk_u32(data + p) == APK_EOCD_SIGNATURE) {
            uint16_t comment = apk_u16(data + p + 20);
            if (apk_range(length, p, 22u + comment) && p + 22u + comment == length) {
                eocd = p; break;
            }
        }
        if (p == lower) break;
    }
    if (eocd == (size_t)-1) goto done;
    uint16_t disk = apk_u16(data + eocd + 4);
    uint16_t dir_disk = apk_u16(data + eocd + 6);
    uint16_t disk_entries = apk_u16(data + eocd + 8);
    uint16_t total_entries = apk_u16(data + eocd + 10);
    uint32_t dir_size = apk_u32(data + eocd + 12);
    uint32_t dir_offset = apk_u32(data + eocd + 16);
    if (disk || dir_disk || disk_entries != total_entries ||
        total_entries == 0xffffu || dir_size == 0xffffffffu ||
        dir_offset == 0xffffffffu ||
        !apk_range(length, dir_offset, dir_size)) goto done;

    size_t cursor = dir_offset, dir_end = cursor + dir_size;
    size_t wanted = strlen(entry_name);
    uint32_t local_offset = 0, compressed = 0, uncompressed = 0, expected_crc = 0;
    uint16_t method = 0, flags = 0;
    int found = 0;
    for (uint32_t i = 0; i < total_entries; ++i) {
        if (!apk_range(dir_end, cursor, 46) ||
            apk_u32(data + cursor) != APK_CENTRAL_SIGNATURE) goto done;
        uint16_t name_len = apk_u16(data + cursor + 28);
        uint16_t extra_len = apk_u16(data + cursor + 30);
        uint16_t comment_len = apk_u16(data + cursor + 32);
        size_t record = 46u + name_len + extra_len + comment_len;
        if (!name_len || !apk_range(dir_end, cursor, record)) goto done;
        if (name_len == wanted && memcmp(data + cursor + 46, entry_name, wanted) == 0) {
            flags = apk_u16(data + cursor + 8);
            method = apk_u16(data + cursor + 10);
            compressed = apk_u32(data + cursor + 20);
            uncompressed = apk_u32(data + cursor + 24);
            expected_crc = apk_u32(data + cursor + 16);
            local_offset = apk_u32(data + cursor + 42);
            found = 1; break;
        }
        cursor += record;
    }
    if (!found || (flags & 1u) || (method != 0 && method != 8) ||
        compressed == 0xffffffffu || uncompressed == 0xffffffffu ||
        uncompressed > 1024u * 1024u * 1024u ||
        !apk_range(length, local_offset, 30) ||
        apk_u32(data + local_offset) != APK_LOCAL_SIGNATURE) goto done;

    uint16_t local_flags = apk_u16(data + local_offset + 6);
    uint16_t local_method = apk_u16(data + local_offset + 8);
    uint16_t local_name = apk_u16(data + local_offset + 26);
    uint16_t local_extra = apk_u16(data + local_offset + 28);
    if ((local_flags & 1u) || local_method != method || local_name != wanted ||
        !apk_range(length, (size_t)local_offset + 30u, local_name) ||
        memcmp(data + (size_t)local_offset + 30u, entry_name, wanted) != 0) goto done;
    size_t input_offset = (size_t)local_offset + 30u + local_name + local_extra;
    if (!apk_range(length, input_offset, compressed)) goto done;

    FILE *out = fopen(output_path, "wb");
    if (!out) { result = 2; goto done; }
    uint32_t crc = (uint32_t)crc32(0L, Z_NULL, 0);
    uint64_t written = 0;
    uint8_t output[65536];
    if (method == 0) {
        if (compressed != uncompressed) { fclose(out); goto remove_output; }
        size_t offset = input_offset, remaining = compressed;
        while (remaining) {
            size_t chunk = remaining < sizeof(output) ? remaining : sizeof(output);
            if (fwrite(data + offset, 1, chunk, out) != chunk) { fclose(out); goto remove_output; }
            crc = (uint32_t)crc32(crc, data + offset, (uInt)chunk);
            offset += chunk; remaining -= chunk; written += chunk;
        }
    } else {
        z_stream stream;
        memset(&stream, 0, sizeof(stream));
        if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) { fclose(out); goto remove_output; }
        size_t consumed = 0;
        int status = Z_OK;
        while (status == Z_OK) {
            if (stream.avail_in == 0 && consumed < compressed) {
                size_t chunk = (compressed - consumed) < 65536u ? (compressed - consumed) : 65536u;
                stream.next_in = (Bytef *)(data + input_offset + consumed);
                stream.avail_in = (uInt)chunk;
                consumed += chunk;
            }
            stream.next_out = output;
            stream.avail_out = (uInt)sizeof(output);
            status = inflate(&stream, Z_NO_FLUSH);
            size_t produced = sizeof(output) - stream.avail_out;
            if (produced) {
                if (written + produced > uncompressed ||
                    fwrite(output, 1, produced, out) != produced) {
                    inflateEnd(&stream); fclose(out); goto remove_output;
                }
                crc = (uint32_t)crc32(crc, output, (uInt)produced);
                written += produced;
            }
            if (status == Z_BUF_ERROR && stream.avail_in == 0 && consumed == compressed) break;
            if (status != Z_OK && status != Z_STREAM_END) {
                inflateEnd(&stream); fclose(out); goto remove_output;
            }
        }
        int valid = status == Z_STREAM_END && written == uncompressed &&
                    stream.total_in == compressed;
        inflateEnd(&stream);
        if (!valid) { fclose(out); goto remove_output; }
    }
    if (fclose(out) != 0) goto remove_output;
    if (written != uncompressed || crc != expected_crc) goto remove_output;
    result = 0;
    goto done;

remove_output:
    unlink(output_path);
    result = 3;
done:
    munmap((void *)data, length);
    return result;
}
