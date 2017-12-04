import numpy as np
cimport numpy as np
cimport cython


__all__ = ['nw']

ctypedef np.int_t DTYPE_INT
ctypedef np.uint_t DTYPE_UINT
ctypedef np.int8_t DTYPE_BOOL
ctypedef np.uint8_t DTYPE_UCHAR


cpdef nw(bytes seqB, bytes seqA, int reward=1, int gap_open=-1, int gap_extend=-1):
    cdef:
        size_t i, b, p, pos = 0, UP = 1, LEFT = 2, DIAG = 3, NA = 4
        int scoreDIAG, scoreUP, scoreLEFT
        np.ndarray[DTYPE_BOOL, ndim=1] gapA, gapB
        np.ndarray[DTYPE_INT, ndim=2] score
        np.ndarray[DTYPE_UINT, ndim=2] pointer
        np.ndarray[DTYPE_UCHAR, ndim=1] alignA, alignB

    if gap_open > 0 or gap_extend > 0:
        raise ValueError('Gap penalies must be <= 0')
    if len(seqA) == 0 or len(seqB) == 0:
        return (b'', b'')

    gapA = np.ones(len(seqA) + 1, dtype=np.int8)
    gapB = np.ones(len(seqB) + 1, dtype=np.int8)
    score = np.zeros((len(seqA) + 1, len(seqB) + 1), dtype=np.int)
    pointer = np.zeros((len(seqA) + 1, len(seqB) + 1), dtype=np.uint)

    pointer[0, 0] = NA
    score[0, 0] = 0
    pointer[0, 1:] = LEFT
    pointer[1:, 0] = UP
    score[0, 1:] = gap_open * np.arange(1, len(seqB) + 1, dtype=np.int)
    score[1:, 0] = gap_open * np.arange(1, len(seqA) + 1, dtype=np.int)
    gapA[0] = 0

    for a in range(1, len(seqA)+1):
        gapB[0] = 0
        for b in range(1, len(seqB)+1):
            gapB[b] = 1
            if seqA[a-1] == seqB[b-1]:
                scoreDIAG = score[a-1, b-1] + reward
            else:
                scoreDIAG = score[a-1, b-1] + (gap_extend if (gapA[a-1] and gapB[b-1]) else gap_open)
            scoreUP = score[a-1, b] + (gap_extend if gapA[a-1] else gap_open)
            scoreLEFT = score[a, b-1] + (gap_extend if gapB[b-1] else gap_open)
            if scoreDIAG >= scoreUP:
                if scoreDIAG >= scoreLEFT:
                    score[a, b] = scoreDIAG
                    pointer[a, b] = DIAG
                    gapA[a] = 0
                    gapB[b] = 0
                else:
                    score[a, b] = scoreLEFT
                    pointer[a, b] = LEFT
            else:
                if scoreUP >= scoreLEFT:
                    score[a, b] = scoreUP
                    pointer[a, b] = UP
                else:
                    score[a, b] = scoreLEFT
                    pointer[a, b] = LEFT

    alignB = np.zeros(len(seqA) + len(seqB), dtype=np.uint8)
    alignA = np.zeros(len(seqA) + len(seqB), dtype=np.uint8)

    p = pointer[a, b]
    while p != NA:
        if p == DIAG:
            a -= 1
            b -= 1
            alignB[pos] = seqB[b]
            alignA[pos] = seqA[a]
        elif p == LEFT:
            b -= 1
            alignB[pos] = seqB[b]
            alignA[pos] = b'-'
        elif p == UP:
            a -= 1
            alignB[pos] = b'-'
            alignA[pos] = seqA[a]
        else:
            raise ValueError
        pos += 1
        p = pointer[a, b]

    return (np.trim_zeros(alignB)[::-1].tobytes(), np.trim_zeros(alignA)[::-1].tobytes())
