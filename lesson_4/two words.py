say = input("Enter two words \n")
a = say.split(' ')
c = 2
while c == len(a):
    spaceindex = say.find(' ')
    w1 = say[:int(spaceindex) + 1][::-1]
    w2 = say[int(spaceindex):][::-1]
    print(w1.title(), w2.title())
    break
else:
    print("try again")