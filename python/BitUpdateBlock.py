import numpy as np


class BitUpdateBlock:
    def __init__(self, received_data, ser=0, in_llr=2.75):
        self.in_llr = in_llr
        self.received_data_memory = np.power(-1, received_data) * self.in_llr
        self.ser = ser
        self.column_sum_memory = (
            np.array([self.received_data_memory, self.received_data_memory]))
        self.choose_memory = 0

    def from_router(self, j, rmj):
        """
        Simulate: Update column sum memory
        with received data and routing message.
        """
        if j != -1:
            self.column_sum_memory[self.choose_memory, j] = (
                np.clip(self.column_sum_memory[self.choose_memory, j] + rmj,
                        -7.875, 7.875))

    def to_router(self, j):
        """
        Simulate: return value in column sum memory
        """
        if j == -1:
            return 7.875
        else:
            return self.column_sum_memory[1 - self.choose_memory, j]

    def hard_decision(self):
        """
        Simulate: Return estimated block
        """
        estimate = (
            np.array(np.sign(self.column_sum_memory[1 - self.choose_memory]) < 0))
        return estimate.astype(np.int8)

    def change_memory(self):
        """
        Simulate: Change the memory to the other one.
        """
        self.choose_memory = 1 - self.choose_memory
        self.column_sum_memory[self.choose_memory, :] = (
            self.received_data_memory)
