# GY171120

__all__ = ['SeqRecord']


cdef class SeqRecord(object):
    ''' Generic class holding a FASTA/Q kseq kseq record '''

    cdef:
        public bytes name, comment, seq, qual

    def __init__(self, bytes name, bytes comment, bytes seq, bytes qual):
        self.name = name
        self.comment = comment
        self.seq = seq
        self.qual = qual

    def __len__(self):
        return len(self.seq)
