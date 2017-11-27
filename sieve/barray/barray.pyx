# GY171127

#cython: language_level=3, boundscheck=False, wraparound=False, nonecheck=False

import array
import math
from cpython cimport array

from sieve.utils import canonical


__all__ = ['BArray', 'Bloom', 'CountingBloom']


cdef unsigned long long _fnv1a_64(bytes key, unsigned long long seed=0):
    ''' 64 bit Fowler–Noll–Vo 1a hash function modified to take a seed '''
    cdef:
        unsigned long long hashresult = 0xcbf29ce484222325
        unsigned long long fnv1a_prime = 0x100000001b3
        unsigned char c
    if seed:
        hashresult ^= seed
        hashresult *= fnv1a_prime
    for c in key:
        hashresult ^= c
        hashresult *= fnv1a_prime
    return hashresult


cdef class BArray(object):
    ''' A low level bitarray implementation '''

    cdef:
        unsigned long long [:] barray
        readonly unsigned long long size

    def __init__(self, unsigned long long size):
        cdef:
            array.array empty_barray = array.array('Q', [])
        self.size = size
        self.barray = array.clone(empty_barray, math.ceil(self.size / 64), zero=True)

    def __len__(self):
        return self.size

    cdef bint _get(self, unsigned long long index):
        cdef:
            unsigned long long word, mask
            unsigned char bit
        word = index // 64
        bit = index % 64
        mask = 1 << bit
        if self.barray[word] & mask:
            return True
        return False

    def __getitem__(self, index):
        return self._get(index)

    cdef void _set(self, unsigned long long index, bint value):
        cdef:
            unsigned long long word, mask
            unsigned char bit
        word = index // 64
        bit = index % 64
        mask = 1 << bit
        if value:
            self.barray[word] |= mask
        else:
            self.barray[word] &= ~mask

    def __setitem__(self, index, value):
        self._set(index, value)

    cpdef bint set_and_report(self, unsigned long long index, bint value):
        ''' Sets a bit, returning if already set as boolean'''
        cdef:
            unsigned long long word, mask
            unsigned char bit
        word = index // 64
        bit = index % 64
        mask = 1 << bit
        if value:
            if self.barray[word] & mask:
                return True
            self.barray[word] |= mask
            return False
        if not self.barray[word] & mask:
            return True
        self.barray[word] &= ~mask
        return False

    cdef unsigned long long _count(self, unsigned long long i):
        ''' 64 bit SWAR popcount '''
        i = i - ((i >> <unsigned char>1) & <unsigned long long>0x5555555555555555)
        i = (i & <unsigned long long>0x3333333333333333) + ((i >> <unsigned char>2) & <unsigned long long>0x3333333333333333)
        return ((((i + (i >> <unsigned char>4)) & <unsigned long long>0x0f0f0f0f0f0f0f0f) * <unsigned long long>0x0101010101010101) & <unsigned long long>0xffffffffffffffff) >> <unsigned char>56

    cpdef unsigned long long count(self):
        ''' Count number of set bits '''
        cdef:
            unsigned long long word, bitsset=0
        for word in self.barray:
            bitsset += self._count(word)
        return bitsset


cdef class Bloom(object):
    ''' Probabilistic set membership testing

    Speeds things up by using permutations of a single hash algorithm as per
    Kirsch & Mitzenmacher (doi:10.1007/11841036_42) '''

    cdef:
        readonly unsigned char k
        readonly unsigned long long size, added
        BArray barray

    def __init__(self, unsigned long long n, unsigned char k=4, double fpr=0.01):
        self.k = k
        self.size = self._calc_size(k, fpr, n)
        self.barray = BArray(self.size)
        self.added = 0

    def __len__(self):
        return self.size

    cdef Bloom _iadd(self, bytes key):
        cdef:
            unsigned long long hash1, hash2
            unsigned char i
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        for i in range(self.k):
            self.barray._set((hash1 + i * hash2) % self.size, True)
        self.added += 1
        return self

    def __iadd__(self, bytes key):
        return self._iadd(key)

    cpdef bint add_and_report(self, bytes key):
        ''' Add item to the filter, returning if already present as boolean '''
        cdef:
            unsigned long long hash1, hash2
            unsigned char i
            bint present=True
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        for i in range(self.k):
            if not self.barray.set_and_report((hash1 + i * hash2) % self.size, True):
                present = False
        self.added += 1
        return present

    cpdef void add_from(self, bytes bytestring, unsigned char kmerlen, unsigned long long step=1):
        cdef:
            unsigned long long hash1, hash2, i
            unsigned char j
            bytes key
        for i in range(0, len(bytestring) - kmerlen + 1, step):
            key = canonical(bytestring[i:i+kmerlen])
            hash1 = _fnv1a_64(key)
            hash2 = _fnv1a_64(key, hash1)
            for j in range(self.k):
                self.barray._set((hash1 + j * hash2) % self.size, True)
            self.added += 1

    cdef bint _contains(self, bytes key):
        cdef:
            unsigned long long hash1, hash2
            unsigned char i
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        for i in range(self.k):
            if not self.barray._get((hash1 + i * hash2) % self.size):
                return False
        return True

    def __contains__(self, bytes key):
        return self._contains(key)

    def _calc_size(self, k, fpr, n):
        ''' Calculate required size from the estimated number of entries `n`,
        number of hashes `k`, and the desired false positive rate `fpr` '''
        return math.ceil((math.log(k / fpr) / math.log(2, 2)) * n)

    def collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.k * self.added / self.size)) ** self.k

    def count(self):
        ''' Return the number of set bits in the filter '''
        return self.barray.count()


cdef class CountingBloom(object):
    ''' Probabilistic set membership testing with count estimation

    Speeds things up by using permutations of a single hash algorithm as per
    Kirsch & Mitzenmacher (doi:10.1007/11841036_42) '''

    cdef:
        unsigned char [:] barray
        readonly unsigned char k, bucketsize
        readonly unsigned long long size, added

    def __init__(self, unsigned long long n, unsigned char k=4, double fpr=0.01):
        cdef:
            array.array B = array.array('B', [])  # 1 byte (max 255)
        self.k = k
        self.size = self._calc_size(k, fpr, n)
        self.barray = array.clone(B, self.size, zero=True)
        self.added = 0
        self.bucketsize = 255

    def __len__(self):
        return self.size

    cdef CountingBloom _iadd(self, bytes key):
        cdef:
            unsigned long long hash1, hash2, pos
            unsigned char i
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        for i in range(self.k):
            pos = (hash1 + i * hash2) % self.size
            if self.barray[pos] != self.bucketsize:
                self.barray[pos] += 1
        self.added += 1
        return self

    def __iadd__(self, bytes key):
        return self._iadd(key)

    cpdef unsigned char add_and_report(self, bytes key):
        ''' Add item to the filter, returning its new count '''
        cdef:
            unsigned long long hash1, hash2, pos
            unsigned char i, count
        count = self.bucketsize
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        for i in range(self.k):
            pos = (hash1 + i * hash2) % self.size
            if self.barray[pos] != self.bucketsize:
                self.barray[pos] += 1
            if self.barray[pos] < count:
                count = self.barray[pos]
        self.added += 1
        return count

    cpdef void add_from(self, bytes bytestring, unsigned char kmerlen, unsigned long long step=1):
        cdef:
            unsigned long long hash1, hash2, i, pos
            unsigned char j
            bytes key
        for i in range(0, len(bytestring) - kmerlen + 1, step):
            key = canonical(bytestring[i:i+kmerlen])
            hash1 = _fnv1a_64(key)
            hash2 = _fnv1a_64(key, hash1)
            for j in range(self.k):
                pos = (hash1 + j * hash2) % self.size
                if self.barray[pos] != self.bucketsize:
                    self.barray[pos] += 1
            self.added += 1

    cdef bint _contains(self, bytes key):
        cdef:
            unsigned long long hash1, hash2
            unsigned char i
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        for i in range(self.k):
            if not self._get((hash1 + i * hash2) % self.size):
                return False
        return True

    def __contains__(self, bytes key):
        return self._contains(key)

    cdef unsigned char _get(self, bytes key):
        cdef:
            unsigned long long hash1, hash2, count, pos
            unsigned char i
        count = self.bucketsize
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        for i in range(self.k):
            pos = (hash1 + i * hash2) % self.size
            if not self.barray[pos]:
                return 0
            if self.barray[pos] < count:
                count = self.barray[pos]
        return count

    def __getitem__(self, bytes key):
        return self._get(key)

    def _calc_size(self, k, fpr, n):
        ''' Calculate required size from the estimated number of entries `n`,
        number of hashes `k`, and the desired false positive rate `fpr` '''
        return math.ceil((math.log(k / fpr) / math.log(2, 2)) * n)

    def collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.k * self.added / self.size)) ** self.k

    cpdef unsigned long long count(self):
        ''' Return the number of set buckets in the filter '''
        cdef:
            unsigned long long word, bucketsset=0
        for word in self.barray:
            if word:
                bucketsset += 1
        return bucketsset
