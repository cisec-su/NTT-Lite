import random
import merged_and_four_step as ntt
import math

random.seed(0)


def _br(i, k):
    bin_i = bin(i & (2**k - 1))[2:].zfill(k)
    return int(bin_i[::-1], 2)


# %%
q = 3329
logq = math.ceil(math.log2(q))
psi = 17
logn = 7
n = 1 << logn
mu_64 = (1 << 64) // q
mu_32 = (1 << 32) // q
log = 23
b = 32
d = 10
inv2 = pow(2, -1, q)

_zetas = [pow(psi, _br(i, 7), q) for i in range(n)]
zetas = []
for i in range(n//2):
    zetas.append(_zetas[n//2 + i])
    zetas.append(q - _zetas[n//2 + i])

with open("meta.txt", "w") as f:
    f.write(hex(q)[2:] + "\n")
    f.write(hex(mu_64)[2:] + "\n")
    f.write(hex(logn)[2:] + "\n")
    f.write(hex(logq)[2:] + "\n")
    f.write(hex(d)[2:] + "\n")
    f.write(hex(inv2)[2:] + "\n")
    f.write(hex(mu_32)[2:] + "\n")

A_0 =  [random.randint(0, q-1) for _ in range(n)]
A_1 =  [random.randint(0, q-1) for _ in range(n)]
B_0 =  [random.randint(0, q-1) for _ in range(n)]
B_1 =  [random.randint(0, q-1) for _ in range(n)]
Z_1 =  [random.randint(0, q-1) for _ in range(n)]

with open("poly_in_single.txt", "w") as f:
    for i in range(n):
        f.write(hex(A_0[i])[2:] + "\n")


with open("poly_in_B_single.txt", "w") as f:
    for i in range(n):
        f.write(hex(B_0[i])[2:] + "\n")


with open("poly_in_dual.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_1[i] << (b // 2)) + A_0[i])[2:] + "\n")


with open("poly_in_B_dual.txt", "w") as f:
    for i in range(n):
        f.write(hex((B_1[i] << (b // 2)) + B_0[i])[2:] + "\n")


with open("zeta_in.txt", "w") as f:
    for i in range(n):
        f.write(hex((Z_1[i]))[2:] + "\n")


# %%
with open("intt_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_0[i] * n) % q)[2:] + "\n")


with open("intt_out_dual.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] * n) % q
        t1 = (A_1[i] * n) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


# %%
with open("mul_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_0[i] * B_0[i]) % q )[2:] + "\n")

with open("mac_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_0[i] * B_0[i] + A_0[i] * B_0[i]) % q )[2:] + "\n")


with open("mac_out_poly.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] * B_0[i] + A_1[i] * B_1[i] * Z_1[i] + A_0[i]) % q
        t1 = (A_1[i] * B_0[i] + A_0[i] * B_1[i] + A_1[i]) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


with open("mul_out_dual.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] * B_0[i]) % q
        t1 = (A_1[i] * B_1[i]) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


with open("mul_out_poly.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] * B_0[i] + A_1[i] * B_1[i] * Z_1[i]) % q
        t1 = (A_1[i] * B_0[i] + A_0[i] * B_1[i]) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


with open("add_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_0[i] + B_0[i]) % q )[2:] + "\n")


with open("add_out_dual.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] + B_0[i]) % q
        t1 = (A_1[i] + B_1[i]) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


with open("add_out_dual_const.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] + B_0[0]) % q
        t1 = (A_1[i] + B_1[0]) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


with open("add_out_single_const.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] + B_0[0]) % q
        f.write(hex(t0)[2:] + "\n")


with open("sub_out_single_const_switched.txt", "w") as f:
    for i in range(n):
        t0 = (B_0[0] - A_0[i]) % q
        f.write(hex(t0)[2:] + "\n")


with open("sub_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_0[i] - B_0[i]) % q )[2:] + "\n")


with open("sub_out_dual.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] - B_0[i]) % q
        t1 = (A_1[i] - B_1[i]) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


psi_table_ = ntt.generate_ntt_tables(n, q, psi)

A_0_ntt, pows = ntt.NTT(A_0, psi_table_, q, debug=False)
A_1_ntt, _    = ntt.NTT(A_1, psi_table_, q, debug=False)



with open("ntt_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex(A_0_ntt[i])[2:] + "\n")


with open("ntt_out_dual.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_1_ntt[i] << (b // 2)) + A_0_ntt[i])[2:] + "\n")


with open("psi.txt", "w") as f:
    for i in range(n - 1):
        j = pows[i]
        f.write(hex(psi_table_[j])[2:] + "\n")
    f.write("0\n")


with open("psi_dual.txt", "w") as f:
    for i in range(n - 1):
        j = pows[i]
        f.write(hex((psi_table_[j] << (b // 2)) + psi_table_[j])[2:] + "\n")
    f.write("0\n")


print("PSI C:")
for i in range(n - 1):
    j = pows[i]
    print(hex(psi_table_[j]), end=", ")
print("\n\n")

print("PSI C DUAL:")
for i in range(n - 1):
    j = pows[i]
    print(hex((psi_table_[j] << (b // 2)) + psi_table_[j]), end=", ")
print("\n\n")

print("A DUAL C:")
for i in range(n):
    print(hex((A_1[i] << (b // 2)) + A_0[i]), end=", ")
print("\n\n")

print("A DUAL NTT:")
for i in range(n):
    print(hex((A_1_ntt[i] << (b // 2)) + A_0_ntt[i]), end=", ")
print("\n\n")


psi_inv_table_ = ntt.generate_ntt_tables(n, q, pow(psi, -1, q))
psi_inv_table_ = [(x*inv2) % q for x in psi_inv_table_]
ntt.INTT(A_0_ntt, psi_inv_table_, q, debug=False, flag=False)


with open("psi_inv.txt", "w") as f:
    for i in range(n - 1):
        j = pows[i]
        f.write(hex(psi_inv_table_[j])[2:] + "\n")
    f.write("0\n")


with open("psi_inv_dual.txt", "w") as f:
    for i in range(n - 1):
        j = pows[i]
        f.write(hex((psi_inv_table_[j] << (b // 2)) + psi_inv_table_[j])[2:] + "\n")
    f.write("0\n")



print("PSI INV C:")
for i in range(n - 1):
    j = pows[i]
    print(hex(psi_inv_table_[j]), end=", ")
print("\n\n")


print("PSI INV C DUAL:")
for i in range(n - 1):
    j = pows[i]
    print(hex((psi_inv_table_[j] << (b // 2)) + psi_inv_table_[j]), end=", ")
print("\n\n")


A_0_comp =  [round(((1 << d)/q)*A_0[i]) % (1 << d) for i in range(n)]
A_1_comp =  [round(((1 << d)/q)*A_1[i]) % (1 << d) for i in range(n)]

with open("comp_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex(A_0_comp[i])[2:] + "\n")

with open("comp_out_dual.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_1_comp[i] << (b // 2)) + A_0_comp[i])[2:] + "\n")


A_0_decomp =  [round((q/(1 << d))*A_0_comp[i]) for i in range(n)]
A_1_decomp =  [round((q/(1 << d))*A_1_comp[i]) for i in range(n)]

with open("decomp_out_single.txt", "w") as f:
    for i in range(n):
        f.write(hex(A_0_decomp[i])[2:] + "\n")

with open("decomp_out_dual.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_1_decomp[i] << (b // 2)) + A_0_decomp[i])[2:] + "\n")


A_0_bin = [random.randint(0, 1) for _ in range(n)]
A_1_bin = [random.randint(0, 1) for _ in range(n)]

with open("encode_in_poly_d1.txt", "w") as f:
    for i in range(n):
        f.write(hex((A_1_bin[i] << (b // 2)) + A_0_bin[i])[2:] + "\n")

with open("encode_out_poly_d1.txt", "w") as f:
    for i in range(n // (b // 2)):
        t = 0
        for j in range(b // 2):
            t += A_0_bin[i*(b // 2) + j] << (2*j    )
            t += A_1_bin[i*(b // 2) + j] << (2*j + 1)
        f.write(hex(t)[2:] + "\n")


A_comp = [A_0_comp[(i>>1)] if (i % 2 == 0) else A_1_comp[(i>>1)] for i in range(2*n)]

A_comp_encoded = []
t = 0
tlen = 0
for i in range(len(A_comp)):
    t = t + (A_comp[i] << tlen)
    tlen += d
    if tlen >= b:
        A_comp_encoded.append(t & ((1 << b) - 1))
        t = t >> b
        tlen = tlen - b
if tlen > 0:
    A_comp_encoded.append(t)

A_1_comp_encoded = []
t = 0
tlen = 0

with open("encode_out_poly.txt", "w") as f:
    for i in range(len(A_comp_encoded)):
        f.write(hex(A_comp_encoded[i])[2:] + "\n")


print("ZETAS C:")
for i in range(n):
    print(hex((zetas[i])), end=", ")
print("\n\n")



sum0 = 0
sum1 = 0
for i in range(n):
    sum0 += A_0[i]
    sum1 += A_1[i]
sum0 %= q
sum1 %= q

with open("sum_out_dual.txt", "w") as f:
    f.write(hex((sum1 << (b // 2)) + sum0)[2:] + "\n")

hw_lut = [bin(i).count("1") for i in range(16)]

cbd_in = [random.randint(0, 1 << 32) for _ in range((n // 4))]
cbd_out = []
for i in range(len(cbd_in)):
    t = cbd_in[i]
    for j in range(8):
        t0 = (t >> (4*j)) & 0x3
        t1 = (t >> (4*j + 2)) & 0x3
        cbd_out.append((hw_lut[t0] - hw_lut[t1]) % q)

with open("cbd_in.txt", "w") as f:
    for i in range(n // 4):
        f.write(hex(cbd_in[i])[2:] + "\n")

with open("cbd_out_dual.txt", "w") as f:
    for i in range(n):
        f.write(hex((cbd_out[(2*i) + 1] << (b // 2)) + cbd_out[2*i])[2:] + "\n")



############################# DECOMPOSE TEST ###########################

def reduce_mod_pm(r, a):
    """
    Reduces r modulo a, such that the result is in the range
    -(a >> 1) < r <= (a >> 1)
    """
    r = r % a
    if r > (a >> 1):
        r -= a
    return r

def decompose(r, a, q):
    """
    Takes an element r and represents
    it as:

    r = r1*a + r0

    With r0 in the range

    -(a << 1) < r0 <= (a << 1)
    """
    rp = r % q
    r0 = reduce_mod_pm(rp, a)
    t = rp - r0
    if t == q - 1:
        r1 = 0
        r0 = r0 - 1
    else:
        r1 = (t) // a
    # assert r0 > -(a >> 1)
    # assert r0 <= (a >> 1)
    # assert r % q == (r0 + r1 * a) % q
    return r1, r0 % q


q = 8380417
inv2 = 16
bound = (q - 1) // (inv2)
logq = math.ceil(math.log2(q))
logn = 8
n = 1 << logn
mu_64 = (1 << 64) // bound
mu_32 = (1 << 32) // bound

with open("decompose_meta.txt", "w") as f:
    f.write(hex(q)[2:] + "\n")
    f.write(hex(mu_64)[2:] + "\n")
    f.write(hex(logn)[2:] + "\n")
    f.write(hex(logq)[2:] + "\n")
    f.write(hex(d)[2:] + "\n")
    f.write(hex(inv2)[2:] + "\n")
    f.write(hex(mu_32)[2:] + "\n")
    f.write(hex(bound)[2:] + "\n")


A =  [random.randint(0, q) for _ in range(n)]

with open("decompose_in.txt", "w") as f:
    for i in range(n):
        f.write(hex(A[i])[2:] + "\n")


AD0 = []
AD1 = []

for A_i in A:
    r1, r0 = decompose(A_i, bound, q)
    AD0.append(r0)
    AD1.append(r1)


with open("decompose_out_low.txt", "w") as f:
    for i in range(n):
        f.write(hex(AD0[i])[2:] + "\n")

with open("decompose_out_high.txt", "w") as f:
    for i in range(n):
        f.write(hex(AD1[i])[2:] + "\n")


q = 8380417
bb = 16
bound =  (q - 1) // (bb)
inv2 = q - bound
logq = math.ceil(math.log2(q))
logn = 8
n = 1 << logn
mu_64 = (1 << 64) // inv2
mu_32 = (1 << 32) // inv2

with open("chknorm_makehint_meta.txt", "w") as f:
    f.write(hex(q)[2:] + "\n")
    f.write(hex(mu_64)[2:] + "\n")
    f.write(hex(logn)[2:] + "\n")
    f.write(hex(logq)[2:] + "\n")
    f.write(hex(d)[2:] + "\n")
    f.write(hex(inv2)[2:] + "\n")
    f.write(hex(mu_32)[2:] + "\n")
    f.write(hex(bound)[2:] + "\n")


A =  [random.randint(-bound, bound) % q for _ in range(n)]
A[0] = bound
A[1] = q - bound

with open("chknorm_in_succ.txt", "w") as f:
    for i in range(n):
        f.write(hex(A[i])[2:] + "\n")


A =  [random.randint(-bound, bound + 1) % q for _ in range(n)]
A[n-2] = bound + 1
A[n-1] = q - bound - 1

with open("chknorm_in_fail.txt", "w") as f:
    for i in range(n):
        f.write(hex(A[i])[2:] + "\n")


A =  [random.randint(0, q) % q for _ in range(n)]


A0 = []
A1 = []

for A_i in A:
    r1, r0 = decompose(A_i, bound, q)
    A0.append(r0)
    A1.append(r1)

print(hex(2*bound), hex(bound))
A0[0 % n] = 2*bound
A0[10 % n] = 2*bound
A0[100 % n] = q-bound
A1[100 % n] = 1
A0[200 % n] = bound + 1

with open("makehint_in_low.txt", "w") as f:
    for i in range(n):
        f.write(hex(A0[i])[2:] + "\n")

with open("makehint_in_high.txt", "w") as f:
    for i in range(n):
        f.write(hex(A1[i])[2:] + "\n")

def make_hint(a0, a1, q, bound):
    if(((a0 > bound) and (a0 < (q-bound))) or (a0 == (q-bound) and a1 != 0)):
        return 1
    else:
        return 0


hints = []

for i in range(n):
    hints.append(make_hint(A0[i], A1[i], q, bound))

with open("makehint_out.txt", "w") as f:
    for i in range(n):
        f.write(hex(hints[i])[2:] + "\n")


for i in range(n):
    if (hints[i]):
        if AD0[i] <= q//2:
            AD1[i] += 1
        else:
            AD1[i] += 15
            AD1[i] = AD1[i] % 16

with open("usehint_out.txt", "w") as f:
    for i in range(n):
        f.write(hex(AD1[i])[2:] + "\n")


############################# rej sample test ##########################


q = 0x77e001
bound = q
inv2 = 254
logq = math.ceil(math.log2(q))
logn = 8
n = 1 << logn
mu_64 = (1 << 64) // inv2
mu_32 = (1 << 32) // inv2
d = 24

with open("rejsamp32_meta.txt", "w") as f:
    f.write(hex(q)[2:] + "\n")
    f.write(hex(mu_64)[2:] + "\n")
    f.write(hex(logn)[2:] + "\n")
    f.write(hex(logq)[2:] + "\n")
    f.write(hex(d)[2:] + "\n")
    f.write(hex(inv2)[2:] + "\n")
    f.write(hex(mu_32)[2:] + "\n")
    f.write(hex(bound)[2:] + "\n")

rej_samp_in = [random.randint(0, 1 << 32) for _ in range(inv2)]

rej_samp_decoded = []
rej_samp_out = []
mem = 0
ctr = 0
for i in range(len(rej_samp_in)):
    mem = mem | (rej_samp_in[i] << ctr)
    ctr += 32
    while ctr >= d:
        t = mem & ((1 << d) - 1)
        mem = mem >> d
        ctr = ctr - d
        rej_samp_decoded.append(t)


for i in range(len(rej_samp_decoded)):
    temp = rej_samp_decoded[i] & ((1 << logq) - 1)
    if temp < bound:
        rej_samp_out.append(temp)
        if len(rej_samp_out) >= n:
            break

with open("rej_samp_in.txt", "w") as f:
    for i in range(len(rej_samp_in)):
        f.write(hex(rej_samp_in[i])[2:] + "\n")

with open("rej_samp_out.txt", "w") as f:
    for i in range(len(rej_samp_out)):
        f.write(hex(rej_samp_out[i])[2:] + "\n")


############################# rej sample eta test ##########################


q = 0x7fe001
bound = 9
inv2 = 230
logq = 4
logn = 8
n = 1 << logn
mu_64 = (1 << 64) // inv2
mu_32 = (1 << 32) // inv2
d = 4

with open("rejsampeta_meta.txt", "w") as f:
    f.write(hex(q)[2:] + "\n")
    f.write(hex(mu_64)[2:] + "\n")
    f.write(hex(logn)[2:] + "\n")
    f.write(hex(logq)[2:] + "\n")
    f.write(hex(d)[2:] + "\n")
    f.write(hex(inv2)[2:] + "\n")
    f.write(hex(mu_32)[2:] + "\n")
    f.write(hex(bound)[2:] + "\n")

rej_samp_in = [random.randint(0, 1 << 32) for _ in range(inv2)]

rej_samp_decoded = []
rej_samp_out = []
mem = 0
ctr = 0
for i in range(len(rej_samp_in)):
    mem = mem | (rej_samp_in[i] << ctr)
    ctr += 32
    while ctr >= d:
        t = mem & ((1 << d) - 1)
        mem = mem >> d
        ctr = ctr - d
        rej_samp_decoded.append(t)


for i in range(len(rej_samp_decoded)):
    if rej_samp_decoded[i] < bound:
        rej_samp_out.append(((bound >> 1) - rej_samp_decoded[i]) % q)
        if len(rej_samp_out) >= n:
            break

with open("rej_samp_eta_in.txt", "w") as f:
    for i in range(len(rej_samp_in)):
        f.write(hex(rej_samp_in[i])[2:] + "\n")

with open("rej_samp_eta_out.txt", "w") as f:
    for i in range(len(rej_samp_out)):
        f.write(hex(rej_samp_out[i])[2:] + "\n")


############################# rej sample dual test ##########################


q = 3329
bound = (q << 16) | q
inv2 = 250
logq = 12
logn = 7
n = 1 << logn
mu_64 = (1 << 64) // inv2
mu_32 = (1 << 32) // inv2
d = 12

with open("rejsampdual_meta.txt", "w") as f:
    f.write(hex(q)[2:] + "\n")
    f.write(hex(mu_64)[2:] + "\n")
    f.write(hex(logn)[2:] + "\n")
    f.write(hex(logq)[2:] + "\n")
    f.write(hex(d)[2:] + "\n")
    f.write(hex(inv2)[2:] + "\n")
    f.write(hex(mu_32)[2:] + "\n")
    f.write(hex(bound)[2:] + "\n")

rej_samp_in = [random.randint(0, 1 << 32) for _ in range(inv2)]

rej_samp_in[0] = (rej_samp_in[0] & 0xfffff000) + 0xd01


rej_samp_decoded = []
rej_samp_out = []
mem = 0
ctr = 0
for i in range(len(rej_samp_in)):
    mem = mem | (rej_samp_in[i] << ctr)
    ctr += 32
    while ctr >= d:
        t = mem & ((1 << d) - 1)
        mem = mem >> d
        ctr = ctr - d
        rej_samp_decoded.append(t)


for i in range(len(rej_samp_decoded)):
    if rej_samp_decoded[i] < q:
        rej_samp_out.append(rej_samp_decoded[i])
        if len(rej_samp_out) >= (n*2):
            break

with open("rej_samp_in_dual.txt", "w") as f:
    for i in range(len(rej_samp_in)):
        f.write(hex(rej_samp_in[i])[2:] + "\n")

with open("rej_samp_out_dual.txt", "w") as f:
    for i in range(len(rej_samp_out)//2):
        f.write(hex((rej_samp_out[(2*i) + 1] << (b // 2)) + rej_samp_out[2*i])[2:] + "\n")