""" Module matrix.

    This module create list and create matrix

"""
from random import randint


def create_matrix_MxN(x, y):
    """Create list MxN
    m = total of lists (lines)
    n = total of items in the list (columns)
    """
    m_num = [[randint(1, 50) for i in range(y)] for i in range(x)]
    a = '\n'.join(str(item) for item in m_num)
    print("My matrix = \n", a)
    return m_num


def create_matrix_MxM(x):
    """Create list MxM
    m = total of lists (lines) and total of items in the list (columns)
    """
    m_num = [[randint(1, 50) for i in range(x)] for i in range(x)]
    a = '\n'.join(str(item) for item in m_num)
    print("My matrix = \n", a)
    return m_num


def my_sum_matrix(s_num):
    """Total column
    Total of each column
    """
    sum_col = [0] * len(s_num[0])
    for row in s_num:
        for i, item in enumerate(row):
            sum_col[i] += item
    s_num.append(sum_col)

    return sum_col


def look_matrix(my_matrix):
    """Matrix visualization
    Display of the matrix on the screen
    """
    b = ("\n".join(
        ["\t".join([str(cell) for cell in row]) for row in my_matrix])
        )
    return b


__all__ = ["create_matrix_MxN", "create_matrix_MxM",
           "my_sum_matrix", "look_matrix"
           ]

if __name__ == "__main__":
    say = create_matrix_MxM(int(input("enter sum matrix MxM \n")))
    print(say)

