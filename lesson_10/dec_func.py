def benchmark(func):
    import time

    def wrapper(*args):
        start_time = time.perf_counter()
        res = func(*args)
        total = time.perf_counter() - start_time
        print("- Время Выполнения: {} секунд.".format(total))
        return res
    return wrapper


@benchmark
def my_liner(sequence, look_for):
    i = 0
    lenght = len(sequence)
    while i < lenght and look_for != sequence[i]:
        i += 1
    return i if i < lenght else None


@benchmark
def my_liner2(sequence, look_for):
    i = 0
    sequence.append(look_for)
    lenght = len(sequence)-1
    while look_for != sequence[i]:
        i += 1
    return i if i < lenght else None


def my_func():
    lst = my_liner([2, 3, 4, 5, 67, 9, 0, 12], 12)
    lst1 = my_liner2([2, 3, 4, 5, 67, 9, 0, 12], 12)
    return lst, lst1


print(my_func())
