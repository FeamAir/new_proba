def b_num(x, y):
    for a in x:
        for b in x:
            if a + b == y:
                return True
        else:
            return False


say = b_num(list(map(int, input("enter numbers \n"))), int(input(" total number \n")))
print(say)