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

#--------------------------Four-Step NTT--------------------------

def w_table_gen(n1, n2, q, w):
    w_table = []
    z = int(log2(n2))
    for i in range(n2):
        for j in range(n1):
            index_reverse = intReverse(i, z)
            w_table.append(pow(w,(index_reverse * j),q))#((w ** (index_reverse * j)) % q)

    return w_table


def w_table_gen(n1, n2, q, w):
    w_table = []
    z = int(log2(n2))
    for i in range(n2):
        for j in range(n1):
            index_reverse = intReverse(i, z)
            w_table.append(pow(w,2*(index_reverse)* j,q))#((w ** (index_reverse * j)) % q)

    return w_table




def w_inv_table_gen(size, q, w):
    w_table = []
    z = int(log2(size[1]))
    for i in range(size[0]):
        for j in range(size[1]):
            index_reverse = intReverse(j, z)
            w_table.append(pow(w,(index_reverse * i),q))#((w ** (i * index_reverse)) % q)

    return w_table


def generate_psi_table(w, n, q):
    psi_table = []
    for i in range(int(n / 2)):
        index_re = intReverse(i, int(log(int(n / 2), 2)))
        psi_table.append(pow(w, index_re, q))
    return psi_table




def CTNTT_GPU(A, psi_table, q):

    N = len(A)
    counter = 0
    for i in range(int(log(N, 2)), 0, -1):
        #print("----------------------------------")
        m = pow(2,i)
        counter = -1
        for j in range(int(N / m)):
            counter += 1
            for k in range(int(m / 2)):

                U = A[j * m + k]
                V = (psi_table[counter] * A[j * m + k + int(m / 2)]) % q

                #print("A[{}] ve A[{}] + W^{} --> A[{}] ve A[{}] ".format(j * m + k, j * m + k + int(m / 2), counter,   j * m + k, j * m + k + int(m / 2)))

                A[j * m + k] = (U + V) % q
                A[j * m + k + int(m / 2)] = (U - V) % q

    return A

def get_column_vector(matrix, j):
    return [matrix[i][j] for i in range(len(matrix))]

def set_column_vector(matrix, j, vector):
    assert len(matrix) == len(vector)
    for i in range(len(matrix)):
        matrix[i][j] = vector[i]


def arr_bit_reverse(A, n):
    B = [0] * n
    for i in range(n):
        B[intReverse(i, int(log(n, 2)))] = A[i]
    return B


def legacy_NTT(A, W, q):

    B = [0 for i in range(len(A))]

    for i in range(len(A)):
        for j in range(len(A)):
            B[i] += (A[j] * pow(W, (2*i + 1)*j, q)) % q
        B[i] = B[i] % q

    return B


def fourstepNTT_negacyclic(A, W, q, size):

    # W is primitive 2n-th root of unity

    n = len(A)
    n1, n2 = size[0], size[1]


    matrix = [[0 for i in range(n2)] for _ in range(n1)]
    for i in range(n1):
        for j in range(n2):
            matrix[i][j] = (A[((i * n2) + j) % n])


    # Cooley Tukey (CT) Part
    W_0 = pow(W, n // n1, q) # primitive 2n1-th root of unity
    psitable = generate_ntt_tables(n1, q, W_0)
    for i in range(n2):
        set_column_vector(matrix, i, NTT(get_column_vector(matrix,i), psitable, q))


    table = [[0 for _ in range(n2)] for _ in range(n1)]
    for i in range(n1//2):
        t = n1 - 1 - 2*i
        print('i:', i, t)
        for j in range(1, n2):
            table[i][j] = 2*n1*n2 - t*j
    print('table:', table)

    for i in range(n1//2):
        t = 2*i + 1
        for j in range(1, n2):
            table[i + (n1//2)][j] = t*j

    print('table:', table)

    # table = [[0, 29, 26, 23],[0, 1, 2, 3],[0, 31, 30, 29],[0, 3, 6, 9]]

    for i in range(n1):
        for j in range(n2):
            print(i, j, table[i][j])
            t = pow(W, table[intReverse(i,int(log(n1, 2)))][j], q)
            matrix[i][j] = ((matrix[i][j] * t) % q)

    W_1 = pow(W, n // n2, q)
    psitable = generate_ntt_tables(n2, q, W_1)

    # CT part
    for i in range(n1):
        matrix[i] = NTT(matrix[i], psitable, q) # of size n2

    # Transpose
    # Converting from matrix to array
    RES = []
    for i in range(len(matrix)):
        for j in range(len(matrix[0])):
            RES.append(matrix[i][j])

    print()
    print()
    print()

    return RES


#--------------------------Four-Step INTT--------------------------
def generate_psi_inv_table(w, n, q):

    psi_table = []
    for i in range(int(n / 2)):
        index_re = intReverse(i, int(log(int(n / 2), 2)))
        psi_table.append(pow(w, index_re, q))

    return psi_table


def GSNTT_GPU(A, psi_table, q):

    N = len(A)
    B = [_ for _ in A]

    m = 1
    v = N
    d = 1

    while v > 1:
        for jf in range(m):
            j = jf
            jt = 0
            counter = 0
            while j < (N - 1):

                temp = B[j]

                B[j] = (temp + B[j + d]) % q
                B[j + d] = (temp - B[j + d]) * psi_table[counter] % q

                counter += 1

                jt = jt + 1
                j = j + 2 * m

        m = 2 * m
        v = int(v / 2)
        d = 2 * d

    return B


def fourstepINTT(A, W, q, size):

    n = len(A)
    A =  arr_bit_reverse(A, n)

    n1 = size[0]
    n2 = size[1]

    STEP_1 = [[] for _ in range(n2)]
    counter = 0
    for i in range(n1):
        for j in range(n2):
            STEP_1[counter // n1].append(A[i + (j * (n1))])
            counter += 1

    print('sdadsasdasd')
    print(STEP_1)
    return

    # GS  Part
    W_0 = pow(W, int(n / n1), q)
    psitable = generate_psi_inv_table(W_0, n1, q)
    for i in range(n2):
        STEP_1[i] = GSNTT_GPU(STEP_1[i], psitable, q)

    STEP2 = [[] for _ in range(len(STEP_1[0]))]
    # Transpose
    for i in range(len(STEP_1[0])):
        for j in range(len(STEP_1)):
            STEP2[i].append(STEP_1[j][i])

    w_table = w_inv_table_gen(size, q, W)
    STEP3 = [[] for _ in range(len(STEP2))]
    # Multiply with w
    for i in range(len(STEP2)):
        for j in range(len(STEP2[0])):
            STEP3[i].append(STEP2[i][j] * w_table[i * len(STEP2[0]) + j] % q)

    W_1 = pow(W, int(n / n2), q)
    psitable = generate_psi_inv_table(W_1, n2, q)
    # GS part
    for i in range(n1):
        STEP3[i] = GSNTT_GPU(STEP3[i], psitable, q)

    # Transpose
    STEP4 = [[] for _ in range(len(STEP3[0]))]
    for i in range(len(STEP3[0])):
        for j in range(len(STEP3)):
            STEP4[i].append(STEP3[j][i])

    # Converting from matrix to array
    RES = []
    for i in range(len(STEP4)):
        for j in range(len(STEP4[0])):
            RES.append(STEP4[i][j])

    N_inv = modinv(n, q)
    for i in range(n):
        RES[i] = (RES[i] * N_inv) % q

    return RES


# a0 a1 a2 a3
# a4 a5 a6 a7
# a8 a9 a10 a11
# a12 a13 a14 a15



# a0 a2
# a1 a3

# a0 a1 W^1
# a2 a3 W^3

# multiply twiddle factor

# a0 a2 W^2
# a1 a3 W^2


# merged
# (a0 + a1)     (a0 - a1)*W1
# (a2 + a3)     (a2 - a3)*W3

# (a0 + a1 + a2 + a3)                      (a0 + a1 - a2 - a3)*W^2
# (a0 - a1)*W^1 + (a2 - a3)*W^3              ((a0 - a1)*W^3 + (a2 - a3)*W^1)


# first step

# (a0 + a1)     (a0 - a1)*W^2
# (a2 + a3)     (a2 - a3)*W^2



# (a0 + a1)*W00     (a0 - a1)*W^2*W01
# (a2 + a3)*W10     (a2 - a3)*W^2*W11


# (a0 + a1)*W00 + (a2 + a3)*W10              ((a0 + a1)*W00 - (a2 + a3)*W10)*W^2
# (a0 - a1)*W^2*W01 + (a2 - a3)*W^2*W11        ((a0 - a1)*W^2*W01 - (a2 - a3)*W^2*W11)*W^2


# W00, W10 = 1, 1
# W01, W11 = W^7, W^1


def fourstepINTT_negacyclic(A, W, q, size):

    n = len(A)
    # A = arr_bit_reverse(A, n)

    n1 = size[0]
    n2 = size[1]

    matrix = [[0 for _ in range(n2)] for _ in range(n1)]
    print('INTT')
    for i in range(n1):
        for j in range(n2):
            matrix[i][j] = (A[((i * n2) + j) % n])
    # GS  Part
    print(matrix)

    print('INTT STEP 1')

    W_0 = pow(W, n // n2, q)
    psitable = generate_ntt_tables(n2, q, W_0)
    for i in range(n1):
        matrix[i] = INTT(matrix[i], psitable, q, rev=False, flag=False)

    print('INTT STEP 1 DONE')
    print(matrix)

    table = [[0 for _ in range(n2)] for _ in range(n1)]
    for i in range(n1//2):
        t = n1 - 1 - 2*i
        print('i:', i, t)
        for j in range(1, n2):
            table[i][j] = 2*n1*n2 - t*j
    print('table:', table)

    for i in range(n1//2):
        t = 2*i + 1
        for j in range(1, n2):
            table[i + (n1//2)][j] = t*j

    # table = [[0, 0], [7, 1]]
    print('table:', table)

    for i in range(n1):
        for j in range(n2):
            print(i, j, table[i][j])
            t = pow(W, table[intReverse(i,int(log(n1, 2)))][j], q)
            matrix[i][j] = ((matrix[i][j] * t) % q) 
    print(matrix)

    print('INTT STEP 2')


    W_1 = pow(W, n // n1, q)
    psitable = generate_ntt_tables(n1, q, W_1)
    # GS part
    for i in range(n2):
        set_column_vector(matrix, i, INTT(get_column_vector(matrix,i), psitable, q, rev=False, flag=False))

    print('INTT STEP 2 DONE')
    print(matrix)

    # Converting from matrix to array
    RES = []
    for i in range(len(matrix)):
        for j in range(len(matrix[0])):
            RES.append(matrix[i][j])

    N_inv = modinv(n, q)
    for i in range(n):
        RES[i] = (RES[i] * N_inv) % q

    return RES


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
            print([hex(Bi) for Bi in B])

        m = 2 * m
    #print(counterr)
    # return arr_bit_reverse(B, N)
    return B
#----------------------------------Merge INTT----------------------------------------

def INTT(A, Psi_table, q, rev=True, flag=True):
    counterr = 0
    N = len(A)
    B = [_ for _ in A]
    # if rev:
    #     B = arr_bit_reverse(B, N)

    l = int(log(N, 2))

    MulCnt, AddCnt, SubCnt, BtfCnt = 0, 0, 0, 0

    t = 1
    m = N
    while (m > 1):
        j1 = 0
        h = int(m / 2)
        for i in range(h):

            j2 = j1 + t - 1
            Psi_pow = intReverse(h + i, l)
            # print('Psi_pow', Psi_pow)
            S = Psi_table[Psi_pow]
            counterr += 1
            #print(S)
            for j in range(j1, j2 + 1):
                #print(S)
                U = B[j]
                V = B[j + t]

                B[j] = (U + V) % q
                a = (U - V) * S
                B[j + t] = a % q
            j1 = j1 + 2 * t
        t = 2 * t
        m = int(m / 2)

    if flag:
        N_inv = modinv(N, q)
        for i in range(N):
            B[i] = (B[i] * N_inv) % q

    if rev:
        return B
    else:
        return B #arr_bit_reverse(B, N)

# Psi table for Merge NTT
def generate_ntt_tables(n, q, np):
    t0 = [1]*n

    for i in range(1,n):
        t0[i] = (t0[i-1] * np) % q

    return t0



if __name__ == "__main__":

    size = [8, 16]
    n = size[0] * size[1]

    random.seed(0)

    #q = (2 ** 64) - (2 ** 32) + 1
    q = 0x7ffe0001 #2147352577
    #w = int(8 ** (64 / n))
    #w_inv = modinv(w, q)

    # n_temp = 65536

    # mod = 2
    # wfound = False
    # while (not (wfound)):
    #     #q = generate_large_prime(q_bit)
    #     q = 0x7ffe0001  # 2147352577

    #     # check q = 1 (mod n or 2n)
    #     while (not ((q % (mod * n_temp)) == 1)):
    #         #q = generate_large_prime(q_bit)
    #         q = 0x7ffe0001  # 2147352577
    #     # generate NTT parameters
    #     for i in range(2, q - 1):
    #         wfound = isrootofunity(i, mod * n_temp, q)
    #         if wfound:
    #             if mod == 1:
    #                 psi = 0
    #                 psi_inv = 0
    #                 w = i
    #                 w_inv = modinv(w, q)
    #             else:
    #                 psi = i
    #                 psi_inv = modinv(psi, q)
    #                 w = pow(psi, 2, q)
    #                 w_inv = modinv(w, q)
    #             break
    
    psi = pow(1910599077,1024//n,q) # pow(psi, n_temp//n, q) #primitive 2n-th root of unity
    psi_inv = modinv(psi, q)
    w = pow(psi, 2, q) #primitive n-th root of unity
    w_inv = modinv(w, q)
    print(w)
    print(psi)

    #----- Create Random Inputs -------

    A = [random.randint(0, q - 1) for x in range(n)]
    #print("A: ", A)

    f0 = open('NTT_Inputs_decimal.txt', 'w')
    for i in range(n):
        f0.write('{}'.format(A[i]))
        f0.write('\n')
    f0.close()

    B = [random.randint(0, q - 1) for x in range(n)]

    #-------Four-Step NTT -------

    A_NTT = fourstepNTT_negacyclic(A, psi, q, size)
    B_NTT = fourstepNTT_negacyclic(B, psi, q, size)

    # -------Merge NTT -------
    psi_table = generate_ntt_tables(n, q, pow(psi, 1, q))
    print('psi len', len(psi_table))
    print(psi_table[0], psi_table[-1])

    A_NTT_merge = NTT(A, psi_table, q)
    B_NTT_merge = NTT(B, psi_table, q)

    A_NTT_legacy = legacy_NTT(A, psi, q)

    print(A_NTT[:16])
    print(A_NTT_merge[:16])
    print(A_NTT_legacy[:16])

    if A_NTT[0] in A_NTT_merge:
        print("**************4-step NTT may be correct*********************")
    if A_NTT == A_NTT_merge:
        print("**************4-step NTT is correct*********************")
    if A_NTT_legacy == A_NTT_merge:
        print("**************legacy NTT is correct*********************")
    # while True:
    #     pass
    ctr = 0
    for num in A_NTT:
        if num in A_NTT_merge:
            ctr += 1

    print(ctr)
    f1 = open('NTT_Outputs_decimal.txt', 'w')
    for i in range(n):
        f1.write('{}'.format(A_NTT_merge[i]))
        f1.write('\n')
    f1.close()

    res = []
    res_merge = []

    for i in range(n):
        res.append((A_NTT[i] * B_NTT[i]) % q)
        res_merge.append((A_NTT_merge[i] * B_NTT_merge[i]) % q)


    print([i for i in range(n)])
    INTT_res = fourstepINTT([i for i in range(n)], psi_inv, q, size)

    INTT_res = fourstepINTT_negacyclic(res, psi_inv, q, size)

    psi_table_inv = generate_ntt_tables(n, q, pow(psi_inv, 1, q))
    INTT_res_merge = INTT(res_merge, psi_table_inv, q)

    if INTT_res[0] in INTT_res_merge:
        print("**************4-step INTT may be correct*********************")
    if INTT_res == INTT_res_merge:
        print("**************4-step INTT is correct*********************")

    print('res is')
    print(INTT_res[:16])
    print(INTT_res_merge[:16])



    check_res_plus_1 = []
    check_res_plus_1 = SchoolbookModPolMul_plus_1(A, B, q)

    check_res_minus_1 = []
    check_res_minus_1 = SchoolbookModPolMul_minus_1(A, B, q)

    print("----------------Parameters---------------\n")

    print("Ring size    : ", n)
    print("Size         : ", size)
    print("q            :", q)
    print("psi          :", psi)
    print("psiv            :", psi_inv)

    print("******************************************\n")

    if INTT_res == check_res_minus_1:

        print("**********Correct_Four_Step*************")

    else:

        print("**********Incorrect_Four_Step*************")

    if INTT_res_merge == check_res_minus_1:

        print("**********Correct_Merge*************")

    else:

        print("**********Incorrect_Merge*************")

    # Decimal to Hexadecimal -----------> Check FGPA results

    # --------------------Input NTT---------------------------------

    with open("NTT_Inputs_decimal.txt") as file_in:
        lines = []
        for i, line in enumerate(file_in):
            lines.append(int(line.lstrip('\n')))

    hexx = []
    for i in range(len(lines)):
        hexx.append(hex(lines[i])[2:])
    for j in range(len(hexx)):
        hexx[i] = hexx[i]

    f0 = open('NTT_Input_hexa.txt', 'w')

    for i in range(n):
        f0.write('{}'.format(hexx[i]))
        f0.write('\n')
    f0.close()


    #--------------------Output NTT---------------------------------

    with open("NTT_Outputs_decimal.txt") as file_in:
        lines = []
        for i,line in enumerate(file_in):
                lines.append(int(line.lstrip('\n')))


    hexx = []
    for i in range (len(lines)):
        hexx.append(hex(lines[i])[2:])
    for j in range(len(hexx)):
        hexx[i] = hexx[i]


    f0 = open('NTT_Output_hexa.txt','w')

    for i in range(n):
        f0.write('{}'.format(hexx[i]))
        f0.write('\n')
    f0.close()
