x = 1900
y = 1000000
year = int(input("enter year \n"))
if (year < x) or (year > y):
    print(year, "the entered year does not meet the conditions")
elif (year % 4 == 0) and (year % 100 != 0) or (year % 400 == 0):
    print(year, 'this is leap year')
else:
    print(year, 'this is not leap year')
