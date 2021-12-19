def ger(x, y):
    if 0 < x < y < 101:
        while x != y:
            yield x + 1
            x += 1
    else:
        print("False, only numbers 1-100")


a = ger(int(input("enter from num \n")), int(input("enter untill num \n")))
print(next(a), end=" ")


