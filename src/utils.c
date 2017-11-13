#include <Python.h>
#include <string.h>
#include <math.h>

typedef struct {
    PyObject_HEAD
} Utils;

////////////////////////////////////////////////////////////////////////////////
// bytestring slicing //////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

static inline PyObject* Utils_grouper(Utils* self, PyObject* args) {
    char *bytestring = NULL;
    int k, i;
    if (! PyArg_ParseTuple(args, "yi", &bytestring, &k)) {
        PyErr_SetString(PyExc_TypeError, "A bytes string and a kmer length is required");
        return NULL;
    }
    size_t len = strlen(bytestring);
    Py_ssize_t chunks = ceil(len/k);
    PyObject* tup = PyTuple_New(chunks);
    if (! tup)
        return NULL;
    char *substr = (char*)malloc(k+1);
    for (i = 0; i < chunks; i++) {
        memset(substr, '\0', k+1);
        strncpy(substr, &bytestring[i*k], k);
        PyObject* tmp = Py_BuildValue("y", substr);
        if (!tmp) {
            Py_DECREF(tup);
            return NULL;
        }
        PyTuple_SET_ITEM(tup, i, tmp);
    }
    return tup;
}

static inline PyObject* Utils_iterkmers(Utils* self, PyObject* args) {
    char *bytestring = NULL;
    int k, step, i;
    if (! PyArg_ParseTuple(args, "yii", &bytestring, &k, &step)) {
        PyErr_SetString(PyExc_TypeError, "A bytes string, kmer length, and step value are required");
        return NULL;
    }
    Py_ssize_t chunks = ceil((strlen(bytestring)-k+1)/step);
    PyObject* tup = PyTuple_New(chunks);
    if (! tup)
        return NULL;
    char *substr = (char*)malloc(k+1);
    for (i = 0; i < chunks; i++) {
        memset(substr, '\0', k+1);
        strncpy(substr, &bytestring[i*step], k);
        PyObject* tmp = Py_BuildValue("y", substr);
        if (!tmp) {
            Py_DECREF(tup);
            return NULL;
        }
        PyTuple_SET_ITEM(tup, i, tmp);
    }
    return tup;
}

////////////////////////////////////////////////////////////////////////////////
// module functionality ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

static PyMethodDef Utils_methods[] = {
    {"grouper", (PyCFunction) Utils_grouper, METH_VARARGS, "Split bytestrings into chunks of length k"},
    {"iterkmers", (PyCFunction) Utils_iterkmers, METH_VARARGS, "Split bytestrings into kmers"},
    {NULL, NULL}
};

static PyTypeObject UtilsType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_flags = Py_TPFLAGS_DEFAULT,

    .tp_name = "utils.Utils",
    .tp_basicsize = sizeof(Utils),
    .tp_doc = "Utils objects",

    .tp_methods = Utils_methods,
};

static PyModuleDef utilsmodule = {
    PyModuleDef_HEAD_INIT,
    "utils",
    "Example module that creates an extension type.",
    -1,
    NULL, NULL, NULL, NULL, NULL
};

PyMODINIT_FUNC PyInit_utils(void) {
    PyObject* m;

    UtilsType.tp_new = &PyType_GenericNew;
    if (PyType_Ready(&UtilsType) < 0) goto fail;
    m = PyModule_Create(&utilsmodule);
    if (m == NULL) goto fail;
    Py_INCREF(&UtilsType);
    PyModule_AddObject(m, "Utils", (PyObject *)&UtilsType);
    return m;

    fail:
    Py_DECREF(m);
    return NULL;
}
