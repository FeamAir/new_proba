def longest_word():
    with open("article.txt", "r", encoding="utf-8") as infile:
        words = infile.read().split()
        max_len = len(max(words, key=len))
        d = []
        for word in words:
            if len(word) == max_len:
                d.append(word)
        return d


print(f"Самые длинное слово :{longest_word()}")
