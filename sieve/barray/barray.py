# GY171116

import math
from array import array
from struct import calcsize
from collections import defaultdict as dd

from sieve.barray.hashes import fnv1a_64


__all__ = ['BArray', 'Bloom', 'CountingBloom']


class BArray(object):
    ''' A pure-Python bitarray implementation '''

    def __init__(self, size):
        self.size = size
        self.barray = array('Q', [0]) * math.ceil(size / 64)

    def __getitem__(self, index):
        word, bit = self._getindex(index)
        mask = 1 << bit
        if self.barray[word] & mask:
            return 1
        return 0

    def __setitem__(self, index, value):
        word, bit = self._getindex(index)
        mask = 1 << bit
        if value:
            self.barray[word] |= mask
        else:
            self.barray[word] &= ~mask

    def __len__(self):
        return self.size

    def _getindex(self, index):
        if index < 0:
            index += self.size
        if not 0 <= index < self.size:
            raise IndexError('Attempt to access out of bounds bit')
        return divmod(index, 64)

    def set(self, index):
        ''' Sets a bit, returning if already set as boolean'''
        word, bit = self._getindex(index)
        mask = 1 << bit
        if self.barray[word] & mask:
            return True
        self.barray[word] |= mask
        return False

    def unset(self, index):
        ''' Unsets a bit, returning if already unset as boolean '''
        word, bit = self._getindex(index)
        mask = 1 << bit
        if not self.barray[word] & mask:
            return True
        self.barray[word] &= ~mask
        return False

    def blockset(self, index, mask):
        ''' Sets bits in a block, returning if already set as boolean '''
        word, _ = self._getindex(index)
        if (self.barray[word] & mask) == mask:
            return True
        self.barray[word] |= mask
        return False

    def blockunset(self, index, mask):
        ''' Unsets bits in a block, returning if already unset as boolean '''
        word, _ = self._getindex(index)
        if not self.barray[word] & mask:
            return True
        self.barray[word] &= ~mask
        return False

    def count(self):
        ''' Count number of set bits '''

        def _count(i):
            ''' 64 bit SWAR popcount '''
            i = i - ((i >> 1) & 0x5555555555555555)
            i = (i & 0x3333333333333333) + ((i >> 2) & 0x3333333333333333)
            return ((((i + (i >> 4)) & 0x0f0f0f0f0f0f0f0f) * 0x0101010101010101) & 0xffffffffffffffff) >> 56

        return sum(_count(word) for word in self.barray)


class Bloom(object):
    ''' Probabilistic set membership testing'''

    def __init__(self, k=4, fpr=0.01, n):
        self.k = k
        self.size = self.calc_params(k, fpr, n)
        self.barray = BArray(self.size)
        self.added = 0

    def __len__(self):
        return self.size

    def __iadd__(self, key):
        for pos in self._hasher(key):
            self.barray[pos] = 1
        self.added += 1
        return self

    def __contains__(self, key):
        return all(self.barray[pos] for pos in self._hasher(key))

    def _hasher(self, key):
        ''' Compute the bit indeces of a key for k hash functions, cheating by
        using permutations of a single hash algorithm, as per Kirsch &
        Mitzenmacher ... doi:10.1007/11841036_42 '''
        key = tuple(ord(c) for c in key)
        hash1 = fnv1a_64(key)
        hash2 = fnv1a_64((hash1,) + key)
        for i in range(self.k):
            yield (hash1 + i * hash2) % self.size

    def add(self, key):
        ''' Add item to the filter, returning if already present as boolean '''
        self.added += 1
        return all([self.barray.set(pos) for pos in self._hasher(key)])

    @staticmethod
    def calc_params(k, fpr, n):
        ''' Calculate required size from the estimated number of entries `n`,
        number of hashes `k`, and the desired false positive rate `fpr` '''
        return math.ceil((math.log(k / fpr) / math.log(2, 2)) * n)

    @property
    def collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.k * self.added / self.size)) ** self.k

    @property
    def bits_set(self):
        ''' Return the number of set bits in the filter '''
        return self.barray.count()


class CountingBloom(object):
    ''' Probabilistic set membership testing with count estimation '''

    def __init__(self, k=4, fpr=0.01, bucketsize='B', n):
        self.k = k
        self.size = self.calc_params(k, fpr, n)
        self.barray = array(bucketsize, [0]) * self.size
        self.bucketsize = 2 ** (8 * calcsize(bucketsize)) - 1
        self.added = 0

    def __len__(self):
        return self.size

    def __iadd__(self, key):
        for bucket in self._hasher(key):
            try:
                self.barray[bucket] += 1
            except OverflowError:
                pass
        self.added += 1
        return self

    def __contains__(self, key):
        return all(self.barray[bucket] for bucket in self._hasher(key))

    def __getitem__(self, key):
        count = self.bucketsize
        for bucket in self._hasher(key):
            current = self.barray[bucket]
            if current == 0:
                return 0
            if current < count:
                count = current
        return count

    def _hasher(self, key):
        ''' Compute the bit indeces of a key for k hash functions, cheating by
        using permutations of a single hash algorithm, as per Kirsch &
        Mitzenmacher ... doi:10.1007/11841036_42 '''
        key = tuple(ord(c) for c in key)
        hash1 = fnv1a_64(key)
        hash2 = fnv1a_64((hash1,) + key)
        for i in range(self.k):
            yield (hash1 + i * hash2) % self.size

    def add(self, key):
        ''' Add item to the filter, returning its new count '''
        count = self.bucketsize
        for bucket in self._hasher(key):
            try:
                self.barray[bucket] += 1
                bucketcount = self.barray[bucket]
                if bucketcount < count:
                    count = bucketcount
            except OverflowError:
                pass
        self.added += 1
        return count

    @staticmethod
    def calc_params(k, fpr, n):
        ''' Calculate required size from the estimated number of entries `n`,
        number of hashes `k`, and the desired false positive rate `fpr` '''
        return math.ceil((math.log(k / fpr) / math.log(2, 2)) * n)

    @property
    def collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.k * self.added / self.size)) ** self.k

    @property
    def buckets_set(self):
        ''' Return the number of set buckets in the filter '''
        return sum([i != 0 for i in self.barray])
