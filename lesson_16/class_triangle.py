class TriangleChecker:
    """Class TriangleChecker(треугольник). Позволяющий создать треуголник из
    заданных параметров. Имеет метод is_triangle """
    def __init__(self, sides):
        self.sides = sides

    def is_triangle(self):
        """ Метод is_triangle передаем список состоящий из трех цифр,
        при занесение в метод строки, отрицательные числа а так же если
        введете числа не соответствуещим правилам создания треугольника вам
        выдаст соответствующте сообщение вашей ошибки"""
        if all(isinstance(side, int) for side in self.sides):
            # перебираем список с помощью isinstance что бы все значения
            # принадлежали целочисленным
            if all(side > 0 for side in self.sides):
                sorted_sides = sorted(self.sides)
                # перебираем и сортируем список
                if sorted_sides[0] + sorted_sides[1] > sorted_sides[2]:
                    # правило треуголника a + b > c
                    return "Ура, можно построить треугольник!"
                return "Жаль, но из этого треугольник не сделать"
            return "С отрицательными числами ничего не выйдет!"
        return "Нужно вводить только цeлoчиcлeнные числа!"

if __name__ == "__main__":
    triangle1 = TriangleChecker([3, 6, 8])
    print(triangle1.is_triangle())