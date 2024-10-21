import numpy as np
from validator import *
import psi_LUT
from BitUpdateBlock import BitUpdateBlock


def psi(x):
    """
    Calculate PSI value
    """
    x_temp = np.abs(x)
    # Treat vector and single number
    if isinstance(x_temp, np.ndarray):
        for i in range(x_temp.shape[0]):
            x_temp[i] = psi_LUT.round_to_closest(x_temp[i],
                                psi_LUT.decimal_numbers)
        y = [psi_LUT.lut[key] for key in x_temp]
        return np.array(y)*(-1)
    else:
        return psi_LUT.lut[psi_LUT.round_to_closest(np.abs(x),
                                psi_LUT.decimal_numbers)]*(-1)


def pcub(input_word):
    """
    Simulate: Parity Check Update Block
    """
    psi_input = psi(input_word)
    a = np.sum(psi_input)
    decrease_self = a - psi(input_word)
    psi_decrease = psi(decrease_self)
    s = np.prod(np.sign(input_word))
    output_word = (
        np.array(-1 * s * psi_decrease * np.sign(input_word)))
    return output_word


def parallel_adder(l_qj, r_mj):
    """
    Simulate: Parallel Adder Block
    """
    lq_mj = l_qj - r_mj
    return lq_mj


def decoder(codeword, block_size, p_matrix, max_iter=8, initial_llr=2.75):
    # initialize H matrix
    h_matrix = initialize_h_matrix(p_matrix, block_size)
    # Initialize Bit Update Blocks
    bit_update_blocks = \
        [BitUpdateBlock(bits, id, initial_llr) for id, bits in
         enumerate(codeword.reshape(p_matrix.shape[1], block_size))]

    # Initialize R-memory
    r_memories = np.zeros((p_matrix.shape[0], p_matrix.shape[1], block_size))
    estimate = np.copy(codeword).reshape(-1)
    for iteration in range(max_iter):
        # Check if the received codeword is valid
        if check_codeword(h_matrix, estimate):
            break
        # Process row by row
        for m in range(p_matrix.shape[0] - 1, -1, -1):
            inds = np.copy(p_matrix[m])
            # -1 means block of zeros
            mask = inds != -1

            for j in range(block_size):
                # take only relevant values from R memory
                r_mem = r_memories[m, np.arange(p_matrix.shape[1]), inds]
                # take only relevant values from column sum memory
                col_sum = np.array([bub.to_router(ind) for ind, bub in
                                    zip(inds, bit_update_blocks)])
                # Pass to Parallel Adder Block
                to_pcub = parallel_adder(col_sum, r_mem)

                r_mem = pcub(to_pcub)[0:p_matrix.shape[1]]
                # Save received data
                r_memories[m, mask, inds[mask]] = r_mem[mask]
                for i, ind in enumerate(inds):
                    bit_update_blocks[i].from_router(ind, r_mem[i])
                # Calculate next indexes
                inds[mask] = (inds[mask] + 1) % block_size

        estimate = np.array([bub.hard_decision() for bub in bit_update_blocks])

        for block in bit_update_blocks:
            block.change_memory()

        estimate = estimate.reshape(-1)

    return estimate
