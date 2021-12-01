while True:
    say = input("Enter two words \n")
    a = say.count(" ")
    if a == 1:
        words = say.find(' ')
        w1 = say[:int(words) + 1][::-1]
        w2 = say[int(words):][::-1]
        print(w1.title(), w2.title())
        break
    else:
        print("Try again")
