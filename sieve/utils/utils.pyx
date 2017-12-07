# GY171206

#cython: language_level=3, boundscheck=False, wraparound=False, nonecheck=False

from collections import deque


__all__ = ['seqhash', 'canonical', 'resemblance', 'containment', 'minimisers']


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


cpdef double resemblance(set a, set b):
    return len(a & b) / ((len(a) + len(b)) / 2)


cpdef double containment(set a, set b):
    return len(a & b) / min(len(a), len(b))


cpdef set minimisers(bytes bytestring, unsigned char k, unsigned char w):
    cdef:
        set minis = set()
        size_t i
        list m
        unsigned long long h
    d = deque(maxlen=w-k+1)
    for i in range(w-k+1):
        d.append(seqhash(canonical(bytestring[i:i+k])))
    m = [h for h in d if h not in minis]
    if m:
        minis.add(min(m))
    for i in range(w-k+1, len(bytestring)-k+1):
        d.append(seqhash(canonical(bytestring[i:i+k])))
        m = [h for h in d if h not in minis]
        if m:
            minis.add(min(m))
    return minis
