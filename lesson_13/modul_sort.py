""" Module sort.

    This module has two sorting options.
    1) bubble_sort
    2)quick_sort

"""
from random import randint


def bubble_sort(x):
    """Bubble_sort.
        This function creates an MxM matrix and sorts it using the bubble method.
        You set a number equal to your matrix.
        Bubble_sort = O(n^2)

    """
    m_num = [[randint(1, 50) for i in range(x)] for i in range(x)]
    list_sum = [sum([m_num[index_col][i] for index_col in range(x)])
                for i in range(x)
                ]
    print("Начальный список = \n", '\n'.join(str(item) for item in m_num))
    print(list_sum, sep='\n')
    while True:
        for i in range(x - 1):
            for j in range(x - 2, i - 1, -1):
                if list_sum[j] > list_sum[j + 1]:
                    list_sum[j], list_sum[j + 1] = list_sum[j + 1], list_sum[j]
                    for line in range(x):
                        m_num[line][j], m_num[line][j + 1] = \
                            m_num[line][j + 1], m_num[line][j]
            for coll in range(x):
                if list_sum[coll] % 2 == 0:
                    for a in range(x - 1):
                        if m_num[a][coll] > m_num[a + 1][coll]:
                            m_num[a][coll], m_num[a + 1][coll] = \
                                m_num[a + 1][coll], m_num[a][coll]
                else:
                    for a in range(x - 1):
                        if m_num[a][coll] < m_num[a + 1][coll]:
                            m_num[a][coll], m_num[a + 1][coll] = \
                                m_num[a + 1][coll], m_num[a][coll]
        m_num.append(list_sum)
        break
    return sort_list_b(m_num)


def sort_list_b(b_num):
    a = ("\n".join(["\t".join([str(cell) for cell in row]) for row in b_num]))
    # print("Финальный список = \n", a)
    return a


def partition(nums, low, high):
    lst = nums[(low + high) // 2]
    i = low - 1
    j = high + 1
    while True:
        i += 1
        while nums[i] < lst:
            i += 1
        j -= 1
        while nums[j] > lst:
            j -= 1
        if i >= j:
            return j

        nums[i], nums[j] = nums[j], nums[i]


def quick_sort(nums):
    """Quick_sort.
        This function allows you to sort the list using the method quick_sort.
        Bubble_sort = O(n log (n))
    """
    def q_sort(items, low, high):
        if low < high:
            lst_index = partition(items, low, high)
            q_sort(items, low, lst_index)
            q_sort(items, lst_index + 1, high)

    q_sort(nums, 0, len(nums) - 1)


__all__ = ["quick_sort", "bubble_sort"]

if __name__ == "__main__":
    say = [randint(0, 30) for i in range(10)]
    # print(say)
    # quick_sort(say)
    # print(say)
    # # say = bubble_sort(int(input("enter sum matrix \n")))

