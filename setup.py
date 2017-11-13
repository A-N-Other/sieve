from distutils.core import setup, Extension
from sys import maxsize

if not maxsize > 2**32:
    raise('Sieve requires compilation with a 64-bit Python3 / PyPy3 build')

extern = [
    Extension('barray.barray', ['src/barray.c', 'src/hashes.c'],
        extra_compile_args=['-m64']),
    Extension('utils.utils', ['src/utils.c'],
        extra_compile_args=['-m64'])
    ]

setup(
    ext_package='PySembler',
    ext_modules=extern
)

# python3 setup.py build_ext --inplace
