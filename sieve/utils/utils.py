# GY171110

from math import ceil


__all__ = ['Utils']


class Utils(object):

    @staticmethod
    def grouper(bytestring, k):
        ''' Yields a bytestring in chunks of length k '''
        for i in range(ceil(len(bytestring)/k)):
            yield bytestring[i*k:i*k+k]

    @staticmethod
    def iterkmers(bytestring, k, step=1):
        ''' Yields all possible kmers of length k from a bytestring '''
        for i in range(0, len(bytestring)-k+1, step):
            yield bytestring[i:i+k]
