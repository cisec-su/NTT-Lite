from math import log, log2, ceil
import random
from sympy import *

import numpy as np

# --------------------------------------------------
# Authors: Can Ayduman and Enes Türkoğlu

# ---------------------------------------------------
# ------------Helper Functions ----------------------
# ---------------------------------------------------


def egcd(a, b):
    if a == 0:
        return (b, 0, 1)
    else:
        g, y, x = egcd(b % a, a)
        return (g, x - (b // a) * y, y)

def modinv(a, m):
    g, x, y = egcd(a, m)
    if g != 1:
        raise Exception('Modular inverse does not exist')
    else:
        return x % m

# Bit-Reverse integer
def intReverse(a,n):
    b = ('{:0'+str(n)+'b}').format(a)
    return int(b[::-1],2)

# Bit-Reversed index
def indexReverse(a,r):
    n = len(a)
    b = [0]*n
    for i in range(n):
        rev_idx = intReverse(i,r)
        b[rev_idx] = a[i]
    return b

# Check if input is m-th (could be n or 2n) primitive root of unity of q
def isrootofunity(w,m,q):
    if pow(w,m,q) != 1:
        return False
    elif pow(w,m//2,q) != (q-1):
        return False
    else:
        v = w
        for i in range(1,m):
            if v == 1:
                return False
            else:
                v = (v*w) % q
        return True


# ---------------------------------------------------
# ---------------------------------------------------
# ---------------------------------------------------

#--------------------------SchoolBook Multiplication---------------
def SchoolbookModPolMul_plus_1(A, B, q):
    n = len(A)
    C = [0] * (2 * n)
    D = [0] * n
    for indA, indC in enumerate(A):
        for indB, indD in enumerate(B):
            C[indA + indB] = (C[indA + indB] + indC * indD) % q

    for i in range(n):
        D[i] = (C[i] + C[i + n]) % q

    return D

def SchoolbookModPolMul_minus_1(A, B, q):
    n = len(A)
    C = [0] * (2 * n)
    D = [0] * n
    for indA, indC in enumerate(A):
        for indB, indD in enumerate(B):
            C[indA + indB] = (C[indA + indB] + indC * indD) % q

    for i in range(n):
        D[i] = (C[i] - C[i + n]) % q

    return D


def generate_psi_table(w, n, q):
    psi_table = []
    for i in range(int(n / 2)):
        index_re = intReverse(i, int(log(int(n / 2), 2)))
        psi_table.append(pow(w, index_re, q))
    return psi_table


def legacy_NTT(A, W, q):

    B = [0 for i in range(len(A))]

    for i in range(len(A)):
        for j in range(len(A)):
            B[i] += (A[j] * pow(W, (2*i + 1)*j, q)) % q
        B[i] = B[i] % q

    return B


#--------------------------Four-Step INTT--------------------------
def generate_psi_inv_table(w, n, q):

    psi_table = []
    for i in range(int(n / 2)):
        index_re = intReverse(i, int(log(int(n / 2), 2)))
        psi_table.append(pow(w, index_re, q))

    return psi_table



def arr_bit_reverse(A, n):
    B = [0] * n
    for i in range(n):
        B[intReverse(i, int(log(n, 2)))] = A[i]
    return B


#----------------------------------Merge NTT----------------------------------------

def NTT(A, Psi_table, q, debug=False):
    N = len(A)
    B = [_ for _ in A]

    if N == 1:
        return B

    l = int(log(N, 2))
    MulCnt, AddCnt, SubCnt, BtfCnt = 0, 0, 0, 0

    t = N
    m = 1
    counterr = 0
    pows = []
    if debug:
        print([(Bi, hex(B[Bi])) for Bi in range(len(B))])
    while (m < N):
        #print("----------------------",counterr, "------------------------------------")
        counterr += 1
        t = int(t / 2)
        for i in range(m):
            j1 = 2 * i * t
            j2 = j1 + t - 1
            Psi_pow = intReverse(m + i, l)
            # print('Psi_pow', Psi_pow)
            S = Psi_table[Psi_pow]
            pows.append(Psi_pow)
            if debug:
                print(f"Psi_pow: {Psi_pow} S: {(hex(S))}")

            for j in range(j1, j2 + 1):

                U = B[j]
                V = (B[j + t] * S) % q
                #print("{} {} {} {}".format(hex(B[j]), hex(B[j + t]), hex((S*2**39)%q), hex(q)))
                B[j] = (U + V) % q
                B[j + t] = (U - V) % q

                #print("A[{}] ve A[{}] + W^{} --> A[{}] ve A[{}] ".format(j, j + t, Psi_pow, j, j + t ))
        if debug:
            print([(Bi, hex(B[Bi])) for Bi in range(len(B))])

        m = 2 * m
    #print(counterr)
    # return arr_bit_reverse(B, N)
    return B, pows
#----------------------------------Merge INTT----------------------------------------

def INTT(A, Psi_table, q, rev=True, flag=True, debug=True):
    counterr = 0
    N = len(A)
    B = [_ for _ in A]

    l = int(log(N, 2))

    pows = []

    MulCnt, AddCnt, SubCnt, BtfCnt = 0, 0, 0, 0

    t = 1
    m = N
    if debug:
        print([(Bi, hex(B[Bi])) for Bi in range(len(B))])
    while (m > 1):
        j1 = 0
        h = int(m / 2)
        for i in range(h):

            j2 = j1 + t - 1
            Psi_pow = intReverse(h + i, l)
            # print('Psi_pow', Psi_pow)
            S = Psi_table[Psi_pow]
            pows.append(Psi_pow)
            if debug:
                print(f"Psi_pow: {Psi_pow} S: {(hex(S))}")

            counterr += 1
            #print(S)
            for j in range(j1, j2 + 1):
                #print(S)
                U = B[j]
                V = B[j + t]

                B[j] = (U + V) % q
                a = (U - V) * S
                B[j + t] = a % q
                if not flag:
                    B[j]     = (B[j   ] * pow(2,-1,q)) % q
            j1 = j1 + 2 * t
        t = 2 * t
        m = int(m / 2)

        if debug:
            print([(Bi, hex(B[Bi])) for Bi in range(len(B))])


    if flag:
        N_inv = modinv(N, q)
        for i in range(N):
            B[i] = (B[i] * N_inv) % q

    return B, pows

# Psi table for Merge NTT
def generate_ntt_tables(n, q, np):
    t0 = [1]*n

    for i in range(1,n):
        t0[i] = (t0[i-1] * np) % q

    return t0

