# GY171127

#cython: language_level=3, boundscheck=False, wraparound=False, nonecheck=False

from sieve.structures import SeqRecord
from sieve.io cimport ks


__all__ = ['MultiReader']


cdef inline bytes _get_name(ks.kseq_t* _ks):
    return _ks.name.s[:_ks.name.l]


cdef inline bytes _get_comment(ks.kseq_t* _ks):
    return _ks.comment.s[:_ks.comment.l]


cdef inline bytes _get_seq(ks.kseq_t* _ks):
    return _ks.seq.s[:_ks.seq.l]


cdef inline bytes _get_qual(ks.kseq_t* _ks):
    return _ks.qual.s[:_ks.qual.l]


cdef class MultiReader(object):
    ''' MultiReader wraps h to read FASTA/Q (optionally compressed) '''

    cdef:
        ks.gzFile _filehandle
        ks.kseq_t* _ks

    def __init__(self, bytes filename):
       self._filehandle = ks.gzopen(filename, 'r')
       self._ks = ks.kseq_init(self._filehandle)

    def __iter__(self):
        return self

    def __next__(self):
        cdef:
            int _kseq_return
        _kseq_return = ks.kseq_read(self._ks)
        if _kseq_return < 0:
            if _kseq_return == -1:
                raise StopIteration
            else:
                raise IOError('kseq.h read error')
        return SeqRecord(
            _get_name(self._ks), _get_comment(self._ks),
            _get_seq(self._ks), _get_qual(self._ks))

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()

    def close(self):
        ks.kseq_destroy(self._ks)
        ks.gzclose(self._filehandle)
