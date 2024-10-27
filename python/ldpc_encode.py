import numpy as np


def shift_vector_by_k(vector, k):
    if k == -1:
        return np.zeros(vector.shape[0], dtype=int)
    if k == 0:
        return vector
    return np.roll(vector, -k, axis=0)


def encode(p_matrix, block_size, message):
    m, n = p_matrix.shape
    message = np.array(message).reshape(-1)
    codeword = np.append(message, np.zeros(m * block_size, dtype=int))

    temp = np.zeros(block_size, dtype=int)
    for i in range(m):  # rows
        for j in range(n - m - 1, -1, -1):  # columns
            shift = p_matrix[i][j]
            code_part = codeword[j * block_size:(j + 1) * block_size]
            shifted = shift_vector_by_k(code_part, shift)
            temp = np.mod(temp + shifted, 2)
    codeword[(n - m) * block_size:(n - m + 1) * block_size] = temp

    for i in range(m - 1):
        temp = np.zeros(block_size, dtype=int)
        for j in range(n - 1, -1, -1):
            shift = p_matrix[i][j]
            code_part = codeword[j * block_size:(j + 1) * block_size]
            shifted = shift_vector_by_k(code_part, shift)
            temp = np.mod(temp + shifted, 2)
        codeword[(n - m + i + 1) * block_size:(n - m + i + 2) * block_size] = temp

    return codeword.reshape(1, -1)
