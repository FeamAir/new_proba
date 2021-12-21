def ger(x, y):
    for num in range(x, y):
        if num > 1:
            for i in range(2, num):
                if (num % i) == 0:
                    break
            else:
                yield num


a = ger(int(input("enter from num \n")), int(input("enter untill num \n")))
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
