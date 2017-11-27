# GY171127

#cython: language_level=3, boundscheck=False, wraparound=False, nonecheck=False


__all__ = ['canonical']


trans = bytes.maketrans(b'ATCG', b'TAGC')


cpdef bytes canonical(bytes bytestring):
    cdef:
        unsigned char pos
    pos = (len(bytestring) + 1) // 2
    return bytestring[::-1].translate(trans) \
        if (bytestring[pos] == 84 or bytestring[pos] == 71) \
        else bytestring
