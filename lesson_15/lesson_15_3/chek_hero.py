def update_hero(**data):
    """Функция считывает информацию с фаила, преобразует в словарь,
        меняет значение словаря и записывает обратно в фаил"""
    d = {}  # создаём словарь
    with open("hero.ini", "r") as inp:  # открываем фаил для чтения
        for i in inp.readlines():  # считываем все строки
            key, val = i.strip().split('=')  # создаём ключ и значение
            d[key] = val  # добавляем в пустой словарь
        for key, val in data.items():  # перебираем входные значения функции
            d[key] = val  # заданые ключи, меняем их значение
    with open('hero.ini', 'w') as inp:  # открываем фаил на запись
        for key, val in d.items():  # разбираем словарь
            inp.write('{}={}\n'.format(key, val))  # записываем все в фаил


update_hero(hero="Halk", power=450, Y=2.3)
