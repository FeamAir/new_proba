class Counter:
    """Класс Counter - счетчик, принимает на вход зачения
    "start" и "end", при каждом выводе происходит
     инкрементация +1, а так же обнуления счетчика"""

    def __init__(self, start, end):
        self.start = start
        self.end = end
        self.current = self.start

    def status_count(self):
        return self.current

    def increment_count(self):  # метод не изминял
        """Фукция инкрементирует значение счетчика,
            а так же следит за границами выполнения"""
        if self.current < self.end:  # добавил "="
            self.current += 1
            return self.current
        if self.current == self.end:
            return self.end

    def refresh_count(self):  # изменил на первоначальный отсчет
        """Обнуления счетчика"""
        self.current = self.start  # изменил на первоначальный отсчет
        print("Cчетчик сброшен на начальное значение {}".format(self.current))
        return self.current


if __name__ == "__main__":
    my_count = Counter(10, 15)
    print(my_count.status_count())
    print(my_count.status_count())
    print(my_count.refresh_count())
    print(my_count.status_count())
    print(my_count.increment_count())
    print(my_count.increment_count())
    print(my_count.status_count())
    print(my_count.increment_count())
    print(my_count.increment_count())
    print(my_count.increment_count())
    print(my_count.status_count())
    print(my_count.increment_count())
    print(my_count.refresh_count())
    print(my_count.increment_count())
