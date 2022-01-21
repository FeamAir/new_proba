class Buffer:
    """class Buffer.
            накапливает в себе элементы последовательности
            и выводить сумму пятерок последовательных элементов по мере
            их накопления.
    """

    def __init__(self):
        self.arr = []

    def add(self, *a):
        """Добавляет значения в список и выводит первые просумированные
         5 заданных значений
        """
        self.arr.extend(a)
        while len(self.arr) >= 5:
            print(sum(self.arr[:5]))
            del self.arr[0:5]

    def get_current_part(self):
        """Выводит оставшиеся в списке не просумированные значения """
        print(self.arr)
        return self.arr


if __name__ == "__main__":
    buf = Buffer()
    buf.add(2, 4, 5)
    buf.add(2, 4, 8, 92, 4, 5)
    buf.add(7, 8, 9)
    buf.add(1)
    buf.get_current_part()
