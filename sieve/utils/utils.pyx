# GY171130

#cython: language_level=3, boundscheck=False, wraparound=False, nonecheck=False

from collections import deque

import cython


__all__ = ['seqhash', 'canonical', 'resemblance', 'containment']


trans = bytes.maketrans(b'ATUCGNRYWSKMDVHB-.', b'TAAGCNYRWSMKHBDV-.')


cpdef unsigned long long seqhash(bytes bytestring):
    cdef:
        unsigned long long h = 0
        unsigned char c
    for c in bytestring:
        h *= 4
        if c == 65:
            h += 0  # A
        elif c == 67:
            h += 1  # C
        elif c == 71:
            h += 2  # G
        elif c == 84:
            h += 3  # T
        else:
            return 0
    return h


cpdef bytes canonical(bytes bytestring):
    cdef:
        bytes bytestringrc
    bytestringrc = bytestring[::-1].translate(trans)
    if seqhash(bytestring) < seqhash(bytestringrc):
        return bytestring
    return bytestringrc


@cython.boundscheck(True)
cdef long overlap(list a, list b):
    cdef:
        long i = 0, j = 0
        long common = 0
    try:
        while True:
            while a[i] < b[j]:
                i += 1
            while a[i] > b[j]:
                j += 1
            if a[i] == b[j]:
                common += 1
                i += 1
                j += 1
    except IndexError:
        return common


cpdef double resemblance(list a, list b):
    return overlap(a, b) / ((len(a) + len(b)) / 2)


cpdef double containment(list a, list b):
    return overlap(a, b) / min(len(a), len(b))
