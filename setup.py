#! /usr/bin/env python3

from distutils.core import setup, Extension
from sys import maxsize

from Cython.Build import cythonize


if not maxsize > 2**32:
    raise('Sieve requires compilation with a 64-bit Python3 / PyPy3 build')

extensions = [
    Extension('sieve.structures.seqrecord', ['sieve/structures/seqrecord.pyx'],
        extra_compile_args=['-O3']),
    Extension('sieve.barray.barray', ['sieve/barray/barray.pyx'],
        extra_compile_args=['-O3']),
    Extension('sieve.utils.utils', ['sieve/utils/utils.pyx'],
        extra_compile_args=['-O3']),
    Extension('sieve.io.i', ['sieve/io/i.pyx'],
        extra_compile_args=['-O3'], libraries=['z'])
    ]

setup(ext_modules=cythonize(extensions))


# setup.py build_ext --inplace
