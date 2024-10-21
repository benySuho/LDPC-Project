import numpy as np

hex_to_bin_dict = {'0': ['0', '0', '0', '0'], '1': ['0', '0', '0', '1'], '2': ['0', '0', '1', '0'],
                   '3': ['0', '0', '1', '1'], '4': ['0', '1', '0', '0'], '5': ['0', '1', '0', '1'],
                   '6': ['0', '1', '1', '0'], '7': ['0', '1', '1', '1'], '8': ['1', '0', '0', '0'],
                   '9': ['1', '0', '0', '1'], 'A': ['1', '0', '1', '0'], 'B': ['1', '0', '1', '1'],
                   'C': ['1', '1', '0', '0'], 'D': ['1', '1', '0', '1'], 'E': ['1', '1', '1', '0'],
                   'F': ['1', '1', '1', '1']}


def get_random_string(length):
    digits = np.random.randint(0, 16, length)
    return ''.join([hex(digit)[2:] for digit in digits])


def print_matrix_for_verilog(matrix, b_size):
    matrix = np.array(matrix)
    print(matrix.shape[0])
    print(matrix.shape[1])
    print(b_size)
    for row in matrix[::-1]:
        for col in row[::-1]:
            print(col)


def write_matrix_to_file(matrix, b_size, filename):
    matrix = np.array(matrix)

    with open(filename, 'w') as file:
        file.write(f"{matrix.shape[0]}\n")  # Write number of rows
        file.write(f"{matrix.shape[1]}\n")  # Write number of columns
        file.write(f"{b_size}\n")  # Write block size

        for row in matrix[::-1]:
            for col in row[::-1]:
                file.write(f"{col}\n")  # Write each element to the file


def print_bin_message_in_dec(bin_message, b_size):
    for i in range(int(len(bin_message) / b_size) - 1, -1, -1):
        print(int(bin_message[i * b_size:(i + 1) * b_size], 2))


def print_testbench(codeword, codeword_original, n):
    print("\t// input codeword")
    print(f"\toriginal = {n}'b", *(f"\b{bin(int(cell))[2]}" for cell in codeword_original), f"\b;")
    print(f"\tcodeword_in = {n}'b", *(f"\b{bin(int(cell))[2]}" for cell in codeword[0]), f"\b;")
    print("")
    print("\t// Process decode")
    print("\tsend_codeword(codeword_in);")
    print("\twait (done);")
    print("\treceive_codeword();")
    print("\tprint_result();")
    print("")
