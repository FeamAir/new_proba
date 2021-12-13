str = {}
for words in input("Enter your sentence ").split():
    str[words] = str.get(words, 0) + 1
print(str)