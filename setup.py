#! /usr/bin/env python3

from distutils.core import setup, Extension
from sys import maxsize

from numpy import get_include
from Cython.Build import cythonize


if not maxsize > 2**32:
    raise('Sieve requires compilation with a 64-bit Python3 / PyPy3 build')

extensions = [
    # structures
    Extension('sieve.structures.seqrecord', ['sieve/structures/seqrecord.pyx'],
        extra_compile_args=['-O3']),
    # barray
    Extension('sieve.barray.barray', ['sieve/barray/barray.pyx'],
        extra_compile_args=['-O3']),
    # utils
    Extension('sieve.utils.utils', ['sieve/utils/utils.pyx'],
        extra_compile_args=['-O3']),
    Extension('sieve.utils.needle', ['sieve/utils/needle.pyx'],
        extra_compile_args=['-O3'], include_dirs=[get_include()]),
    # io
    Extension('sieve.io.i', ['sieve/io/i.pyx'],
        extra_compile_args=['-O3'], libraries=['z'])
    ]

setup(ext_modules=cythonize(extensions))


# setup.py build_ext --inplace
