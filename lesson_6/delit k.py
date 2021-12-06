say = list(input("enter number \n"))
print(say)
k = int(input("delete index"))
for a in range(k, len(say) - 1):
    say[a], say[a + 1] = say[a + 1], say[a]
print(say)
say.pop()
print(say)


