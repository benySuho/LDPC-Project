import numpy as np


def shift_base_matrix_by_k(block_size, k):
    if k == -1:
        return np.zeros((block_size, block_size))
    return np.roll(np.eye(block_size), -k, axis=0)


def initialize_h_matrix(p_matrix, block_size):
    if not isinstance(p_matrix, np.ndarray):
        p_matrix = np.array(p_matrix).reshape(len(p_matrix), len(p_matrix[0]))
    p_matrix[p_matrix != -1] = p_matrix[p_matrix != -1] % block_size
    h_matrix = None
    for m in range(p_matrix.shape[0]):
        row = None
        for n in range(p_matrix.shape[1]):
            shifted_block = shift_base_matrix_by_k(block_size, p_matrix[m, n])
            if row is None:
                row = shifted_block
            else:
                row = np.concatenate((row, shifted_block), axis=1)
        if h_matrix is None:
            h_matrix = row
        else:
            h_matrix = np.concatenate((h_matrix, row), axis=0)
    return np.trunc(h_matrix).astype(int)


def check_codeword(h_matrix, codeword):
    codeword = codeword.reshape(-1)
    for m in range(h_matrix.shape[0]):
        if np.matmul(h_matrix[m, :], codeword) % 2 == 1:
            return False
    return True
