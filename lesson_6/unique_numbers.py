import random

lst1 = [random.randint(1, 10) for i in range(5)]
lst2 = [random.randint(1, 10) for i in range(5)]
print(lst1,"\n", lst2)
lst = []
cnt = 0
a = lst1 + lst2
for i in a:
    if a.count(i) == 1:
        lst.append(i)
        cnt += 1
print(f"{lst}, summary unique numbers = {cnt}")

# or

# lst1 = [random.randint(1, 10) for i in range(5)]
# lst2 = [random.randint(1, 10) for i in range(5)]
# print(lst1, "\n", lst2)
# a = lst1 + lst2
# print("summary unique numbers =", len(list([i for i in a if a.count(i) == 1])))
