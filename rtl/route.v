`timescale 1ns / 1ps

module route #(
    parameter MAX_BLOCK_SIZE = 8,
    parameter MAX_ROWS = 8,
    parameter WIDTH_LLR = 5,
    localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE),  // Bits for block size
    localparam WIDTH_ROWS = $clog2(MAX_ROWS + 1)  // Bit width for row index
) (
    input wire clk,
    input wire rst_n,
    input wire start_row,
    input wire [WIDTH_BLOCK-1:0] block_size_in,
    input wire pcub_done,
    input wire [WIDTH_BLOCK-1:0] cell_in,
    input wire [WIDTH_ROWS-1:0] row_index_in,
    input wire [WIDTH_LLR-1:0] llr_in,
    input wire sign_in,
    input wire pbub_ready,
    output reg [WIDTH_LLR-1:0] llr_to_parallel_adder,
    output reg sign_to_parallel_adder,
    output reg [WIDTH_BLOCK-1:0] col_out,
    output reg start_parallel_adder,
    output wire add_pbub,
    output wire row_done
);
  // Create R Memory
  reg [WIDTH_LLR-1:0] r_memory[0:MAX_ROWS-1][0:MAX_BLOCK_SIZE-1];
  reg signs[0:MAX_ROWS-1][0:MAX_BLOCK_SIZE-1];

  reg [WIDTH_BLOCK-1:0] row_index;
  reg [6:0] state, next_state;
  reg [WIDTH_BLOCK-1:0] col, next_col;

  wire last_row;

  localparam IDLE = 7'b0000001;
  localparam RETURN = 7'b0000010;
  localparam CLC_IDX = 7'b0000100;
  localparam CALC_ROW = 7'b0001000;
  localparam SAVE_TO_MEM = 7'b0010000;
  localparam RST = 7'b0100000;
  localparam WAIT_CALC = 7'b1000000;

  integer j, k;

  // Next state logic
  always @* begin
    case (state)
      IDLE: begin
        if (start_row) begin
          next_state = CLC_IDX;
        end else begin
          next_state = IDLE;
        end
      end
      CLC_IDX: begin
        next_state = CALC_ROW;
      end
      CALC_ROW: begin
        if (pbub_ready) begin
          next_state = WAIT_CALC;
        end else next_state = CALC_ROW;
      end
      WAIT_CALC: begin
        if (pcub_done) begin
          next_state = SAVE_TO_MEM;
        end else begin
          next_state = WAIT_CALC;
        end
      end
      SAVE_TO_MEM: begin
        if (last_row) begin
          next_state = RETURN;
        end else begin
          next_state = CLC_IDX;
        end
      end
      RETURN: begin
        next_state = IDLE;
      end
      RST: begin
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // State register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= RST;  // Reset state to idle
    end else begin
      state <= next_state;  // Update state
    end
  end

  // Calculate next index
  always @(posedge clk) begin
    if (start_row) begin
      row_index <= 0;
      col <= cell_in;
      col_out <= cell_in;
    end else if (state == CLC_IDX) begin
      if (col == (1 << WIDTH_BLOCK) - 1) begin
        next_col <= (1 << WIDTH_BLOCK) - 1;
      end else if (col < block_size_in - 1) begin
        next_col <= col + 1;
      end else begin
        next_col <= 0;
      end
      row_index <= row_index + 1;
    end else if (state == SAVE_TO_MEM) begin
      col <= next_col;
      col_out <= next_col;
    end
  end

  // Send start signal to parallel adder
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_parallel_adder <= 1'b0;
    else if (state == CALC_ROW & pbub_ready) begin
      start_parallel_adder <= 1'b1;
    end else start_parallel_adder <= 1'b0;
  end

  // Output the stored value if index is not -1
  always @(posedge clk) begin
    if (state == CALC_ROW) begin
      if (col == (1 << WIDTH_BLOCK) - 1) begin
        llr_to_parallel_adder  <= 0;
        sign_to_parallel_adder <= 1'b0;
      end else begin
        llr_to_parallel_adder  <= r_memory[row_index_in][col];
        sign_to_parallel_adder <= signs[row_index_in][col];
      end
    end
  end

  //  Save or reset memory
  always @(posedge clk) begin
    if (state == RST) begin
      for (j = 0; j < MAX_ROWS; j = j + 1) begin
        for (k = 0; k < MAX_BLOCK_SIZE; k = k + 1) begin
          r_memory[j][k] <= {(WIDTH_LLR){1'b0}};
          signs[j][k] <= 1'b0;
        end
      end
    end else if (state == SAVE_TO_MEM) begin
      if (col != (1 << WIDTH_BLOCK) - 1) begin
        r_memory[row_index_in][col] <= llr_in;
        signs[row_index_in][col] <= sign_in;
      end
    end
  end

  assign last_row = (row_index == block_size_in) ? 1'b1 : 1'b0;
  assign row_done = (state == RETURN) ? 1'b1 : 1'b0;
  assign add_pbub = pcub_done;

endmodule
