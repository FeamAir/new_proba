dict = {}
txt = """
Стоишь на берегу и чувствуешь соленый запах запах запах запах запах ветра, что веет с моря, и веришь,
что свободен ты и жизнь лишь началась, и губы жжет жжет жжет жжет жжет подруги поцелуй, пропитанный слезой!
"""
print(txt)
d = " "
for words in txt.replace(',', ' ,').split():
    dict[words] = dict.get(words, 0) + 1
print(dict)
max_cnt = max(dict.values())
often = [k for k, v in dict.items() if v == max_cnt ]
print("You have = ", often)
while len(often) > 1:
    d = input("what words?? \n")
    if d not in dict:
        print("not found")
        continue
    print("total value", d, "=", dict[d])
    break

