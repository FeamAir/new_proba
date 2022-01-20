class Group:
    """Класс Group сохраняет список студентов """
    journal = []

    def __init__(self, group_name):
        self.group_name = group_name
        self.journal = []

    def add_student(self, students_parameters: list):
        new_student = Student(*students_parameters)
        self.journal.append(new_student)

    def print_journal(self):
        [print(student) for student in self.journal]


class Student:
    """Класс Student Принимает параметры студента"""

    def __init__(self, name, age, grades):
        self.name = name
        self.age = age
        self.grades = grades

    def __str__(self):
        return "Имя:{} , Возраст:{} ".format(self.name, self.age)

    def one_student(self):
        print('Имя: {}. Возраст: {}. Оценка: {}'.format(self.name, self.age,
                                                        self.grades))


if __name__ == "__main__":
    one_std = Student("Вася", 18, 4)
    one_std.one_student()

group_A = Group("A2022")
a = group_A.add_student(["Юрий", 18, 5])
b = group_A.add_student(["Светлана", 16, 5])
c = group_A.add_student(["Светлана", 16, 5])
group_A.print_journal()
