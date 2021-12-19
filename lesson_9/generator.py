def ger(x, y):
    if 0 < x < y < 101:
        for num in range(x, y):
            if num > 1:
                for i in range(2, num):
                    if (num % i) == 0:
                        break
                else:
                    yield num
    else:
        print("False, only numbers 1-100")


a = ger(int(input("enter from num \n")), int(input("enter untill num \n")))
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")
print(next(a), end=" ")


# a = int(input('enter the lower no.'))
# b = int(input('enter the higher no.'))
# print("Prime numbers between", a, "and", b, "are:")
# for num in range(a, b):
#     if num > 1:
#         for i in range(2, num):
#             if (num % i) == 0:
#                 break
#         else:
#             print(num)
