def ger(x, y):
    if 0 < x < y < 101:
            for i in range(x, y):
                if i % 2 != 0:
                    yield i
    else:
        print("False, only numbers 1-100")


a = ger(int(input("enter from num \n")), int(input("enter untill num \n")))
print(next(a), end=" ")







