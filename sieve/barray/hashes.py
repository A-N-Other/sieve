# GY171110

from sieve.utils import Utils
_Utils = Utils()
grouper = _Utils.grouper


def fnv1a_64(key):
    ''' 64 bit Implementation of the Fowler–Noll–Vo 1a hash function '''
    fnv1a_prime = 0x100000001b3
    fnv1a_hash = 0xcbf29ce484222325
    intmax = 0xffffffffffffffff
    for s in key:
        fnv1a_hash ^= s
        fnv1a_hash = (fnv1a_hash * fnv1a_prime) & intmax
    return fnv1a_hash


def murmur2_64(key, seed=12345):

    def bytes_to_long(bytes):
        return sum(b << (i * 8) for i, b in enumerate(bytes))

    m = 0xc6a4a7935bd1e995
    r = 47
    MASK = 0xffffffffffffffff
    h = seed ^ ((m * len(key)) & MASK)

    for octet in grouper(key, 8):
        k = bytes_to_long(octet)
        k = (k * m) & MASK
        k = k ^ ((k >> r) & MASK)
        k = (k * m) & MASK
        h = (h ^ k)
        h = (h * m) & MASK

    l = len(key) & 7
    if l >= 7:
        h = (h ^ (key[6] << 48))
    if l >= 6:
        h = (h ^ (key[5] << 40))
    if l >= 5:
        h = (h ^ (key[4] << 32))
    if l >= 4:
        h = (h ^ (key[3] << 24))
    if l >= 3:
        h = (h ^ (key[2] << 16))
    if l >= 2:
        h = (h ^ (key[1] << 8))
    if l >= 1:
        h = (h ^ key[0])
        h = (h * m) & MASK

    h = h ^ ((h >> r) & MASK)
    h = (h * m) & MASK
    h = h ^ ((h >> r) & MASK)

    return h
