# GY171110

from math import log, ceil, e
from array import array

from sieve.barray.hashes import fnv1a_64, murmur2_64


__all__ = ['BArray', 'Bloom', 'CountingBloom']


class BArray(object):
    ''' A pure-Python bitarray implementation '''

    def __init__(self, size):
        self.size = size
        self.barray = array('Q', [0]) * ceil(size / 64)

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

    def precheckset(self, index, value=1):
        ''' Checks if a bit is already set to value (returning True), else sets
        the bit to value (returning False) '''
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

        for word in self.barray:
            print(_count(word))

        return sum(_count(word) for word in self.barray)


def _bit_indeces(key, num_hashes, size):
    ''' Compute the bit indeces of a key for k hash functions '''
    h1, h2 = fnv1a_64(key), murmur2_64(key, 12345)
    return [(h1+i*h2)%size for i in range(1, num_hashes+1)]


class Bloom(object):
    '''
    Probabilistic set membership testing.

    mem is the RAM to be allocated to the bloom filter
        (in the form '512K', '1.5M', '2G' etc)

    ... or ...

    n is the number of elements to be entered into the filter, and
    p is the desired error rate of the filter

    '''

    def __init__(self, mem=None, n=None, p=0.01):
        self.size, self.num_hashes = self.calc_params(mem, n, p)
        self.barray = BArray(self.size)
        self.added = 0

    def __repr__(self):
        return 'Bloom(num_hashes={}, size={})'.format(self.num_hashes, self.size)

    def __len__(self):
        return self.size

    def __iadd__(self, key):
        for bit in _bit_indeces(key, self.num_hashes, self.size):
            self.barray[bit] = 1
        self.added += 1
        return self

    def __contains__(self, key):
        return all(self.barray[bit] for bit in _bit_indeces(key,
            self.num_hashes, self.size))

    @staticmethod
    def calc_params(mem=None, n=None, p=0.01):
        if mem:
            if mem[-1] in ('K', 'k'):
                mem = int(float(mem[:-1]) * 1024)
            elif mem[-1] in ('M', 'm'):
                mem = int(float(mem[:-1]) * 1024**2)
            elif mem[-1] in ('G', 'g'):
                mem = int(float(mem[:-1]) * 1024**3)
            size = mem * 8
            num_hashes = 7
        elif n:
            size = ceil((-n*log(p))/log(2)**2)
            num_hashes = ceil((size/n)*log(2))
        else:
            pass #raise PySembler_BloomError('Either a memory limit (mem) or the number of members to be added (n) must be provided.')
        return size, num_hashes

    def precheckadd(self, bits):
        ''' Check if all bits corresponding to a key are already set, returning
        True, otherwise set the bits and return False '''
        changes = [self.barray.precheckset(bit, 1) for bit in \
            _bit_indeces(key, self.num_hashes, self.size)]
        self.added += 1
        return all(changes)

    @property
    def collision_probability(self):
        ''' Return an estimate of the collision probability for the next key
        entered given the current number of insertions. As the filter fills and
        dependent on the redundancy of the keys entered, this will increasingly
        return an overestimate. '''
        return (1-e**(-self.num_hashes*self.added/self.size))**self.num_hashes

    @property
    def bits_set(self):
        ''' Return the number of set bits in the filter '''
        return self.barray.count()


class CountingBloom(object):
    '''
    Probabilistic set membership testing including the likely count of a
    key within the set.

    mem is the RAM to be allocated to the bloom filter
        (in the form '512K', '1.5M', '2G' etc)

    ... or ...

    n is the number of elements to be entered into the filter, and
    p is the desired error rate of the filter

    '''

    def __init__(self, mem=None, n=None, p=0.01):
        self.barray = array('B')
        if mem:
            if mem[-1] in ('K', 'k'):
                self.size = int(float(mem[:-1]) * 1024)
            elif mem[-1] in ('M', 'm'):
                self.size = int(float(mem[:-1]) * 1024**2)
            elif mem[-1] in ('G', 'g'):
                self.size = int(float(mem[:-1]) * 1024**3)
            self.num_hashes = 7
        elif n:
            self.size = ceil((-n*log(p))/log(2)**2)
            self.num_hashes = ceil((self.size/n)*log(2))
        else:
            pass #raise PySembler_BloomError('Either a memory limit (mem) or the number of members to be added (n) must be provided.')
        self.barray = array('B', [0])*self.size
        self.added = 0

    def __repr__(self):
        return 'Bloom(num_hashes={}, size={})'.format(self.num_hashes, self.size)

    def __len__(self):
        return self.size

    def add(self, key):
        ''' Increments bits in the bloom filter corresponding to a key.
        Increments self.added to track the number of entries. '''
        try:
            for bucket in _bit_indeces(key, self.num_hashes, self.size):
                self.barray[bucket] += 1
        except OverflowError:
            pass
        self.added += 1
        return self

    def __contains__(self, key):
        return min(self.barray[bucket] for bucket in _bit_indeces(key,
            self.num_hashes, self.size))

    def inc(self, buckets):
        ''' Increments a pre-calculated iterable of buckets '''
        for bucket in buckets:
            self.barray[bucket] += 1
        self.added += 1

    def __getitem__(self, key):
        ''' Returns the likely number of times a key has been entered. Returns
        0 (equates to False) if a key is not set. '''
        return min(self.barray[bucket] for bucket in _bit_indeces(key,
            self.num_hashes, self.size))

    @property
    def buckets_set(self):
        ''' Return the number of set buckets in the filter '''
        return sum([1 for i in self.barray if i])

    @property
    def collision_probability(self):
        ''' Return an estimate of the collision probability for the next key
        entered given the current number of insertions. As the filter fills and
        dependent on the redundancy of the keys entered, this will increasingly
        return an overestimate. '''
        return (1-e**(-self.num_hashes*self.added/self.size))**self.num_hashes
