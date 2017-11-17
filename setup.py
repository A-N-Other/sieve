#! /usr/bin/env python3

from distutils.core import setup
from sys import maxsize

from Cython.Build import cythonize


if not maxsize > 2**32:
    raise('Sieve requires compilation with a 64-bit Python3 / PyPy3 build')

setup(
    ext_modules=cythonize([
        'sieve/barray/barray.pyx',
        'sieve/utils/utils.pyx'])
)


# setup.py build_ext --inplace
