#ifndef _TG_COMMON_H_
#define _TG_COMMON_H_

#include <cstdint>
#include <type_traits>
#include "common_with_hls.h"

typedef uint8_t datatype_t;

static constexpr unsigned int TESTDATA_CAPTURE_BEFORE_END = 0xFFFFFFFE;
static constexpr unsigned int TESTDATA_CAPTURE_AFTER_END = 0xFFFFFFFF;

static constexpr uint8_t UNKNWON_TYPE       = 0;
static constexpr uint8_t IS_NATIVE_TYPE     = 1 << 0;
static constexpr uint8_t IS_ARRAY_TYPE      = 1 << 1;
static constexpr uint8_t IS_POINTER_TYPE    = 1 << 2;
static constexpr uint8_t IS_STRUCT_TYPE     = 1 << 3;

template<typename T>
static datatype_t get_datatype(const T& data) {
    datatype_t datatype = UNKNWON_TYPE;
    if (std::is_class<T>::value) {
        datatype |= IS_STRUCT_TYPE;
    }
    if (std::is_pointer<T>::value) {
        datatype |= IS_POINTER_TYPE;
    }
    if (std::is_array<T>::value) {
        datatype |= IS_ARRAY_TYPE;
    }
    if (std::is_fundamental<T>::value){
        datatype |= IS_NATIVE_TYPE;
    }

    return datatype;
}

#define CRC32_POLYNOMIAL 0xEDB88320

// Function to calculate CRC-32
static uint32_t crc32(const uint8_t *data, size_t length) {
    uint32_t crc = 0xFFFFFFFF; // Initial value
    for (size_t i = 0; i < length; i++) {
        crc ^= data[i]; // XOR byte into least significant byte of crc
        for (int j = 0; j < 8; j++) { // Process each bit
            if (crc & 1) {
                crc = (crc >> 1) ^ CRC32_POLYNOMIAL;
            } else {
                crc >>= 1;
            }
        }
    }
    return ~crc; // Final XOR value
}



#endif