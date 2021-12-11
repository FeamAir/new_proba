import random

lst = [random.randint(0,10) for i in range(10)]
print(lst)
uniq_num = []
for i in lst:
    if lst.count(i) == 1:
        uniq_num.append(i)
t = tuple(uniq_num)
print(t, type(t))