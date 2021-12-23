import random


def bubble_sort(x):
    m_num = [[random.randint(1, 50) for i in range(x)] for i in range(x)]
    list_sum = [sum([m_num[index_col][i] for index_col in range(x)])
                for i in range(x)
                ]
    print("Начальный список = \n", '\n'.join(str(item) for item in m_num))
    print(list_sum, sep='\n')
    while True:
        for i in range(x - 1):
            for j in range(x - 2, i - 1, -1):
                if list_sum[j] > list_sum[j + 1]:
                    list_sum[j], list_sum[j + 1] = list_sum[j + 1], list_sum[j]
                    for line in range(x):
                        m_num[line][j], m_num[line][j + 1] = \
                            m_num[line][j + 1], m_num[line][j]
            for coll in range(x):
                if list_sum[coll] % 2 == 0:
                    for a in range(x - 1):
                        if m_num[a][coll] > m_num[a + 1][coll]:
                            m_num[a][coll], m_num[a + 1][coll] = \
                                m_num[a + 1][coll], m_num[a][coll]
                else:
                    for a in range(x - 1):
                        if m_num[a][coll] < m_num[a + 1][coll]:
                            m_num[a][coll], m_num[a + 1][coll] = \
                                m_num[a + 1][coll], m_num[a][coll]
        m_num.append(list_sum)
        break
    return sort_list_b(m_num)


def sort_list_b(b_num):
    a = ("\n".join(["\t".join([str(cell) for cell in row]) for row in b_num]))
    return a


say = bubble_sort(int(input("enter sum matrix \n")))
print(say)
