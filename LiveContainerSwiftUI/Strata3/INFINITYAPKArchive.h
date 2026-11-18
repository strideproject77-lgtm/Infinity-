#ifndef INFINITY_APK_ARCHIVE_H
#define INFINITY_APK_ARCHIVE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Extract one named APK ZIP entry. Supports stored and raw-DEFLATE entries.
   The output is allocated by the function and must be released with
   infinity_apk_free(). Returns 0 on success, nonzero on malformed,
   unsupported, missing, oversized, or corrupt input. */
int infinity_apk_extract_entry(const uint8_t *archive, size_t archive_length,
                               const char *entry_name,
                               uint8_t **output, size_t *output_length);
void infinity_apk_free(void *pointer);

/* Safely stream one ZIP entry to a caller-controlled staging file. */
int infinity_apk_extract_entry_to_file(const char *archive_path,
                                       const char *entry_name,
                                       const char *output_path);

#ifdef __cplusplus
}
#endif

#endif
