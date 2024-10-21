`timescale 1ns / 1ps

module ldpc_encoder #(
    parameter MAX_BLOCK_SIZE = 64,  // Length of the block size
    parameter MAX_ROWS = 32,  // Number of rows in shift matrix
    parameter MAX_COLS = 32,  // Number of columns shift matrix
    localparam MSG_LEN = MAX_ROWS * MAX_BLOCK_SIZE,  // Length of the input message
    localparam CODE_LEN = MAX_COLS * MAX_BLOCK_SIZE,  // Length of the encoded codeword
    localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE),  // Bit width for block size
    localparam WIDTH_COLS = $clog2(MAX_COLS + 1),
    localparam WIDTH_ROWS = $clog2(MAX_ROWS + 1),
    localparam MAX_ITERATIONS = ((MAX_ROWS * MAX_COLS * WIDTH_BLOCK + MAX_BLOCK_SIZE - 1) / MAX_BLOCK_SIZE),
    localparam WIDTH_ITERATIONS = $clog2(MAX_ITERATIONS + 1)
) (
    input wire clk,  // Clock signal
    input wire rst_n,  // Active low reset signal
    input wire start_input,  // Start calculation signal
    input wire start_conf_input,
    input wire [MAX_BLOCK_SIZE-1:0] data_in,
    output wire [MAX_BLOCK_SIZE-1:0] data_out,  // Output message after decoding
    output wire done  // Done signal output
);
  // Internal registers
  reg [MAX_ROWS*MAX_COLS*WIDTH_BLOCK-1:0] g_matrix;
  reg [WIDTH_BLOCK-1:0] block_size;
  reg [WIDTH_ITERATIONS-1:0] iteration;
  reg [WIDTH_ROWS-1:0] row_index, rows;
  reg [WIDTH_COLS-1:0] col_index, cols;
  reg [ MSG_LEN-1:0] msg;
  reg [CODE_LEN-1:0] codeword;
  reg [5:0] state, next_state;

  // Internal wires
  wire [MAX_BLOCK_SIZE-1:0] blocks_in;
  wire [MAX_BLOCK_SIZE-1:0] blocks_out[MAX_COLS-1:0];
  wire [WIDTH_BLOCK-1:0] shift_amount[MAX_COLS-1:0];
  wire last_row, last_col;

  integer j;

  // State machine
  localparam IDLE = 6'h1;
  localparam INPUT_METADATA = 6'h2;
  localparam INPUT_MATRIX = 6'h4;
  localparam INPUT_DATA = 6'h8;
  localparam CLC = 6'h10;
  localparam RETURN = 6'h20;

  // Rotate modules
  genvar i, k;
  generate
    for (i = 0; i < MAX_COLS; i = i + 1) begin
      rotate_right_vector #(
          .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE)
      ) rrv (
          .in_vector(blocks_in),
          .out_vector(blocks_out[i]),
          .shift_amount(shift_amount[i]),
          .width(block_size)
      );
    end
  endgenerate

  // Calculate next state
  always @* begin
    case (state)
      IDLE: begin
        if (start_conf_input) begin
          next_state = INPUT_METADATA;
        end else if (start_input) begin
          next_state = INPUT_DATA;
        end else begin
          next_state = IDLE;
        end
      end
      INPUT_METADATA: begin
        next_state = INPUT_MATRIX;
      end
      INPUT_MATRIX: begin
        if (start_conf_input) begin
          next_state = IDLE;
        end else begin
          next_state = INPUT_MATRIX;
        end
      end
      INPUT_DATA: begin
        if (last_row) begin
          next_state = CLC;
        end else begin
          next_state = INPUT_DATA;
        end
      end
      CLC: begin
        if (last_row) begin
          next_state = RETURN;
        end else begin
          next_state = CLC;
        end
      end
      RETURN: begin
        if (last_col) begin
          next_state = IDLE;
        end else begin
          next_state = RETURN;
        end
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always @(posedge clk) begin
    if (state == IDLE & start_conf_input) begin
      rows <= data_in[WIDTH_ROWS-1:0];
      cols <= data_in[WIDTH_COLS+7:8];
      block_size <= data_in[WIDTH_BLOCK+15:16];
      msg <= 0;
    end else if (state == INPUT_MATRIX) begin
      g_matrix[iteration*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= data_in;
    end else if (state == INPUT_DATA) begin
      msg[row_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= data_in;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      row_index <= 0;
    end else if (last_row) begin
      row_index <= 0;
    end else if (state == INPUT_DATA | state == CLC) begin
      row_index <= row_index + 1;
    end else begin
      row_index <= 0;
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      col_index <= 0;
    end else if (last_col) begin
      col_index <= 0;
    end else if (state == RETURN) begin
      col_index <= col_index + 1;
    end else begin
      col_index <= 0;
    end

  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      iteration <= 0;
    end else if (state == INPUT_METADATA) begin
      iteration <= 0;
    end else if (state == INPUT_MATRIX) begin
      iteration <= iteration + 1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      codeword <= 0;
    end else if (start_input) begin
      codeword <= 0;
    end else if (state == CLC) begin
      for (j = 0; j < MAX_COLS; j = j + 1) begin
        codeword[j*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= codeword[j*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] ^ blocks_out[j];
      end
    end
  end

  for (k = 0; k < MAX_COLS; k = k + 1) begin
    assign shift_amount[k] = g_matrix[(row_index*MAX_COLS+k)*WIDTH_BLOCK+:WIDTH_BLOCK];
    assign blocks_in = msg[row_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
  end

  assign done = (state == RETURN) ? 1'b1 : 1'b0;
  assign last_row = (row_index == MAX_ROWS - 1) ? 1'b1 : 1'b0;
  assign last_col = (col_index == MAX_COLS - 1) ? 1'b1 : 1'b0;
  assign data_out = codeword[col_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
endmodule
