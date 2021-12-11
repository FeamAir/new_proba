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


# say = [0, 1, 2, 3, 4, 5, 6]
# k = (4)
# print(type(k))
# c = (5)
# say1 = say + [c]
# print(say1)
# for i in range(k, len(say1)-1):
#     say1[-1],say1[k] = say1[k],say1[-1]
# print(say1)

# say1[-1],say1[k] = say1[k],say1[-1]