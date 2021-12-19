def b_num(x, y):
    for a in x:
        for b in x:
            if a + b == y:
                return a, b


say = b_num(list(map(int, input("enter numbers \n"))), int(input(" total number \n")))
print(bool(say))