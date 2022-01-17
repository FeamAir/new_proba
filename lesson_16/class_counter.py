class Counter:
    """Класс Counter - счетчик, принимает на вход зачения
    "start" и "end", при каждом выводе происходит
     инкрементация +1, а так же обнуления счетчика"""
    def __init__(self, start, end):
        self.start = start
        self.end = end
        self.current = self.start

    def increment_count(self):
        """Фукция инкрементирует значение счетчика,
            а так же следит за границами выполнения"""
        if self.current < self.end:
            self.current += 1
            return self.current
        else:
            return "Превышено значение счетчика"

    def refresh_count(self):
        """Обнуления счетчика"""
        self.current = self.start + 1
        return self.current

my_count=Counter(10, 15)

print(my_count.increment_count())
print(my_count.increment_count())
print(my_count.increment_count())
print(my_count.increment_count())
print(my_count.refresh_count())
print(my_count.increment_count())
print(my_count.increment_count())