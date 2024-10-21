`timescale 1ns / 1ps

module rotate_left_vector #(
    parameter MAX_BLOCK_SIZE = 64,  // Maximum width of the input vector
    localparam WIDTH = $clog2(MAX_BLOCK_SIZE)  // Bit width of shift amount

) (
    input wire [MAX_BLOCK_SIZE-1:0] in_vector,  // Input vector to be rotated
    input wire [WIDTH-1:0] shift_amount,  // Number of bits to rotate
    input wire [WIDTH-1:0] width,  // Number of bits to consider for rotation
    output wire [MAX_BLOCK_SIZE-1:0] out_vector  // Rotated output vector
);
  // Mask used to ignore irrelevant MSB bits
  reg [MAX_BLOCK_SIZE-1:0] effective_bits;
  // Masked input vector and rotated vector
  wire [MAX_BLOCK_SIZE-1:0] only_effective_bits, rotated_bits;

  // Generate a mask based on the effective width
  always @(width) begin
    effective_bits = ~((1 << (MAX_BLOCK_SIZE - width))-1);
  end

  // Apply the mask to the input vector
  assign only_effective_bits = (in_vector & effective_bits);

  // Perform the rotation
  // If shift_amount is -1, output 0
  // Otherwise, rotate the vector left by shift_amount
  assign rotated_bits = (only_effective_bits << shift_amount) | 
                        (only_effective_bits >> (width-shift_amount));

  // Mask the rotated vector
  assign out_vector = 
    (shift_amount == ((1 << WIDTH) - 1)) ? 0 : rotated_bits & effective_bits;

endmodule
