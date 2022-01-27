class Notebook:

    def __init__(self):
        self.jotter = {}
        self.cnt = 1

    def addPerson(self, val):
        """Добавляет данные человека"""
        self.jotter[str(self.cnt)] = val  # ключ является счетчиком
        self.cnt += 1
        return 'Запись внесена'

    def del_name(self, name):
        """"Удаляем запись по номеру в списке"""
        if name in self.jotter:
            del self.jotter[name]
            return f'№{name} удален'
        return 'нет такого в списке'

    def change(self, name):
        """Метод изменяет запись"""
        if name in self.jotter:
            print('Введите новые данные ')
            new_lst = [input("Имя: "),
                       input("Фамилия: "),
                       input("Дата рождения: "),
                       input("Номер телефона: "),
                       input("Адресс: ")]
            self.jotter[name] = new_lst
            data = ' '.join(self.jotter[name])
            return f'Данные исправлены = №{name} {data}'
        return 'нет такого в списке'

    def find(self, name):
        """Метод ищет по имени и номеру телефона"""
        for key, val in self.jotter.items():
            val1, val2, val3, val4, val5 = val
            if val1 == name:
                data = ' '.join(self.jotter[key])
                return f'{key} {data}'
            if val3 == name:
                data = ' '.join(self.jotter[key])
                return f'{key} {data}'
        else:
            return "Контакт не найден"

    def srt_list(self):
        """Метод сортирует по имени и по фамилии"""
        print('''Выберите что вы хотите сделать
                * 1 - Сортировать по Имени
                * 2 - Сортировать по Фаимилии''')
        print("Введите команду \n")
        command = input()
        if command == '1':
            srt = sorted(self.jotter.items(), key=lambda item: item[1])
            srt = dict(srt)
            self.jotter.clear()
            self.jotter = srt
            return f'Список обновлён'
        elif command == '2':
            srt = sorted(self.jotter.items(), key=lambda item: item[1][1])
            srt = dict(srt)
            self.jotter.clear()
            self.jotter = srt
            return f'Список обновлён'

    def exit(self):
        return exit()

    def info(self):
        return self.jotter.items()

    def my_num_list(self):
        for key, val in book.info():
            val = ' '.join(val)
            print("№", key, val)

print('Записная книга')
print('''Выберите что вы хотите сделать
* 1 - Добавить запись
* 2 - Удалить запись
* 3 - Изменить запись
* 4 - Поиск
* 5 - Сортировка
* 6 - Выход
* 7 - Количество записей  ''')

book = Notebook()

while True:
    print("Введите команду \n")
    command = input()
    if command == '1':  # Добавляем данные
        new_list = [input("Имя: "),
                    input("Фамилия: "),
                    input("Дата рождения: "),
                    input("Номер телефона: "),
                    input("Адресс: ")]
        print(book.addPerson(new_list))
    elif command == '2':  # Удаляем данные
        book.my_num_list()
        name = input("Введите номер списка который хотите удалить >:  ")
        print(book.del_name(name))
    elif command == '3':  # Изменяем данные
        book.my_num_list()
        name = input("Введите номер списка который хотите изменить >:  ")
        print(book.change(name))
    elif command == '4':  # Ищем по имени или тел.номеру
        name = input("Введите имя контакта >:  ")
        print(book.find(name))
    elif command == '5':  # Сортируем по имени или фаимилии
        print(book.srt_list())
    elif command == '6':  # Выход
        print(book.exit())
    elif command == '7':  # Позволяет просметреть всех кто в базе данных
        for key, val in book.info():
            val = ' '.join(val)
            print(val)

    else:
        print('неизвестная команда')
