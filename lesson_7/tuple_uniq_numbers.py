import random

lst = [random.randint(0, 10) for i in range(10)]
print(lst)
unique_numbers = []
for i in lst:
    if lst.count(i) == 1:
        unique_numbers.append(i)
unique_numbers.reverse()
t = tuple(unique_numbers)
print(t, type(t))
