import random

print(len(set([int(i) for i in input().split()])))

# or хочу что бы не только подсчет выводился но и сам список с которого он считает
# print(len(set([i for i in {random.randint(0, 10) for i in range(10)}])))
