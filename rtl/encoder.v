`timescale 1ns / 1ps

module ldpc_encoder #(
    parameter MAX_BLOCK_SIZE = 64,  // Length of the block size
    parameter MAX_ROWS = 12,  // Number of rows in shift matrix
    parameter MAX_COLS = 24,  // Number of columns shift matrix
    // Length of the codeword
    localparam CODE_LEN = MAX_COLS * MAX_BLOCK_SIZE,
    // Bit width for block size
    localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE),
    localparam WIDTH_COLS = $clog2(MAX_COLS + 1),
    localparam WIDTH_ROWS = $clog2(MAX_ROWS + 1),
    localparam MAX_ITERATIONS = 
      ((MAX_ROWS * MAX_COLS * WIDTH_BLOCK + MAX_BLOCK_SIZE - 1) 
                                              / MAX_BLOCK_SIZE),
    localparam WIDTH_ITERATIONS = $clog2(MAX_ITERATIONS + 1)
) (
    input wire clk,  // Clock signal
    input wire rst_n,  // Active low reset signal
    input wire start_input,  // Start calculation signal
    input wire start_conf_input,
    input wire [MAX_BLOCK_SIZE-1:0] data_in,
    // Output message after decoding
    output wire [MAX_BLOCK_SIZE-1:0] data_out,
    output wire done  // Done signal output
);
  // Internal registers
  reg [MAX_ROWS*MAX_COLS*WIDTH_BLOCK-1:0] g_matrix;
  reg [WIDTH_BLOCK-1:0] block_size;
  reg [WIDTH_ITERATIONS-1:0] iteration;
  reg [WIDTH_ROWS-1:0] row_index, read_index, rows;
  reg [WIDTH_COLS-1:0] col_index, cols, save_index;
  reg [CODE_LEN-1:0] codeword;
  reg [7:0] state, next_state;
  reg [MAX_BLOCK_SIZE-1:0] temp;

  // Internal wires
  wire [MAX_BLOCK_SIZE-1:0] block_in;
  wire [MAX_BLOCK_SIZE-1:0] block_out;
  wire [WIDTH_BLOCK-1:0] shift;
  wire last_row, last_col;


  // State machine parameters
  localparam IDLE = 8'h1;
  localparam INPUT_METADATA = 8'h2;
  localparam INPUT_MATRIX = 8'h4;
  localparam INPUT_DATA = 8'h8;
  localparam CLC_1 = 8'h10;
  localparam SAVE = 8'h20;
  localparam CLC_2 = 8'h40;
  localparam RET = 8'h80;

  // Instantiate the Rotate module
  rotate_left_vector #(
      .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE)
  ) rlv (
      .in_vector(block_in),
      .out_vector(block_out),
      .shift_amount(shift),
      .width(block_size)
  );

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
        if (last_col) begin
          next_state = CLC_1;
        end else begin
          next_state = INPUT_DATA;
        end
      end
      CLC_1: begin
        if (last_row & last_col) begin
          next_state = SAVE;
        end else begin
          next_state = CLC_1;
        end
      end
      SAVE: begin
        if (last_row) begin
          next_state = RET;
        end else begin
          next_state = CLC_2;
        end
      end
      CLC_2: begin
        if (last_col) begin
          next_state = SAVE;
        end else begin
          next_state = CLC_2;
        end
      end
      RET: begin
        if (last_col) begin
          next_state = IDLE;
        end else begin
          next_state = RET;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Handle input metadata and matrix
  always @(posedge clk) begin
    if (state == IDLE & start_conf_input) begin
      rows <= data_in[WIDTH_ROWS-1:0];
      cols <= data_in[WIDTH_COLS+7:8];
      block_size <= data_in[WIDTH_BLOCK+15:16];
    end else if (state == INPUT_MATRIX) begin
      g_matrix[iteration*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= data_in;
    end
  end

  // Row index logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      row_index <= 0;
    end else if (state == INPUT_DATA) begin
      row_index <= rows - 1;
    end else if (state == CLC_1 & last_row & last_col) begin
      row_index <= rows - 1;
    end else if (state == CLC_1 & last_col) begin
      row_index <= row_index - 1;
    end else if (state == SAVE) begin
      row_index <= row_index - 1;
    end
  end

  // Read index logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      read_index <= 0;
    end else if (state == INPUT_DATA) begin
      read_index <= rows - 1;
    end else if (state == CLC_1 & last_row & last_col) begin
      read_index <= rows - 1;
    end else if (state == CLC_1 & last_col) begin
      read_index <= row_index - 1;
    end else if (state == SAVE) begin
      read_index <= row_index;
    end
  end

  // Column index logic
  always @(posedge clk) begin
    if (!rst_n) begin
      col_index <= 0;
    end else if (start_input) begin
      col_index <= rows;
    end else if (state == CLC_1 & last_col) begin
      col_index <= rows;
    end else if (state == SAVE) begin
      col_index <= 0;
    end else if (last_col) begin
      col_index <= 0;
    end else if (state == RET | state == INPUT_DATA | state == CLC_1 | state == CLC_2) begin
      col_index <= col_index + 1;
    end

  end

  // Iteration counter logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      iteration <= 0;
    end else if (state == INPUT_METADATA) begin
      iteration <= 0;
    end else if (state == INPUT_MATRIX) begin
      iteration <= iteration + 1;
    end
  end

  // Codeword register logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      codeword <= 0;
    end else if (start_input) begin
      codeword <= 0;
    end else if (state == INPUT_DATA) begin
      codeword[col_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= data_in;
    end else if (state == SAVE) begin
      codeword[save_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= temp;
    end
  end

  // Temp register logic
  always @(posedge clk) begin
    case (state)
      INPUT_DATA: begin
        temp <= 0;
      end
      SAVE: begin
        temp <= 0;
      end
      CLC_1: begin
        temp <= temp ^ block_out;
      end
      CLC_2: begin
        temp <= temp ^ block_out;
      end
      default: begin
      end
    endcase
  end

  // Save index logic
  always @(posedge clk) begin
    if (start_input) begin
      save_index <= rows - 1;
    end else if (state == SAVE) begin
      save_index <= save_index - 1;
    end
  end

  assign shift = g_matrix[(read_index*MAX_COLS+col_index)*WIDTH_BLOCK+:WIDTH_BLOCK];
  assign block_in = codeword[col_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
  assign done = (state == RET) ? 1'b1 : 1'b0;
  assign last_row = (row_index == 0) ? 1'b1 : 1'b0;
  assign last_col = (col_index == cols - 1) ? 1'b1 : 1'b0;
  assign data_out = codeword[col_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
endmodule
