import ldpc_encode as encode
import ldpc_decode as decode
from print_matrix import *
import numpy as np
import P_MATRICES

matrix = P_MATRICES.P6
block_size = 62

n = block_size * len(matrix[0])  # length of coded word
m = block_size * (len(matrix[0]) - len(matrix))  # length of info bits
num_errors = 20
num_codewords = 10
max_iterations = 50

# Convert the lists to a NumPy matrix structure
p_matrix = np.array(matrix).reshape(len(matrix),
                                    len(matrix[0]))
p_matrix[p_matrix != -1] = (p_matrix[p_matrix != -1]
                            % block_size)

for iteration in range(num_codewords):
    # Generate random message and encode it
    message = np.random.randint(2, size=(1, m))
    codeword = encode.encode(p_matrix, block_size, message)
    codeword_original = np.copy(codeword.reshape(-1))

    # Add errors
    for i in range(num_errors):
        index = np.random.randint(0, codeword.shape[1])
        codeword[0][index] = (
            np.mod(codeword[0][index] + 1, 2))

    # Belief propagation decode
    estimate = decode.decoder(codeword.reshape(-1),
                                block_size, p_matrix,
                                max_iter=max_iterations,
                                initial_llr=2.75)

    if not np.array_equal(codeword_original, estimate):
        print(f'\t$display("{iteration + 1}:'
              f' Expected Fail");')
    else:
        print(f'\t$display("{iteration + 1}:'
              f' Expected Success");')

    # Print for verilog
    print_testbench(codeword, codeword_original, n)

# Print matrix for verilog testbench
write_matrix_to_file(matrix, block_size, "matrix.txt")
