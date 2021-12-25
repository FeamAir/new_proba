from random import randint


def create_my_matrix(x, y):
    m_num = [[randint(1, 50) for i in range(y)] for i in range(x)]
    print("Начальный список = \n", '\n'.join(str(item) for item in m_num))
    for row in my_sum_matrix(m_num):
        a = ("{:<4}" * len(row)).format(*row)
        print(a)


def my_sum_matrix(s_num):
    sum_col = [0] * len(s_num[0])
    for row in s_num:
        for i, item in enumerate(row):
            sum_col[i] += item
    s_num.append(sum_col)
    sum_row = [0] * len(s_num)
    for i, row in enumerate(s_num):
        for item in row:
            sum_row[i] += item
    sum_row.pop()
    for a1, a in enumerate(sum_row):
        s_num[a1].append(a)

    return s_num


if __name__ == "__main__":
    say = int(input("enter sum matrix(m) \n"))
    say1 = int(input("enter sum matrix(n) \n"))
    my_mat = create_my_matrix(say, say1)