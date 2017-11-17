# GY171117

from math import ceil

trans = bytes.maketrans(b'atcg', b'tagc')


def grouper(bytestring, k):
    ''' Yields a bytestring in chunks of length k '''
    for i in range(ceil(len(bytestring) / k)):
        yield bytestring[i*k:i*k+k]


def iterkmers(bytestring, k, step=1):
    ''' Yields all possible kmers of length k from a bytestring '''
    for i in range(0, len(bytestring) - k + 1, step):
        yield bytestring[i:i+k]


def canonical(bytestring, pos=0):
    return bytestring[::-1].translate(trans) \
        if (bytestring[pos] == 84 or bytestring[pos] == 71) \
        else bytestring
