cmake_minimum_required(VERSION 3.22.1)
project(mirage_ffi LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

# Map Android ABI to Cactus 4.x prebuilt platform folder
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(CACTUS_PLATFORM "android-arm64")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(CACTUS_PLATFORM "android-armv7")
elseif(ANDROID_ABI STREQUAL "riscv64")
    set(CACTUS_PLATFORM "android-riscv64")
else()
    message(FATAL_ERROR "Unsupported Android ABI for Cactus Mirage: ${ANDROID_ABI}. Use arm64-v8a or armeabi-v7a.")
endif()

set(CACTUS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cactus/${CACTUS_PLATFORM}")

if(NOT EXISTS "${CACTUS_DIR}/libcactus.a" OR NOT EXISTS "${CACTUS_DIR}/cactus.h")
    message(FATAL_ERROR
        "Missing Cactus 4.x native runtime at ${CACTUS_DIR}. "
        "Run ./setup_and_build.sh to download libcactus.a and cactus.h from Cactus-Compute/cactus."
    )
endif()

add_library(cactus_static STATIC IMPORTED)
set_target_properties(cactus_static PROPERTIES
    IMPORTED_LOCATION "${CACTUS_DIR}/libcactus.a"
    INTERFACE_INCLUDE_DIRECTORIES "${CACTUS_DIR}"
)

add_library(mirage_ffi SHARED
    mirage_ffi.c
    mirage_ffi.h
)

target_include_directories(mirage_ffi PRIVATE "${CACTUS_DIR}")

# libcactus.a is built against libc++; link C++ standard library and math/log
target_link_libraries(mirage_ffi
    cactus_static
    c++_shared
    log
    m
    dl
)
