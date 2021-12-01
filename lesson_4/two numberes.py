a = int(input("Enter numbers \n"))
a1 = a % 10
a = a // 10
k = 0
while a > 0:
    a2 = a % 10
    if a1 == a2:
        k += 1
    a = a // 10
    a1 = a2
if k > 0:
    print("Yes")
else:
    print("No")
