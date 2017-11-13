# GY171113

import math
from array import array
from struct import calcsize

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

    def set(self, index, value=1):
        ''' Sets a bit, returning if already set the same as boolean '''
        word, bit = self._getindex(index)
        mask = 1 << bit
        current = self.barray[word] & mask
        if (current and value) or (not current and not value):
            return True
        if value:
            self.barray[word] |= mask
        else:
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

    def __init__(self, size=None, n=None, err=0.01):
        ''' `size` exact size in bytes for underlying bitarray, or calculate
        from the estimated number of entries `n` and desired error rate `err` '''
        self.size, self.num_hashes = self.calc_params(size, n, err)
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
        for i in range(self.num_hashes):
            yield (hash1 + i * hash2) % self.size

    def add(self, key):
        ''' Add item to the filter, returning if already present as boolean '''
        self.added += 1
        return all(self.barray.set(pos, 1) for pos in self._hasher(key))

    @staticmethod
    def calc_params(size=None, n=None, err=None):
        ''' Takes a size (in bits) or calculates one from the estimated
        number of entries `n` and the desired error rate `e` '''
        if size:
            return (size, 7)
        size = math.ceil((-n * math.log(err)) / math.log(2) ** 2)
        num_hashes = math.ceil((size / n) * math.log(2))
        return size, num_hashes

    @property
    def collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.num_hashes * self.added / self.size)) ** \
            self.num_hashes

    @property
    def bits_set(self):
        ''' Return the number of set bits in the filter '''
        return self.barray.count()


class CountingBloom(object):
    ''' Probabilistic set membership testing with count estimation '''

    def __init__(self, size=None, n=None, err=0.01, bucketsize='B'):
        ''' `size` exact number of buckets for underlying array, or calculate
        from the estimated number of entries `n`, desired error rate `err`, and
        required bucket size `bucketsize` '''
        self.size, self.num_hashes = self.calc_params(size, n, err)
        self.barray = array(bucketsize, [0]) * self.size
        self.bucketsize = 2 ** (8 * calcsize(bucketsize)) - 1
        self.added = 0

    def __len__(self):
        return self.size

    def __iadd__(self, key):
        for pos in self._hasher(key):
            try:
                self.barray[pos] += 1
            except OverflowError:
                pass
        self.added += 1
        return self

    def __contains__(self, key):
        return all(self.barray[pos] for pos in self._hasher(key))

    def __getitem__(self, key):
        return min(self.barray[pos] for pos in self._hasher(key))

    def _hasher(self, key):
        ''' Compute the bit indeces of a key for k hash functions, cheating by
        using permutations of a single hash algorithm, as per Kirsch &
        Mitzenmacher ... doi:10.1007/11841036_42 '''
        key = tuple(ord(c) for c in key)
        hash1 = fnv1a_64(key)
        hash2 = fnv1a_64((hash1,) + key)
        for i in range(self.num_hashes):
            yield (hash1 + i * hash2) % self.size

    def add(self, key):
        ''' Add item to the filter, returning its new count '''
        self.added += 1
        count = self.bucketsize
        try:
            for bucket in self._hasher(key):
                self.barray[bucket] += 1
                bucketcount = self.barray[bucket]
                if bucketcount < count:
                    count = bucketcount
        except OverflowError:
            pass
        return bucketcount

    @staticmethod
    def calc_params(size=None, n=None, err=None):
        ''' Takes a size (in bits) or calculates one from the estimated
        number of entries `n` and the desired error rate `e` '''
        if size:
            return (size, 7)
        size = math.ceil((-n * math.log(err)) / math.log(2) ** 2)
        num_hashes = math.ceil((size / n) * math.log(2))
        return size, num_hashes

    @property
    def collision_probability(self):
        ''' Return a current estimate of the collision probability '''
        return (1 - math.e ** (-self.num_hashes * self.added / self.size)) ** \
            self.num_hashes

    @property
    def buckets_set(self):
        ''' Return the number of set bits in the filter '''
        return sum([i != 0 for i in self.barray])
