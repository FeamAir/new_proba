class NegativeAge(Exception):
    def __init__(self, value):
        self.msg = value


age = input("Сколько вам лет ?? \n")
if age.isdigit() > 0:
    print("Вам", age, "лет")
else:
    raise NegativeAge("Неверно введено значение")
