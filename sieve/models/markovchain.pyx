from collections import defaultdict as dd
from math import log


__all__ = ['MarkovChain']


class MarkovChain(object):

    def __init__(self, order=1):
        self.order = order
        self.longestMer = order + 1
        self.mers = dd(int)

    def train(self, sequences):
        ''' Build the mer dict based on input sequences '''
        for s in sequences:
            s = s.upper()
            for i in range(len(s) - self.order):
                for j in range(self.order + 2):
                    self.mers[s[i:i+j]] += 1

    def _prob(self, obs):
        ''' Probability of obs having had `obs`[:-1], or an estimate based on
        GC content if `obs` has not been observed during training '''
        count_obs = self.mers.get(obs, None)
        if count_obs is None:
            return self._prob(obs[-1])
        return count_obs / self.mers[obs[:-1]]

    def prob(self, s):
        ''' Probability of observing `s` '''
        P = 1
        for i in range(1, self.order + 1):
            P *= self._prob(s[:i])
        for i in range(len(s) - self.order):
            P *= self._prob(s[i:i+self.order+1])
        return P

    def logprob(self, s, base=2):
        ''' Log probability of observing `s` '''
        P = 0
        for i in range(1, self.order + 1):
            P += log(self._prob(s[:i]), base)
        for i in range(len(s) - self.order):
            P += log(self._prob(s[i:i+self.order+1]), 2)
        return P
