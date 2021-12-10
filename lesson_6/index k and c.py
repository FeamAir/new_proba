import random

say = [random.randint(1, 10) for i in range(10)]
print(say)
k = int(input("enter index"))
c = int(input("enter change index"))
d = int(input("enter add number"))
say = say[:k]+[c]+say[k:]
print(say)
say.append(d)
print(say)
say.sort()
print(say)
