`timescale 1ns / 1ps  

module validator #(
    parameter MAX_BLOCK_SIZE = 8,  // Maximum block size
    parameter MAX_ROWS = 8,  // Maximum number of rows in the H matrix
    parameter MAX_COLS = 8,  // Maximum number of columns in the H matrix
    localparam MAX_CODE_LEN = MAX_COLS * MAX_BLOCK_SIZE,  // Codeword length
    localparam WIDTH_CODE_LEN = $clog2(MAX_CODE_LEN + 1),  // Bit width
    localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE),  // Bit width
    localparam WIDTH_ROWS = $clog2(MAX_ROWS + 1),  // Bit width
    localparam WIDTH_COLS = $clog2(MAX_COLS + 1)  // Bit width
) (
    input wire clk,  // Clock signal
    input wire rst_n,  // Active low reset signal
    input wire start,  // Start calculation signal
    input wire [MAX_CODE_LEN-1:0] codeword_in,  // Input codeword
    input wire [MAX_ROWS*MAX_COLS*WIDTH_BLOCK-1:0] h_matrix_in,  // H matrix
    input wire [WIDTH_BLOCK-1:0] block_size_in,  // Block size input
    input wire [WIDTH_ROWS-1:0] rows_in,  // Number of rows in H matrix
    input wire [WIDTH_COLS-1:0] cols_in,  // Number of columns in H matrix
    output wire ready,
    output reg valid  // Validity flag output
);
  reg [MAX_BLOCK_SIZE-1:0] syndrome;  // Temporary block
  reg [WIDTH_ROWS-1:0] row_index, rows;  // Row row_index and total rows
  reg [WIDTH_COLS-1:0] col_index, cols;  // Total columns
  reg [WIDTH_BLOCK-1:0] block_size;  // Block size register
  reg [4:0] state, next_state;  // State and next state registers

  // Wire declarations
  wire [MAX_COLS*WIDTH_BLOCK-1:0] row;  // Wire for current row of H matrix
  wire [WIDTH_BLOCK-1:0] shift;
  wire [MAX_BLOCK_SIZE-1:0] block_in, block_out;

  // integer i;  // Loop variable

  // State machine encoding
  localparam IDLE = 5'b00001;  // Idle state
  localparam PRP = 5'b00010;  // Preparation for calculation
  localparam CLC = 5'b00100;  // Calculation state
  localparam VAL = 5'b01000;  // Validation state
  localparam RETURN = 5'b10000;  // Return state

  // Rotate module
  rotate_left_vector #(
      .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE)
  ) rlv (
      .in_vector(block_in),
      .out_vector(block_out),
      .shift_amount(shift),
      .width(block_size)
  );

  // Next state logic
  always @* begin
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PRP;  
        end else begin
          next_state = IDLE;
        end
      end
      PRP: begin
        next_state = CLC; 
      end
      CLC: begin
        if (col_index == cols - 1) begin
          next_state = VAL; 
        end else begin
          next_state = CLC;
        end
      end
      VAL: begin
        if ((|syndrome) | row_index == rows - 1) begin
          next_state = RETURN;
        end else begin
          next_state = PRP;
        end
      end
      RETURN: begin
        next_state = IDLE;  
      end
      default: begin
        next_state = IDLE;  // Default to idle state
      end
    endcase
  end

  // State register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;  // Reset state to idle
    end else begin
      state <= next_state;  // Update state
    end
  end

  // Input registers update
  always @(posedge clk) begin
    if (start) begin
      rows <= rows_in;  // Load number of rows
      cols <= cols_in;  // Load number of columns
      block_size <= block_size_in;  // Load block size
    end
  end

  // Index register update
  always @(posedge clk) begin
    if (start) begin
      row_index <= 0;  // Initialize index
    end else if (state == VAL) begin
      row_index <= row_index + 1;  
    end
  end

  always @(posedge clk) begin
    if (state == PRP) begin
      col_index <= 0;
    end else if (state == CLC) begin
      col_index <= col_index + 1;
    end
  end

  always @(posedge clk) begin
    if (state == PRP) begin
      syndrome <= 0;
    end else if (state == CLC) begin
      syndrome <= syndrome ^ block_out;
    end
  end

  // Valid output update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid <= 1'b0;  // Reset valid to 0
    end else if (state == PRP) begin
      valid <= 1'b0;  // Reset valid to 0
    end else if (state == RETURN) begin
      valid <= ~(|syndrome);
    end
  end

  // Assign control signals
  assign row = 
    h_matrix_in[row_index*MAX_COLS*WIDTH_BLOCK+:MAX_COLS*WIDTH_BLOCK];
  assign shift = row[col_index*WIDTH_BLOCK+:WIDTH_BLOCK];
  assign block_in = 
    codeword_in[col_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
  assign ready = (state == IDLE) ? 1'b1 : 1'b0;  // Ready signal
endmodule
