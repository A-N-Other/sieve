#include <stdint.h>
#include <Python.h>

#include "hashes.h"

inline uint64_t fnv1a_64(char* bytestring, Py_ssize_t byteslen) {
    uint64_t hsh = 0xcbf29ce484222325, prime = 0x100000001b3;
    int i;
    for (i = 0; i < byteslen; i++) {
        hsh ^= bytestring[i];
        hsh *= prime;
    }
    return hsh;
}

inline uint64_t murmur2_64(char* bytestring, Py_ssize_t byteslen, uint64_t seed) {
    const uint64_t m = 0xc6a4a7935bd1e995;
    const int r = 47;
    uint64_t h = seed ^ (byteslen * m);
    const uint64_t* data = (const uint64_t *)bytestring;
    const uint64_t* end = data + (byteslen/8);
    while(data != end) {
        uint64_t k = *data++;
        k *= m;
        k ^= k >> r;
        k *= m;
        h ^= k;
        h *= m;
    }
    const uint8_t * data2 = (const uint8_t*)data;
    switch(byteslen & 7) {
        case 7: h ^= (uint64_t)(data2[6]) << 48;
        case 6: h ^= (uint64_t)(data2[5]) << 40;
        case 5: h ^= (uint64_t)(data2[4]) << 32;
        case 4: h ^= (uint64_t)(data2[3]) << 24;
        case 3: h ^= (uint64_t)(data2[2]) << 16;
        case 2: h ^= (uint64_t)(data2[1]) << 8;
        case 1: h ^= (uint64_t)(data2[0]);
              h *= m;
    };
    h ^= h >> r;
    h *= m;
    h ^= h >> r;
    return h;
}
