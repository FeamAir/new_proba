stds = (
    ("Иван", 18, 7.1, "Киев"),
    ("Светлана", 20, 8.2, "Киев"),
    ("Дмитрий", 19, 5.1, "Фастов"),
    ("Николай", 18, 7.0, "Одесса"),
    ("Стас", 18, 6.7, "Киев"),
    ("Илона", 20, 9.9, "Жмерынка"),
    ("Надя", 21, 8.6, "Маякы")
)
cnt = 0
good_job = []
for i in stds:
    name, age, mark, city = i
    cnt += mark
avg_mark = cnt / len(stds)
print("Средний бал прохождения =", format(avg_mark, '.2f'))
for i in stds:
    name, age, mark, city = i
    if mark >= avg_mark:
        good_job.append(name)
print('Ученики ', ', '.join(good_job), ',', 'в этом семестре хорошо учатся!')

