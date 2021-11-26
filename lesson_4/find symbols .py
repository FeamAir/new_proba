say = input("enter words \n")
start = -1
cnt = 0

while True:
    start = say.find("char", start + 1)
    if start == -1:
        break
    cnt += 1
print("Количество символов: ", cnt)
