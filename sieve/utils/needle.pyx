# GY171206

#cython: language_level=3, boundscheck=False, wraparound=False, nonecheck=False

import numpy as np
cimport numpy as np


__all__ = ['nw', 'centerstar']


ctypedef np.int_t DTYPE_INT
ctypedef np.uint_t DTYPE_UINT
ctypedef np.int8_t DTYPE_BOOL
ctypedef np.uint8_t DTYPE_UCHAR


cpdef np.ndarray[DTYPE_UCHAR, ndim=2] nw(bytes seqA, bytes seqB, int match=1, int mismatch=-2, int gap_open=-4, int gap_extend=-1):
    cdef:
        size_t i, a, b, p, pos = 0, UP = 1, LEFT = 2, DIAG = 3, NA = 4
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
            scoreUP = score[a-1, b] + (gap_extend if gapA[a-1] else gap_open)
            scoreLEFT = score[a, b-1] + (gap_extend if gapB[b-1] else gap_open)
            scoreDIAG = score[a-1, b-1] + (match if seqA[a-1] == seqB[b-1] else mismatch)
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

    alignA = np.zeros(len(seqA) + len(seqB), dtype=np.uint8)
    alignB = np.zeros(len(seqA) + len(seqB), dtype=np.uint8)

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
            raise ValueError('Traceback failure')
        pos += 1
        p = pointer[a, b]

    return np.array([np.trim_zeros(alignA)[::-1], np.trim_zeros(alignB)[::-1]])


cpdef np.ndarray centerstar(tuple seqs):
    cdef:
        np.ndarray[DTYPE_UCHAR, ndim=1] space = np.array([45], dtype=np.uint8)  # '-'
        np.ndarray aln
        np.ndarray[DTYPE_UCHAR, ndim=2] pair
        size_t i = 0
        bytes seq

    aln = nw(seqs[0], seqs[1])
    for seq in seqs[2:]:
        pair = nw(seqs[0], seq)
        while not np.array_equal(aln[0], pair[0]):
            if i > len(aln[0]) - 1:
                aln = np.insert(
                    aln, [len(aln[0])],
                    np.tile(space, len(pair[0]) - len(aln[0])), axis=1)
                continue
            if i > len(pair[1]) - 1:
                pair = np.insert(
                    pair, [len(pair[0])],
                    np.tile(space, len(aln[0]) - len(pair[0])), axis=1)
                continue
            if aln[0,i] != pair[0][i]:
                if aln[0,i] == 45:   # '-'
                    pair = np.insert(pair, [i], space, axis=1)
                elif pair[0,i] == 45:   # '-'
                    aln = np.insert(aln, [i], space, axis=1)
                # else aligned mismatch is fine
            i += 1
        aln = np.concatenate((aln, np.array(pair[1], copy=False, ndmin=2)))
    return aln
