cdef extern from 'zlib.h':
    ctypedef void* gzFile
    gzFile gzopen(const char* file_name, const char* mode)
    void gzclose(gzFile f)

cdef extern from 'ks.h':
    ctypedef struct kstream_t:
        pass
    ctypedef struct kstring_t:
        size_t l, m
        char *s
    ctypedef struct kseq_t:
        kstring_t name, comment, seq, qual
        int last_char, is_fastq
        kstream_t *f;
    kseq_t *kseq_init(gzFile fd)
    void kseq_destroy(kseq_t *ks)
    int kseq_read(kseq_t *seq)