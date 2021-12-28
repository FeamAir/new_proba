# from random import randint
from modul_sort import *


# print(dir())


#   Данная функция создаёт матрицу и вызывает Метод пузырька


def my_num(x):
    a = bubble_sort(x)
    return a


say = my_num(int(input("enter sum matrix \n")))
print(say)


#   Данная функция вызывает быстрый метод сортировки
#   Необходимо убрать хеш на импорте random


# def my_quick(x):
#     print("Начальный список =", x)
#     quick_sort(x)
#
#     return x
#
#
# say = my_quick([randint(0, 30) for i in range(10)])
# print("Конечный результат =", say)


