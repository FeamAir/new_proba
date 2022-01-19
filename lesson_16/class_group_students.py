class Group:
    journal = []

    def __init__(self, group_name):
        self.group_name = group_name
        self.journal = []


    def add_student(self, students_parameters: list):
        new_student = Student(*students_parameters)
        self.journal.append(new_student)

    def print_journal(self):
        print([str(student) for student in self.journal])

class Student:
    def __init__(self, name, age, grades):
        self.name = name
        self.age = age
        self.grades = grades

    def __str__(self):
        return "Имя:{} , Возраст:{} ".format(self.name, self.age)

    def one_student(self):
        print('Имя: {}. Возраст: {}. Оценка: {}'.format(self.name, self.age,
                                                        self.grades))


one_std = Student("Вася", 18, 4)
one_std.one_student()


group_A = Group("A2022")
b = group_A.add_student(["Юрий",18, 5])
b = group_A.add_student(["Светлана",16, 5])
b = group_A.add_student(["Дмитрий",18, 3])
b = group_A.add_student(["Александр",21, 4])
b = group_A.add_student(["Юлия",19, 5])
group_A.print_journal()

