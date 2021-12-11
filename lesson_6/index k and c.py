import random

say = [random.randint(1, 10) for i in range(10)]
print(say)
k = int(input("enter index"))
c = int(input("enter change index"))
say.append(c)
for a in range(len(say) - 1, k, -1):
    say[a], say[a - 1] = say[a - 1], say[a]
print(say)
say.sort()
print(say)
