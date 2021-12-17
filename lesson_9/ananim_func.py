def func(x, y=2):
    lst = list(map(lambda x: x ** y, x))
    print(lst)
    return lst


say = func(list(map(int, input("enter numbers \n").split())))
