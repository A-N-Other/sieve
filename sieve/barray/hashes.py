# GY171113


def fnv1a_64(key):
    ''' 64 bit Implementation of the Fowler–Noll–Vo 1a hash function '''
    fnv1a_prime = 0x100000001b3
    hashresult = 0xcbf29ce484222325
    MASK = 0xffffffffffffffff
    for s in key:
        hashresult ^= s
        hashresult = (hashresult * fnv1a_prime) & MASK
    return hashresult
