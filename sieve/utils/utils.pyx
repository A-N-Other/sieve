# GY171127

#cython: language_level=3, boundscheck=False, wraparound=False, nonecheck=False


__all__ = ['iterkmers', 'canonical']


trans = bytes.maketrans(b'ATCG', b'TAGC')


def iterkmers(bytes bytestring, unsigned char k, unsigned char step=1):
    ''' Yields all possible kmers of length k from a bytestring '''
    cdef:
        unsigned long long i
    for i in range(0, len(bytestring) - k + 1, step):
        yield bytestring[i:i+k]


cpdef bytes canonical(bytes bytestring):
    cdef:
        unsigned char pos
    pos = (len(bytestring) + 1) // 2
    return bytestring[::-1].translate(trans) \
        if (bytestring[pos] == 84 or bytestring[pos] == 71) \
        else bytestring
