""" Module sort.

    This module has three sorting options.
    1) bubble_sort
    2) quick_sort
    3) insertion_sort

"""
from random import randint


def bubble_sort(lst):
    """Bubble_sort.
        This function sorts it using the bubble method.
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


def insertion_sort(data):
    """insertion_sort.
         This function sorts it using the insertion_sort.
         insertion_sort = O(n^2)
    """
    for i in range(len(data)):
        j = i - 1
        key = data[i]
        while data[j] > key and j >= 0:
            data[j + 1] = data[j]
            j -= 1
        data[j + 1] = key
    return data


__all__ = ["quick_sort", "bubble_sort", "insertion_sort"]

if __name__ == "__main__":
    say = [randint(0, 30) for i in range(10)]
    print(say)
    insertion_sort(say)
    print(say)
    # print(say)
    # bubble_sort(say)
    # print(say)

    # print(say)
    # quick_sort(say)
    # print(say)
    # say = bubble_sort(int(input("enter sum matrix \n")))

