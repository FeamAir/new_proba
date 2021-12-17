def ger(x, y):
    for i in range(x, y + 1):
        if 0 < x < y < 101:
            print(i, end=" ")
        else:
            print("False, only numbers 1-100")
            return i


a = ger(int(input("enter from num \n")), int(input("enter untill num \n")))
