import random

say = [random.randint(1, 10) for i in range(10)]
print(say)
k = int(input("enter index"))
c = int(input("enter change index"))
d = int(input("enter add number"))
for i in range(k, len(say) - 1):
    say.append(c)
    say[-1], say[k] = say[k], say[-1]
    break
print(say)
say.append(d)
say.sort()
print(say)
