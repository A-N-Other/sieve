# GY171117


import array
import math
from cpython cimport array

cimport cython


__all__ = ['BArray', 'Bloom', 'CountingBloom']


cdef unsigned long long _fnv1a_64(bytes key, unsigned long long seed=0):
    ''' 64 bit implementation of the Fowler–Noll–Vo 1a hash function modified
    to take a seed value '''
    cdef:
        unsigned long long hashresult = 0xcbf29ce484222325
        unsigned long long fnv1a_prime = 0x100000001b3
        char c
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
        self.barray = array.clone(empty_barray, math.ceil(size / 64), zero=True)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __getitem__(self, signed long long index):
        cdef:
            unsigned long long word, mask
            unsigned char bit
        word, bit = self._getindex(index)
        mask = 1 << bit
        if self.barray[word] & mask:
            return 1
        return 0

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __setitem__(self, signed long long index, bint value):
        cdef:
            unsigned long long word, mask
            unsigned char bit
        word, bit = self._getindex(index)
        mask = 1 << bit
        if value:
            self.barray[word] |= mask
        else:
            self.barray[word] &= ~mask

    def __len__(self):
        return self.size

    cdef _getindex(self, signed long long index):
        if index < 0:
            index += self.size
        if not 0 <= index < self.size:
            raise IndexError('Attempt to access out of bounds bit')
        return divmod(index, 64)

    cpdef set(self, signed long long index):
        ''' Sets a bit, returning if already set as boolean'''
        cdef:
            unsigned long long word, mask
            unsigned char bit
        word, bit = self._getindex(index)
        mask = 1 << bit
        if self.barray[word] & mask:
            return True
        self.barray[word] |= mask
        return False

    cpdef unset(self, signed long long index):
        ''' Unsets a bit, returning if already unset as boolean '''
        cdef:
            unsigned long long word, mask
            unsigned char bit
        word, bit = self._getindex(index)
        mask = 1 << bit
        if not self.barray[word] & mask:
            return True
        self.barray[word] &= ~mask
        return False

    cpdef blockset(self, signed long long index, unsigned long long mask):
        ''' Sets bits in a block, returning if already set as boolean '''
        cdef:
            unsigned long long word
            unsigned char bit
        word, bit = self._getindex(index)
        if (self.barray[word] & mask) == mask:
            return True
        self.barray[word] |= mask
        return False

    cpdef blockunset(self, signed long long index, unsigned long long mask):
        ''' Unsets bits in a block, returning if already unset as boolean '''
        cdef:
            unsigned long long word
            unsigned char bit
        word, bit = self._getindex(index)
        if not self.barray[word] & mask:
            return True
        self.barray[word] &= ~mask
        return False

    cdef unsigned long long _count(self, unsigned long long i):
        ''' 64 bit SWAR popcount '''
        i = i - ((i >> 1) & 0x5555555555555555)
        i = (i & 0x3333333333333333) + ((i >> 2) & 0x3333333333333333)
        return ((((i + (i >> 4)) & 0x0f0f0f0f0f0f0f0f) * 0x0101010101010101) & 0xffffffffffffffff) >> 56

    cpdef unsigned long long count(self):
        ''' Count number of set bits '''
        cdef:
            unsigned long long word
        return sum([self._count(word) for word in self.barray])


cdef class Bloom(object):
    ''' Probabilistic set membership testing'''

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

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __iadd__(self, bytes key):
        cdef:
            unsigned long long pos
        for pos in self._hasher(key):
            self.barray[pos] = 1
        self.added += 1
        return self

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __contains__(self, bytes key):
        cdef:
            unsigned long long pos
        return all(self.barray[pos] for pos in self._hasher(key))

    cdef tuple _hasher(self, bytes key):
        ''' Compute the bit indeces of a key for k hash functions, cheating by
        using permutations of a single hash algorithm, as per Kirsch &
        Mitzenmacher ... doi:10.1007/11841036_42 '''
        cdef:
            unsigned long long hash1, hash2
            unsigned char i
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        return tuple((hash1 + i * hash2) % self.size for i in range(self.k))

    cpdef bint add(self, bytes key):
        ''' Add item to the filter, returning if already present as boolean '''
        cdef:
            unsigned long long pos
        self.added += 1
        return all([self.barray.set(pos) for pos in self._hasher(key)])

    cdef unsigned long long _calc_size(self, unsigned char k, double fpr, unsigned long long n):
        ''' Calculate required size from the estimated number of entries `n`,
        number of hashes `k`, and the desired false positive rate `fpr` '''
        return math.ceil((math.log(k / fpr) / math.log(2, 2)) * n)

    cpdef double collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.k * self.added / self.size)) ** self.k

    cpdef unsigned long long bits_set(self):
        ''' Return the number of set bits in the filter '''
        return self.barray.count()


cdef class CountingBloom(object):
    ''' Probabilistic set membership testing with count estimation '''

    cdef:
        unsigned long long [:] barray
        readonly unsigned char k
        readonly unsigned long long size, added, bucketsize

    def __init__(self, unsigned long long n, unsigned char k=4, double fpr=0.01, unsigned char bucketsize=1):
        cdef:
            array.array B = array.array('B', []) # 1 bytes (max 255)
            array.array H = array.array('H', []) # 2 bytes (max 65535)
            array.array L = array.array('L', []) # 4 bytes (max 4294967295)
            array.array Q = array.array('Q', []) # 8 bytes (max 18446744073709551615)
        self.k = k
        self.size = self._calc_size(k, fpr, n)
        self.barray = array(bucketsize, [0]) * self.size
        if bucketsize == 1:
            self.barray = array.clone(B, self.size, zero=True)
        elif bucketsize == 2:
            self.barray = array.clone(H, self.size, zero=True)
        elif bucketsize == 4:
            self.barray = array.clone(L, self.size, zero=True)
        elif bucketsize == 8:
            self.barray = array.clone(Q, self.size, zero=True)
        else:
            raise ValueError('Only bucketsizes of 1, 2, 4, and 8 are supported')
        self.bucketsize = 2 ** (bucketsize * 8) - 1
        self.added = 0

    def __len__(self):
        return self.size

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __iadd__(self, bytes key):
        cdef:
            unsigned long long bucket
        for bucket in self._hasher(key):
            try:
                self.barray[bucket] += 1
            except OverflowError:
                pass
        self.added += 1
        return self

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __contains__(self, bytes key):
        cdef:
            unsigned long long bucket
        return all(self.barray[bucket] for bucket in self._hasher(key))

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __getitem__(self, bytes key):
        cdef:
            unsigned long long bucket, count
        count = self.bucketsize
        for bucket in self._hasher(key):
            if self.barray[bucket] == 0:
                return 0
            if self.barray[bucket] < count:
                count = self.barray[bucket]
        return count

    cdef unsigned long long _hasher(self, bytes key):
        ''' Compute the bit indeces of a key for k hash functions, cheating by
        using permutations of a single hash algorithm, as per Kirsch &
        Mitzenmacher ... doi:10.1007/11841036_42 '''
        cdef:
            unsigned long long hash1, hash2
            unsigned char i
        hash1 = _fnv1a_64(key)
        hash2 = _fnv1a_64(key, hash1)
        return tuple((hash1 + i * hash2) % self.size for i in range(self.k))

    cpdef add(self, bytes key):
        ''' Add item to the filter, returning its new count '''
        cdef:
            unsigned long long bucket, count
        count = self.bucketsize
        for bucket in self._hasher(key):
            try:
                self.barray[bucket] += 1
                if self.barray[bucket] < count:
                    count = self.barray[bucket]
            except OverflowError:
                pass
        self.added += 1
        return count

    cdef unsigned long long _calc_size(self, unsigned char k, double fpr, unsigned long long n):
        ''' Calculate required size from the estimated number of entries `n`,
        number of hashes `k`, and the desired false positive rate `fpr` '''
        return math.ceil((math.log(k / fpr) / math.log(2, 2)) * n)

    cpdef double collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.k * self.added / self.size)) ** self.k

    cpdef unsigned long long buckets_set(self):
        ''' Return the number of set buckets in the filter '''
        cdef:
            unsigned long long bucket
        return sum([bucket != 0 for bucket in self.barray])
