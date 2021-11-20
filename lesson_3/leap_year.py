x = 1900
y = 10_000_00
year = int(input("enter year \n"))
if x < year < y:
    if (year % 4 == 0) and (year % 100 != 0) or (year % 400 == 0):
        print(year, 'this is leap year')
    else:
        print(year, 'this is not leap year')
else:
    print(year, "the entered year does not meet the conditions")