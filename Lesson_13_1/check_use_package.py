from my_lib_modules.create_matrix import *
from my_lib_modules.sort_my_module import bubble_sort_matrix as b_sort

#   Данная функция создаёт матрицу МхМ, использует метод пузырька
#   Далее сумирует столбцы и выводим матрицу


def start_matrix(matrix):
    lst = create_matrix_MxM(matrix)
    b_sort(lst)
    return lst


say = start_matrix(int(input("enter sum matrix MxM \n")))
my_sum_matrix(say)
print(say)
print("Финальная матрица = \n \n", look_matrix(say), "\n")

