`timescale 1ns / 1ps
// Calculations are performed using fixed-point representation,
// with 2 integer bits and WIDTH-2 fractional bits,
// formatted as xx.xxxxxx
module psi #(
    parameter WIDTH = 6  // Bit Width should be between 5 and 8
) (
    input  wire [WIDTH-1:0] psi_in,
    output reg  [WIDTH-1:0] psi_out
);

  always @(psi_in) begin
    case (WIDTH)
      5: begin
        // case(psi_in) for 5 bits width
      end
      6: begin
        case (psi_in)
          6'b000000: psi_out <= 6'b111111;
          6'b000001: psi_out <= 6'b110111;
          6'b000010: psi_out <= 6'b101100;
          6'b000011: psi_out <= 6'b100110;
          6'b000100: psi_out <= 6'b100001;
          6'b000101: psi_out <= 6'b011110;
          6'b000110: psi_out <= 6'b011011;
          6'b000111: psi_out <= 6'b011001;
          6'b001000: psi_out <= 6'b010111;
          6'b001001: psi_out <= 6'b010101;
          6'b001010: psi_out <= 6'b010011;
          6'b001011: psi_out <= 6'b010010;
          6'b001100: psi_out <= 6'b010000;
          6'b001101: psi_out <= 6'b001111;
          6'b001110: psi_out <= 6'b001110;
          6'b001111: psi_out <= 6'b001101;
          6'b010000: psi_out <= 6'b001100;
          6'b010001: psi_out <= 6'b001100;
          6'b010010: psi_out <= 6'b001011;
          6'b010011: psi_out <= 6'b001010;
          6'b010100: psi_out <= 6'b001001;
          6'b010101: psi_out <= 6'b001001;
          6'b010110: psi_out <= 6'b001000;
          6'b010111: psi_out <= 6'b001000;
          6'b011000: psi_out <= 6'b000111;
          6'b011001: psi_out <= 6'b000111;
          6'b011010: psi_out <= 6'b000110;
          6'b011011: psi_out <= 6'b000110;
          6'b011100: psi_out <= 6'b000110;
          6'b011101: psi_out <= 6'b000101;
          6'b011110: psi_out <= 6'b000101;
          6'b011111: psi_out <= 6'b000101;
          6'b100000: psi_out <= 6'b000100;
          6'b100001: psi_out <= 6'b000100;
          6'b100010: psi_out <= 6'b000100;
          6'b100011: psi_out <= 6'b000100;
          6'b100100: psi_out <= 6'b000011;
          6'b100101: psi_out <= 6'b000011;
          6'b100110: psi_out <= 6'b000011;
          6'b100111: psi_out <= 6'b000011;
          6'b101000: psi_out <= 6'b000011;
          6'b101001: psi_out <= 6'b000010;
          6'b101010: psi_out <= 6'b000010;
          6'b101011: psi_out <= 6'b000010;
          6'b101100: psi_out <= 6'b000010;
          6'b101101: psi_out <= 6'b000010;
          6'b101110: psi_out <= 6'b000010;
          6'b101111: psi_out <= 6'b000010;
          6'b110000: psi_out <= 6'b000010;
          6'b110001: psi_out <= 6'b000001;
          6'b110010: psi_out <= 6'b000001;
          6'b110011: psi_out <= 6'b000001;
          6'b110100: psi_out <= 6'b000001;
          6'b110101: psi_out <= 6'b000001;
          6'b110110: psi_out <= 6'b000001;
          6'b110111: psi_out <= 6'b000001;
          6'b111000: psi_out <= 6'b000001;
          6'b111001: psi_out <= 6'b000001;
          6'b111010: psi_out <= 6'b000001;
          6'b111011: psi_out <= 6'b000001;
          6'b111100: psi_out <= 6'b000001;
          6'b111101: psi_out <= 6'b000001;
          6'b111110: psi_out <= 6'b000001;
          6'b111111: psi_out <= 6'b000000;
        endcase
      end
      7: begin
        // case(psi_in) for 7 bits width
      end
      8: begin
        // case(psi_in) for 8 bits width
      end
    endcase
  end
endmodule
