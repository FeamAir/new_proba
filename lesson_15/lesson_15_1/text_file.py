with open("my_text.txt", "w", encoding="utf-8") as f:
    while True:
        s = input("enter your new text line \n")
        if s == "":
            break
        f.write(s + '\n')
