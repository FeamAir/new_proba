def my_exceptions():
    my_str = ""
    for i in range(2):
        a = input("Enter numbers \n")
        try:
            my_str = int(my_str) + int(a)
        except:
            my_str += a

    return my_str


print("your result =", my_exceptions())
