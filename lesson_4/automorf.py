n = int(input("enter number \n"))
for i in range(1, n):
    a = 10
    while i >= a:
        a = a * 10
    if (i * i % a) == i:
        print("number", i, "quatro number", i * i)
