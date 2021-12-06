a = list(input("numbers"))
b = list(input("numbers"))
c = []
print(a, b)
for i in a:
    if i in c:
        continue
    for j in b:
        if i == j:
            c.append(i)
            break
print(c)

# or
# еще в работе
# a = list(input("numbers"))
# b = list(input("numbers"))
# c = []
# print(f"{['yes' for i in a for j in b if i == j]}")
