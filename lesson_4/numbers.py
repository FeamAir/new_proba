say = input('enter number \n')
a = 0
for i in range(0, len(say)):
    for b in range(i + 1, len(say)):
        if say[i] == say[b]:
            a += 1
if a > 0:
    print("Yes")
else:
    print("NO")
