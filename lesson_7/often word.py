dict = {}
txt = """
Стоишь на берегу и чувствуешь соленый запах ветра, что веет с моря, и веришь,
что свободен ты и жизнь лишь началась, и губы жжет подруги поцелуй, пропитанный слезой!
"""
print(txt)
for words in txt.split():
    dict[words] = dict.get(words, 0) + 1
#        or с учетом запятых
# for words in txt.replace(',', ' ,').split():
#     dict[words] = dict.get(words, 0) + 1
print(dict)
max_count = max(dict.values())
most_frequent = [k for k, v in dict.items() if v == max_count]

