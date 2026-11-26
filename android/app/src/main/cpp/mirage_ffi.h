#ifndef MIRAGE_FFI_H
#define MIRAGE_FFI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define MIRAGE_EXPORT __declspec(dllexport)
#else
#define MIRAGE_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/**
 * Configure the Cactus worker thread pool before loading weights.
 * Pass 0 for automatic core detection, or 4 on mobile to avoid contention.
 */
MIRAGE_EXPORT void mirage_set_threads(int threads);

/**
 * Load mirage.cact from a filesystem path into the Cactus 4.x runtime.
 * Returns 0 on success, negative error code on failure.
 */
MIRAGE_EXPORT int mirage_load_file(const char* model_path);

/**
 * Run Mirage vision inference on packed RGB24 pixels (width * height * 3 bytes).
 * Returns a heap-allocated UTF-8 JSON string (caller must free via mirage_free_string),
 * or NULL on fatal allocation error.
 */
MIRAGE_EXPORT char* mirage_describe_rgb(
    const uint8_t* rgb_bytes,
    int width,
    int height,
    const char* options_json,
    const char* language,
    const char* keywords
);

/**
 * Free a string returned by mirage_describe_rgb.
 */
MIRAGE_EXPORT void mirage_free_string(char* ptr);

/**
 * Returns 1 if Mirage weights are currently loaded, 0 otherwise.
 */
MIRAGE_EXPORT int mirage_is_loaded(void);

#ifdef __cplusplus
}
#endif

#endif  // MIRAGE_FFI_H
