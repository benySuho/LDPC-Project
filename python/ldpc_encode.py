import numpy as np


def shift_vector_by_k(vector, k):
    if k == -1:
        return np.zeros(vector.shape[0], dtype=int)
    if k == 0:
        return vector
    return np.roll(vector, -k, axis=0)


def encode(p_matrix, block_size, message):
    m, n = p_matrix.shape
    message = np.array(message.reshape(-1))
    codeword = np.append(message, np.zeros(m * block_size, dtype=int))

    #  Double diagonal encoding
    temp = np.zeros(block_size, dtype=int)
    for i in range(m):  # rows
        for j in range(n - m):  # columns
            message_part = message[j * block_size:(j + 1) * block_size]
            shift = p_matrix[i][j]
            shifted = shift_vector_by_k(message_part, shift)
            temp = np.mod(temp + shifted, 2)

    codeword[(n - m) * block_size:(n - m + 1) * block_size] = shift_vector_by_k(temp, block_size)

    for i in range(m - 1):
        temp = np.zeros(block_size, dtype=int)
        for j in range(n - m + i + 1):
            code_part = codeword[j * block_size:(j + 1) * block_size]
            shift = p_matrix[i][j]
            temp = np.mod(temp + shift_vector_by_k(code_part, shift), 2)
        codeword[(n - m + i+1) * block_size:(n - m + i + 2) * block_size] = temp

    return codeword.reshape(1, -1)
