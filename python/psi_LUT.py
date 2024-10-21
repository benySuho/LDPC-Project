import numpy as np
import itertools

WIDTH = 6
NUMBERS = 2


def bin_to_dec(binary_number):
    """
        Convert a binary number to a decimal number.
    """
    decimal_number = 0
    for i in range(NUMBERS):
        decimal_number += (
                binary_number[i] * (2 ** (NUMBERS - i - 1)))
    for i in range(WIDTH - NUMBERS):
        decimal_number += (
                binary_number[i + NUMBERS] *
                (2 ** (- i - 1)))
    return decimal_number


def dec_to_bin(decimal_number):
    """
    Convert a decimal number to a binary number.
    """
    decimal_number = np.abs(decimal_number)
    binary_number = []
    integer_part = int(decimal_number)
    fractional_part = decimal_number - integer_part

    # Process integer part
    for i in range(NUMBERS):
        exponent = NUMBERS - i - 1
        power_of_two = 2 ** exponent
        if integer_part >= power_of_two:
            binary_number.append(1)
            integer_part -= power_of_two
        else:
            binary_number.append(0)

    # Process fractional part
    for i in range(WIDTH - NUMBERS):
        exponent = - (i + 1)
        power_of_two = 2 ** exponent
        if fractional_part >= power_of_two:
            binary_number.append(1)
            fractional_part -= power_of_two
        else:
            binary_number.append(0)

    return tuple(binary_number)


def round_to_closest(number, array):
    """
    Find the number in the array
    that is closest to the given number
    """
    closest_number = (
        min(array, key=lambda x: abs(x - number)))
    return closest_number

# Generate all combinations of 0 and 1
binary_vectors = (
    list(itertools.product([0, 1], repeat=WIDTH)))
decimal_numbers = []

for vector in binary_vectors:
    binary_number = np.array(vector).astype(np.int8)
    decimal_number = bin_to_dec(binary_number)
    decimal_numbers.append(decimal_number)

decimal_numbers = np.array(decimal_numbers)

# Create dict as lookup table
lut = {decimal_numbers[0]: decimal_numbers[-1]}

for num in decimal_numbers[1:-1]:
    psi = np.abs(np.log(np.abs(np.tanh(num / 2))))
    psi_round = round_to_closest(psi, decimal_numbers)
    lut[num] = psi_round

lut[decimal_numbers[-1]] = decimal_numbers[0]



# print(len(lut))
# print(decimal_numbers[-1])
# print("always @(psi_in) begin\n\tcase (psi_in)")
#
# for i in range(2 ** WIDTH):
#     a_bits = ''.join(str(bit) for bit in binary_vectors[i])
#     b_bits = ''.join(str(bit) for bit in dec_to_bin(lut[decimal_numbers[i]]))
#     # print(binary_vectors[i], dec_to_bin(lut[decimal_numbers[i]]))
#     print(f"\t\t{WIDTH}'b{a_bits}: psi_out <= {WIDTH}'b{b_bits};")
# print(f"\t\tdefault: psi_out <= {WIDTH}'b{''.join(str(bit) for bit in binary_vectors[0])};")
#
# print("\tendcase\nend")
