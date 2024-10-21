`timescale 1ns / 1ps

module parallel_adder #(
    parameter WIDTH_LLR = 5,  // Bit width for LLR values
    parameter MAX_COLS  = 8   // Maximum number of columns in the H matrix
) (
    input wire clk,
    input wire add,
    input wire rst_n,
    input wire [MAX_COLS*WIDTH_LLR-1:0] llr_from_memory,
    input wire [MAX_COLS*(WIDTH_LLR+1)-1:0] llr_from_pbub,
    input wire [MAX_COLS-1:0] sign_from_memory,
    input wire [MAX_COLS-1:0] sign_from_pbub,
    output wire [MAX_COLS*WIDTH_LLR-1:0] llr_out,
    output wire [MAX_COLS-1:0] sign_out,
    output reg done
);
  reg [2:0] state, next_state;  // State registers
  reg adding;  // Add operation flag

  localparam IDLE = 3'b001;
  localparam CLC = 3'b010;
  localparam RETURN = 3'b100;

  genvar i;

  generate  // Instantiate multiple adder modules
    for (i = 0; i < MAX_COLS; i = i + 1) begin
      adder #(
          .WIDTH_LLR(WIDTH_LLR)
      ) adder (
          .clk(clk),
          .add(adding),
          .llr_from_memory(llr_from_memory[(i+1)*(WIDTH_LLR)-1:i*WIDTH_LLR]),
          .llr_from_pbub(llr_from_pbub[(i+1)*(WIDTH_LLR+1)-1:i*(WIDTH_LLR+1)]),
          .sign_from_memory(sign_from_memory[i]),
          .sign_from_pbub(sign_from_pbub[i]),
          .llr_out(llr_out[(i+1)*(WIDTH_LLR)-1:i*WIDTH_LLR]),
          .sign_out(sign_out[i])
      );
    end
  endgenerate

  // Next state logic
  always @* begin
    case (state)
      IDLE: begin
        if (adding) next_state = CLC;
        else next_state = IDLE;
      end
      CLC: begin
        next_state = RETURN;
      end
      RETURN: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Add operation control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) adding <= 1'b0;
    else if (add) adding <= 1'b1;
    else adding <= 1'b0;
  end

  // Done signal assertion
  always @(posedge clk) begin
    if (state == RETURN) done <= 1;
    else done <= 0;
  end

endmodule


module adder #(
    parameter WIDTH_LLR = 5
) (
    input wire clk,
    input wire add,
    input wire [WIDTH_LLR-1:0] llr_from_memory,
    input wire [WIDTH_LLR:0] llr_from_pbub,
    input wire sign_from_memory,
    input wire sign_from_pbub,
    output reg [WIDTH_LLR-1:0] llr_out,
    output reg sign_out
);

  reg [WIDTH_LLR+1:0] temp;  // Temporary register for intermediate result

  always @(posedge clk) begin
    if (add) begin  // Perform addition when add signal is high
      if (sign_from_memory == sign_from_pbub) begin  // If signs are the same
        if ({1'b0, llr_from_memory} > llr_from_pbub) begin
          // Subtract magnitudes
          temp <= {2'b00, llr_from_memory} - {1'b0, llr_from_pbub};
          sign_out <= ~sign_from_pbub;  // Invert sign
        end else if ({1'b0, llr_from_memory} == llr_from_pbub) begin
          sign_out <= 0;  // Set sign to 0
          temp     <= 0;  // Result is 0
        end else begin
          sign_out <= sign_from_pbub;  // Keep sign
          // Subtract magnitudes
          temp <= {1'b0, llr_from_pbub} - {2'b00, llr_from_memory};
        end

      end else begin  // If signs are different
        sign_out <= sign_from_pbub;  // Keep sign
        // Add magnitudes
        temp <= {2'b00, llr_from_memory} + {1'b0, llr_from_pbub};
      end
    end else begin  // Output result when add signal is low
      if (|{temp[WIDTH_LLR+1:WIDTH_LLR]}) begin  // Check for overflow
        llr_out <= (1 << WIDTH_LLR) - 1;  // Saturate output
      end else begin
        llr_out <= temp[WIDTH_LLR-1:0];  // Assign result
      end
    end
  end
endmodule
