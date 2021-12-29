""" Module sort.

    This module has three sorting options.
    1)  bubble_sort
    2)  quick_sort
    3)  bubble_sort_matrix

"""

from random import randint


def bubble_sort(lst):
    """Bubble_sort.
    Sorts it using the bubble method.
    Bubble_sort = O(n^2)
    """
    length = len(lst)
    while True:
        for i in range(length - 1):
            for j in range(length - 2, i - 1, -1):
                if lst[j] > lst[j + 1]:
                    lst[j], lst[j + 1] = lst[j + 1], lst[j]
        return lst


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


def bubble_sort_matrix(lst):
    """bubble_sort_matrix.
    Sorts it using the bubble method for matrix.
    Bubble_sort = O(n^2)
    """
    length = len(lst)
    while True:
        for i in range(length):
            for a in range(length-1):
                for j in range(length - 2, a-1, -1):
                    if lst[i][j] > lst[i][j + 1]:
                        lst[i][j], lst[i][j + 1] = lst[i][j + 1], lst[i][j]
        return lst


__all__ = ["quick_sort", "bubble_sort", "bubble_sort_matrix"]

if __name__ == "__main__":
    say = [randint(0, 10) for i in range(10)]
    print("Начальный список = \n", say)
    quick_sort(say)
    print("Финальный список = \n", say)


