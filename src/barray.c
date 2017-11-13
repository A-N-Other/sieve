#include <Python.h>
#include "structmember.h"
#include <stdint.h>

// PySembler includes
#include "hashes.h"

const uint64_t onebit64 = 0x0000000000000001;
const uint8_t onebit8 = 0x01;

#define SetBit(b) (self->barray[(b)/64] |= onebit64 << ((b)%64))
#define ClearBit(b) (self->barray[(b)/64] &= ~(onebit64 << ((b)%64)))
#define TestBit(b) ((self->barray[(b)/64] & (onebit64 << ((b)%64))) ? 1 : 0)

////////////////////////////////////////////////////////////////////////////////
// barray.BArray ///////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

typedef struct {
    PyObject_HEAD
    Py_ssize_t size;
    uint64_t *barray;
} BArray;

static int BArray_init(BArray* self, PyObject *args) {
    if (! PyArg_ParseTuple(args, "K", &self->size))
        return -1;
    self->barray = (uint64_t *) calloc((self->size + 64 - 1) / 64, sizeof(uint64_t));
    if (! self->barray) {
        PyErr_NoMemory();
        return -1;
    }
    return 0;
}

static void BArray_dealloc(BArray* self) {
    Py_TYPE(self)->tp_free((PyObject*) self);
}

static inline PyObject* BArray_getitem(BArray* self, PyObject *key) {
    if (PyIndex_Check(key)) {
        Py_ssize_t i;
        i = PyLong_AsSsize_t(key);
        if (PyErr_Occurred())
            return NULL;
        if (i < 0)
            i += self->size;
        if (0 <= i && i < self->size)
            return Py_BuildValue("i", TestBit(i));
        PyErr_SetString(PyExc_IndexError, "Attempt to access out of bounds bit");
        return NULL;
    } else if (PySlice_Check(key)) {
        Py_ssize_t start, stop, step, slicelength;
        if (PySlice_GetIndicesEx(key, self->size, &start, &stop, &step, &slicelength) < 0)
            return NULL;
        if (slicelength <= 0)
            return PyTuple_New(0);
        Py_ssize_t i, j;
        PyObject* tup = PyTuple_New(slicelength);
        if (! tup)
            return NULL;
        for (i = start, j = 0; i < stop; i += step, j++) {
            PyObject* num = Py_BuildValue("i", TestBit(i));
            if (!num) {
                Py_DECREF(tup);
                return NULL;
            }
            PyTuple_SET_ITEM(tup, j, num);
        }
        return tup;
    } else {
        PyErr_SetString(PyExc_IndexError, "An index or a slice is required");
        return NULL;
    }
}

static inline int BArray_setitem(BArray* self, PyObject *key, PyObject *value) {
    long val;
    if (value == NULL) {
        PyErr_SetString(PyExc_TypeError, "Deletion is not allowed!");
        return -1;
    }
    if (PyLong_Check(value)) {
        val = PyLong_AsLong(value);
    } else if (PyBool_Check(value)) {
        val = (value == Py_True) ? 1 : 0;
    } else {
        PyErr_SetString(PyExc_TypeError, "Bits may only be set to 0/1 or True/False");
        return -1;
    }
    if (PyIndex_Check(key)) {
        Py_ssize_t i;
        i = PyLong_AsSsize_t(key);
        if (PyErr_Occurred())
            return -1;
        if (i < 0)
            i += self->size;
        if (0 <= i && i < self->size) {
            if (val) {
                SetBit(i);
            } else {
                ClearBit(i);
            }
            return 0;
        }
        PyErr_SetString(PyExc_IndexError, "Attempt to set out of bounds bit");
        return -1;
    } else if (PySlice_Check(key)) {
        Py_ssize_t i, start, stop, step, slicelength;
        if (PySlice_GetIndicesEx(key, self->size, &start, &stop, &step, &slicelength) < 0)
            return -1;
        if (slicelength <= 0)
            return 0;
        for (i = start; i < stop; i += step) {
            if (val) {
                SetBit(i);
            } else {
                ClearBit(i);
            }
        }
        return 0;
    } else {
        PyErr_SetString(PyExc_IndexError, "An index or a slice is required");
        return -1;
    }
}

static inline PyObject* BArray_prechecksetitem(BArray* self, PyObject *args) {
    Py_ssize_t key;
    PyObject* value;
    long val;
    if (! PyArg_ParseTuple(args, "nO", &key, &value)) {
        PyErr_SetString(PyExc_TypeError, "An index and a value are expected");
        return NULL;
    }
    if (value == NULL) {
        PyErr_SetString(PyExc_TypeError, "Deletion is not allowed");
        return NULL;
    }
    if (PyLong_Check(value)) {
        val = PyLong_AsLong(value);
    } else if (PyBool_Check(value)) {
        val = (value == Py_True) ? 1 : 0;
    } else {
        PyErr_SetString(PyExc_TypeError, "Bits may only be set to 0/1 or True/False");
        return NULL;
    }
    if (key < 0)
        key += self->size;
    if (0 <= key && key < self->size) {
        int b = TestBit(key);
        if ((b && val) || (!b && !val))
            Py_RETURN_TRUE;
        if (val) {
            SetBit(key);
        } else {
            ClearBit(key);
        }
        Py_RETURN_FALSE;
    }
    PyErr_SetString(PyExc_IndexError, "Attempt to set out of bounds bit");
    return NULL;
}

static Py_ssize_t BArray_length(BArray *self) {
    return self->size;
}

static inline PyObject* BArray_setall(BArray* self, PyObject *value) {
    long val;
    Py_ssize_t i;
    if (PyLong_Check(value)) {
        val = PyLong_AsLong(value);
    } else if (PyBool_Check(value)) {
        val = (value == Py_True) ? 1 : 0;
    } else {
        PyErr_SetString(PyExc_TypeError, "Bits may only be set to 0/1 or True/False");
        return NULL;
    }
    if (val) {
        for (i = 0; i < (((self->size + 64 - 1) / 64) - 1); i++) self->barray[i] |= 0xFFFFFFFFFFFFFFFF;
        self->barray[i] |= 0xFFFFFFFFFFFFFFFF >> (64 - (self->size%64));
    } else {
        for (i = 0; i < (((self->size + 64 - 1) / 64) - 1); i++) self->barray[i] &= ~0xFFFFFFFFFFFFFFFF;
        self->barray[i] &= ~(0xFFFFFFFFFFFFFFFF >> (64 - (self->size%64)));
    }
    Py_RETURN_NONE;
}

static inline PyObject* BArray_countbits(BArray* self) {
    const uint64_t m1 = 0x5555555555555555, m2 = 0x3333333333333333,
        m4 = 0x0f0f0f0f0f0f0f0f, h01 = 0x0101010101010101;
    uint64_t acc = 0, x;
    Py_ssize_t i;
    for (i = 0; i < (self->size + 64 - 1) / 64; i++) {
        x = self->barray[i];
        x -= (x >> 1) & m1;
        x = (x & m2) + ((x >> 2) & m2);
        x = (x + (x >> 4)) & m4;
        acc += (x * h01)>>56;
    }
    return PyLong_FromUnsignedLongLong(acc);
}

static PyMethodDef BArray_methods[] = {
    {"precheckset", (PyCFunction) BArray_prechecksetitem, METH_VARARGS, "Check if a bit is already set to value, returning True, otherwise set the bit and return False"},
    {"setall", (PyCFunction) BArray_setall, METH_O, "Set all bits in the filter"},
    {"countbits", (PyCFunction) BArray_countbits, METH_NOARGS, "Count the number of set bits"},
    {NULL, NULL}  /* sentinel */
};

static PyMappingMethods BArray_mapping_methods = {
    .mp_length = (lenfunc) BArray_length,
    .mp_subscript = (binaryfunc) BArray_getitem,
    .mp_ass_subscript = (objobjargproc) BArray_setitem,
};

static PyTypeObject BArrayType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,

    .tp_name = "barray.BArray",
    .tp_basicsize = sizeof(BArray),
    .tp_doc = "BArray objects",

    .tp_init = (initproc)BArray_init,
    .tp_dealloc = (destructor)BArray_dealloc,

    .tp_methods = BArray_methods,
};

////////////////////////////////////////////////////////////////////////////////
// barray.Bloom ////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

typedef struct {
    PyObject_HEAD
    Py_ssize_t size;
    uint64_t *barray;
    uint64_t added;
    uint8_t num_hashes;
} Bloom;

static int Bloom_init(Bloom* self, PyObject *args) {
    if (! PyArg_ParseTuple(args, "Kb", &self->size, &self->num_hashes))
        return -1;
    self->barray = (uint64_t *) calloc((self->size + 64 - 1) / 64, sizeof(uint64_t));
    if (! self->barray) {
        PyErr_NoMemory();
        return -1;
    }
    self->added = 0;
    return 0;
}

static void Bloom_dealloc(Bloom* self) {
    Py_TYPE(self)->tp_free((PyObject*) self);
}

static Py_ssize_t Bloom_length(Bloom *self) {
    return self->size;
}

static inline PyObject* Bloom_countbits(Bloom* self) {
    const uint64_t m1 = 0x5555555555555555, m2 = 0x3333333333333333,
        m4 = 0x0f0f0f0f0f0f0f0f, h01 = 0x0101010101010101;
    uint64_t acc = 0, x;
    Py_ssize_t i;
    for (i = 0; i < (self->size + 64 - 1) / 64; i++) {
        x = self->barray[i];
        x -= (x >> 1) & m1;
        x = (x & m2) + ((x >> 2) & m2);
        x = (x + (x >> 4)) & m4;
        acc += (x * h01)>>56;
    }
    return PyLong_FromUnsignedLongLong(acc);
}

static inline PyObject* Bloom_add(Bloom* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen;
    uint64_t h1, h2;
    uint8_t i;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) SetBit((h1+i*h2)%self->size);
        self->added++;
        Py_RETURN_NONE;
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return NULL;
}

static inline int Bloom_contains(Bloom* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen;
    uint64_t h1, h2;
    uint8_t i;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) {
            if (!TestBit((h1+i*h2)%self->size)) return 0;
        }
        return 1;
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return -1;
}

static PyMemberDef Bloom_members[] = {
    {"added", T_ULONGLONG, offsetof(Bloom, added), 0, "added"},
    {NULL}  /* Sentinel */
};

static PyMethodDef Bloom_methods[] = {
    {"countbits", (PyCFunction) Bloom_countbits, METH_NOARGS, "Count the number of set bits"},
    {"add", (PyCFunction) Bloom_add, METH_O, "Add a key to the Bloom filter"},
    {NULL, NULL}
};

static PyMappingMethods Bloom_mapping_methods = {
    .mp_length = (lenfunc)Bloom_length
};

static PySequenceMethods Bloom_sequence_methods = {
    .sq_contains = (objobjproc)Bloom_contains
};

static PyTypeObject BloomType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,

    .tp_name = "barray.Bloom",
    .tp_basicsize = sizeof(Bloom),
    .tp_doc = "Bloom objects",

    .tp_init = (initproc)Bloom_init,
    .tp_dealloc = (destructor)Bloom_dealloc,

    .tp_methods = Bloom_methods,
    .tp_members = Bloom_members
};

////////////////////////////////////////////////////////////////////////////////
// barray.CountingBloom ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

typedef struct {
    PyObject_HEAD
    Py_ssize_t size;
    uint64_t *barray;
    uint64_t added;
    uint8_t num_hashes;
    uint8_t bucket_size;
    uint8_t max_count;
    Py_ssize_t _size;
} CountingBloom;

static int CountingBloom_init(CountingBloom* self, PyObject *args) {
    uint8_t i;

    if (! PyArg_ParseTuple(args, "Kbb", &self->size, &self->num_hashes, &self->bucket_size))
        return -1;
    self->_size = (Py_ssize_t)self->size/self->bucket_size;
    self->max_count = 0;
    for (i = 0; i < self->bucket_size; i++) self->max_count |= onebit8 << i;
    self->barray = (uint64_t*)calloc((self->size + 64 - 1) / 64, sizeof(uint64_t));
    if (! self->barray) {
        PyErr_NoMemory();
        return -1;
    }
    self->added = 0;
    return 0;
}

static void CountingBloom_dealloc(CountingBloom* self) {
    Py_TYPE(self)->tp_free((PyObject*) self);
}

static Py_ssize_t CountingBloom_length(CountingBloom *self) {
    return self->_size;
}

static inline PyObject* CountingBloom_add(CountingBloom* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen, bucket;
    uint64_t h1, h2;
    uint8_t i, j, tmp;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) {
            bucket = (h1+i*h2) % self->_size;
            tmp = 0;
            for (j = 0; j < self->bucket_size; j++) {
                if (TestBit((bucket * self->bucket_size) + j)) tmp |= onebit8 << j;
            }
            if (!tmp) {
                SetBit((bucket * self->bucket_size));
            } else {
                if (++tmp <= self->max_count) {
                    j = 0;
                    while (tmp) {
                        if (tmp & 1) {
                            SetBit((bucket * self->bucket_size) + j);
                        } else {
                            ClearBit((bucket * self->bucket_size) + j);
                        }
                        j++;
                        tmp >>= 1;
                    }
                }
            }
        }
        self->added++;
        Py_RETURN_NONE;
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return NULL;
}

static inline PyObject* CountingBloom_getitem(CountingBloom* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen, bucket;
    uint64_t h1, h2;
    uint8_t i, j, tmp, count = self->max_count;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) {
            bucket = (h1+i*h2) % self->_size;
            tmp = 0;
            for (j = 0; j < self->bucket_size; j++) {
                if (TestBit((bucket * self->bucket_size) + j)) tmp |= onebit8 << j;
            }
            if (!tmp) return Py_BuildValue("B", tmp);
            if (tmp < count) count = tmp;
        }
        return Py_BuildValue("B", count);
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return NULL;
}

static inline int CountingBloom_contains(CountingBloom* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen, bucket;
    uint64_t h1, h2;
    uint8_t i, j, tmp;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) {
            bucket = (h1+i*h2) % self->_size;
            tmp = 0;
            for (j = 0; j < self->bucket_size; j++) {
                if (TestBit((bucket * self->bucket_size) + j)) tmp |= onebit8 << j;
            }
            if (!tmp) return 0;
        }
        return 1;
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return -1;
}

static PyMemberDef CountingBloom_members[] = {
    {"added", T_ULONGLONG, offsetof(CountingBloom, added), 0, "added"},
    {NULL}  /* Sentinel */
};

static PyMethodDef CountingBloom_methods[] = {
    {"add", (PyCFunction) CountingBloom_add, METH_O, "Add a key to the Bloom filter"},
    {NULL, NULL}
};

static PyMappingMethods CountingBloom_mapping_methods = {
    .mp_length = (lenfunc) CountingBloom_length,
    .mp_subscript = (binaryfunc) CountingBloom_getitem
};

static PySequenceMethods CountingBloom_sequence_methods = {
    .sq_contains = (objobjproc)CountingBloom_contains
};

static PyTypeObject CountingBloomType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,

    .tp_name = "barray.CountingBloom",
    .tp_basicsize = sizeof(CountingBloom),
    .tp_doc = "CountingBloom objects",

    .tp_init = (initproc)CountingBloom_init,
    .tp_dealloc = (destructor)CountingBloom_dealloc,

    .tp_methods = CountingBloom_methods,
    .tp_members = CountingBloom_members
};

////////////////////////////////////////////////////////////////////////////////
// barray.CountingBloom8 ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

typedef struct {
    PyObject_HEAD
    Py_ssize_t size;
    uint8_t *barray;
    uint64_t added;
    uint8_t num_hashes;
    Py_ssize_t _size;
} CountingBloom8;

static int CountingBloom8_init(CountingBloom8* self, PyObject *args) {
    if (! PyArg_ParseTuple(args, "Kb", &self->size, &self->num_hashes))
        return -1;
    self->_size = (Py_ssize_t)self->size/8;
    self->barray = (uint8_t*)calloc((self->size + 8 - 1) / 8, 1);
    if (! self->barray) {
        PyErr_NoMemory();
        return -1;
    }
    self->added = 0;
    return 0;
}

static void CountingBloom8_dealloc(CountingBloom8* self) {
    Py_TYPE(self)->tp_free((PyObject*) self);
}

static Py_ssize_t CountingBloom8_length(CountingBloom8 *self) {
    return self->_size;
}

static inline PyObject* CountingBloom8_add(CountingBloom8* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen, bucket;
    uint64_t h1, h2;
    uint8_t i, count = 255;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) {
            bucket = (h1+i*h2) % self->_size;
            if (self->barray[bucket] < count) count = self->barray[bucket];
        }
        if (count < 255) {
            for (i = 1; i <= self->num_hashes; i++) {
                bucket = (h1+i*h2) % self->_size;
                if (self->barray[bucket] == count) self->barray[bucket] += 1;
            }
        }
        self->added++;
        return Py_BuildValue("B", count);
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return NULL;
}

static inline PyObject* CountingBloom8_getitem(CountingBloom8* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen, bucket;
    uint64_t h1, h2;
    uint8_t i, count = 255;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) {
            bucket = (h1+i*h2) % self->_size;
            if (self->barray[bucket] < count) count = self->barray[bucket];
            if (!count) return Py_BuildValue("B", count);
        }
        return Py_BuildValue("B", count);
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return NULL;
}

static inline int CountingBloom8_contains(CountingBloom8* self, PyObject *key) {
    char *bytestring = NULL;
    Py_ssize_t byteslen, bucket;
    uint64_t h1, h2;
    uint8_t i;
    if (PyBytes_Check(key)) {
        if (PyBytes_AsStringAndSize(key, &bytestring, &byteslen) == -1) goto fail;
        h1 = fnv1a_64(bytestring, byteslen);
        h2 = murmur2_64(bytestring, byteslen, 12345);
        for (i = 1; i <= self->num_hashes; i++) {
            bucket = (h1+i*h2) % self->_size;
            if (!self->barray[bucket]) return 0;
        }
        return 1;
    }
    fail:
    PyErr_SetString(PyExc_TypeError, "A key (type bytes) is required");
    return -1;
}

static PyMemberDef CountingBloom8_members[] = {
    {"added", T_ULONGLONG, offsetof(CountingBloom8, added), 0, "added"},
    {NULL}  /* Sentinel */
};

static PyMethodDef CountingBloom8_methods[] = {
    {"add", (PyCFunction) CountingBloom8_add, METH_O, "Add a key to the Bloom filter"},
    {NULL, NULL}
};

static PyMappingMethods CountingBloom8_mapping_methods = {
    .mp_length = (lenfunc) CountingBloom8_length,
    .mp_subscript = (binaryfunc) CountingBloom8_getitem
};

static PySequenceMethods CountingBloom8_sequence_methods = {
    .sq_contains = (objobjproc)CountingBloom8_contains
};

static PyTypeObject CountingBloom8Type = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,

    .tp_name = "barray.CountingBloom8",
    .tp_basicsize = sizeof(CountingBloom8),
    .tp_doc = "CountingBloom8 objects",

    .tp_init = (initproc)CountingBloom8_init,
    .tp_dealloc = (destructor)CountingBloom8_dealloc,

    .tp_methods = CountingBloom8_methods,
    .tp_members = CountingBloom8_members
};

////////////////////////////////////////////////////////////////////////////////
// module functionality ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

static PyModuleDef barraymodule = {
    PyModuleDef_HEAD_INIT,
    "barray",
    "Example module that creates an extension type.",
    -1,
    NULL, NULL, NULL, NULL, NULL
};

PyMODINIT_FUNC PyInit_barray(void) {
    PyObject* m;

    BArrayType.tp_new = &PyType_GenericNew;
    BArrayType.tp_as_mapping = &BArray_mapping_methods;
    if (PyType_Ready(&BArrayType) < 0) goto fail;

    BloomType.tp_new = &PyType_GenericNew;
    BloomType.tp_as_mapping = &Bloom_mapping_methods;
    BloomType.tp_as_sequence = &Bloom_sequence_methods;
    if (PyType_Ready(&BloomType) < 0) goto fail;

    CountingBloomType.tp_new = &PyType_GenericNew;
    CountingBloomType.tp_as_mapping = &CountingBloom_mapping_methods;
    CountingBloomType.tp_as_sequence = &CountingBloom_sequence_methods;
    if (PyType_Ready(&CountingBloomType) < 0) goto fail;

    CountingBloom8Type.tp_new = &PyType_GenericNew;
    CountingBloom8Type.tp_as_mapping = &CountingBloom8_mapping_methods;
    CountingBloom8Type.tp_as_sequence = &CountingBloom8_sequence_methods;
    if (PyType_Ready(&CountingBloom8Type) < 0) goto fail;

    m = PyModule_Create(&barraymodule);
    if (m == NULL) goto fail;

    Py_INCREF(&BArrayType);
    PyModule_AddObject(m, "BArray", (PyObject *)&BArrayType);
    Py_INCREF(&BloomType);
    PyModule_AddObject(m, "Bloom", (PyObject *)&BloomType);
    Py_INCREF(&CountingBloomType);
    PyModule_AddObject(m, "CountingBloom", (PyObject *)&CountingBloomType);
    Py_INCREF(&CountingBloom8Type);
    PyModule_AddObject(m, "CountingBloom8", (PyObject *)&CountingBloom8Type);

    return m;

    fail:
    Py_DECREF(m);
    return NULL;
}
