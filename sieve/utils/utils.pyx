# GY171117

import math

cimport cython


trans = bytes.maketrans(b'ATCG', b'TAGC')


@cython.boundscheck(False)
@cython.wraparound(False)
def grouper(bytes bytestring, unsigned char k):
    ''' Yields a bytestring in chunks of length k '''
    cdef:
        unsigned long long i
    for i in range(math.ceil(len(bytestring) / k)):
        yield bytestring[i*k:i*k+k]


@cython.boundscheck(False)
@cython.wraparound(False)
def iterkmers(bytes bytestring, unsigned char k, unsigned char step=1):
    ''' Yields all possible kmers of length k from a bytestring '''
    cdef:
        unsigned long long i
    for i in range(0, len(bytestring) - k + 1, step):
        yield bytestring[i:i+k]


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef canonical(bytes bytestring, unsigned char pos=0):
    return bytestring[::-1].translate(trans) \
        if (bytestring[pos] == 84 or bytestring[pos] == 71) \
        else bytestring
