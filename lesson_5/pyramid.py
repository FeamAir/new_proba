b = 2
c = 10
while True:
    say = int(input("enter number from 3 to 9 \n"))
    if b < say < c:  # проверяем правильность выполнения условия
        for i in range(1, say + 2):  # перебераем от одного к задоному числу в два шага
            for a in range(1, i - 1):  # перебирае от одного c  минус один шагом
                print(a, end="")
            for a in range(i - 1, 0, -1):  # перебирает числа в обратном порядке
                print(a, end="")
            print()
        break
    else:
        print("try again")
