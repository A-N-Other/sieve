# GY171116


cdef _fnv1a_64(bytes key, unsigned long long seed=0):
    ''' 64 bit implementation of the Fowler–Noll–Vo 1a hash function modified
    to take a seed value '''
    cdef unsigned long long hashresult = 0xcbf29ce484222325
    cdef unsigned long long fnv1a_prime = 0x100000001b3
    cdef char c

    if seed:
        hashresult ^= seed
        hashresult *= fnv1a_prime
    for c in key:
        hashresult ^= c
        hashresult *= fnv1a_prime
    return hashresult
