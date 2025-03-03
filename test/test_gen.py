import random
import merged_and_four_step as ntt
import math

random.seed(0)


# %%
q = 3329
logq = math.ceil(math.log2(q))
psi = 17
logn = 7
n = 1 << logn
mu = (1 << 24) // q
log = 12
b = 32
d = 10

with open("meta.txt", "w") as f:
    f.write(hex(q)[2:] + "\n")
    f.write(hex(mu)[2:] + "\n")
    f.write(hex(logn)[2:] + "\n")
    f.write(hex(logq)[2:] + "\n")
    f.write(hex(d)[2:] + "\n")

A_0 =  [random.randint(0, q-1) for _ in range(n)]
A_1 =  [random.randint(0, q-1) for _ in range(n)]
B_0 =  [random.randint(0, q-1) for _ in range(n)]
B_1 =  [random.randint(0, q-1) for _ in range(n)]


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


with open("mul_out_dual.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] * B_0[i]) % q
        t1 = (A_1[i] * B_1[i]) % q
        f.write(hex((t1 << (b // 2)) + t0)[2:] + "\n")


with open("mul_out_poly.txt", "w") as f:
    for i in range(n):
        t0 = (A_0[i] * B_0[i] + A_1[i] * B_1[i]) % q
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

print("PSI C:")
for i in range(n - 1):
    j = pows[i]
    print(hex(psi_table_[j]), end=", ")
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
# _, _ = ntt.INTT(A_0_ntt, psi_inv_table_, q, debug=False, flag=False)


with open("psi_inv.txt", "w") as f:
    for i in range(n - 1):
        j = pows[i]
        f.write(hex(psi_inv_table_[j])[2:] + "\n")
    f.write("0\n")



A_0_comp =  [round(((1 << d)/q)*A_0[i]) for i in range(n)]
A_1_comp =  [round(((1 << d)/q)*A_1[i]) for i in range(n)]

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