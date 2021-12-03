import random

name = input("what is your name? \n").title()
number = random.randint(1, 100)
cnt = 0
print(f"Good {name},I create for you a number from 1 to 100, good luck!!!")
while True:
    say = input(f" {name} enter your number \n")
    cnt += 1
    text = "your number {luck} is bigger".format(luck=say)
    text1 = "your number {luck} is less".format(luck=say)
    if say.isdigit():
        say1 = int(say)
        print("")
        if say1 > number:  # если число введенное пользоваелем больше рендомного
            print(text)
        if say1 < number:  # если число введенное пользоваелем меньше рендомного
            print(text1)
        if say1 == number:  # если число введенное пользоваелем совпала с рендомным числом
            break
    else:
        print("incorrect symbol, try again")
if say1 == number:
    print(f"{name}, you win. Number of attempts = {cnt}")
