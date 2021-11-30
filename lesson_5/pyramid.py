b = 2
c = 10
while True:
    say = int(input("enter number from 3 to 9 \n"))
    if b < say < c: #проверяем правильность значеения
        for i in range(say, say + 10): #от ведденнго пользователем плюсуем 10 чисел
            for a in range(say, i + 1):# от ведденнго пользователем плюсуем 1
                print(a, end=' ')#заканчивается новой строкой
            print("")
        break
    else:
        print("try again")
