#include "mirage_ffi.h"
#include "cactus.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_model_loaded = 0;

MIRAGE_EXPORT void mirage_set_threads(int threads) {
    cactus_set_threads(threads);
}

MIRAGE_EXPORT int mirage_load_file(const char* model_path) {
    if (model_path == NULL) {
        return -1;
    }

    FILE* fp = fopen(model_path, "rb");
    if (fp == NULL) {
        return -2;
    }

    if (fseek(fp, 0, SEEK_END) != 0) {
        fclose(fp);
        return -3;
    }

    long file_size = ftell(fp);
    if (file_size <= 0) {
        fclose(fp);
        return -4;
    }
    rewind(fp);

    uint8_t* buffer = (uint8_t*)malloc((size_t)file_size);
    if (buffer == NULL) {
        fclose(fp);
        return -5;
    }

    size_t read_bytes = fread(buffer, 1, (size_t)file_size, fp);
    fclose(fp);

    if (read_bytes != (size_t)file_size) {
        free(buffer);
        return -6;
    }

    int rc = cactus_load(buffer, (size_t)file_size);
    free(buffer);

    if (rc == 0) {
        g_model_loaded = 1;
    }
    return rc;
}

MIRAGE_EXPORT char* mirage_describe_rgb(
    const uint8_t* rgb_bytes,
    int width,
    int height,
    const char* options_json,
    const char* language,
    const char* keywords
) {
    if (!g_model_loaded || rgb_bytes == NULL || width <= 0 || height <= 0) {
        const char* err = "{\"error\":\"Mirage model is not loaded or invalid image buffer\"}";
        char* out = (char*)malloc(strlen(err) + 1);
        if (out != NULL) {
            strcpy(out, err);
        }
        return out;
    }

    const size_t buf_size = 1024 * 1024;  // 1 MB output JSON buffer
    char* out_buf = (char*)calloc(1, buf_size);
    if (out_buf == NULL) {
        return NULL;
    }

    const char* lang = (language != NULL && language[0] != '\0') ? language : "en";
    cactus_describe(
        rgb_bytes,
        width,
        height,
        options_json,
        lang,
        keywords,
        out_buf,
        buf_size
    );
    return out_buf;
}

MIRAGE_EXPORT void mirage_free_string(char* ptr) {
    if (ptr != NULL) {
        free(ptr);
    }
}

MIRAGE_EXPORT int mirage_is_loaded(void) {
    return g_model_loaded;
}
