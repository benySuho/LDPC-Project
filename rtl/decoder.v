`timescale 1ns / 1ps

module ldpc_decoder #(
    parameter MAX_BLOCK_SIZE = 64,  // Maximum block size
    parameter MAX_ROWS = 8,  // Maximum number of rows in the H matrix
    parameter MAX_COLS = 32,  // Maximum number of columns in the H matrix
    parameter MAX_ITERATIONS = 50,  // Maximum number of iterations
    parameter WIDTH_LLR = 6,  // Bit width for LLR values: in range 5-8
    // Initial log-likelihood ratio: 10110=2.75
    parameter INITIAL_LLR = 5'b10110,  
    // Maximum codeword length
    localparam MAX_CODE_LEN = MAX_COLS * MAX_BLOCK_SIZE,  
    // Maximum message length
    localparam MAX_MSG_LEN = MAX_ROWS * MAX_BLOCK_SIZE,  
    // Bit width for codeword length
    localparam WIDTH_CODE_LEN = $clog2(MAX_CODE_LEN + 1),  
    // Bit width for block size
    localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE),  
     // Bit width for row index
    localparam WIDTH_ROWS = $clog2(MAX_ROWS + 1), 
     // Bit width for column index
    localparam WIDTH_COLS = $clog2(MAX_COLS + 1), 
    // Bit width for iteration counter
    localparam WIDTH_ITERATION = $clog2(MAX_ITERATIONS + 1)  
) (
    input wire clk,  // Clock signal
    input wire rst_n,  // Active low reset signal
    input wire start_input,  // Start calculation signal
    input wire start_conf_input,
    input wire [MAX_BLOCK_SIZE-1:0] data_in,
    output wire [MAX_BLOCK_SIZE-1:0] data_out,  // Output after decoding
    output reg valid,  // Validity flag output
    output wire done  // Done signal output
);
  reg [MAX_CODE_LEN-1:0] codeword;
  reg [MAX_CODE_LEN-1:0] estimate;  // Output message after decoding
  reg [MAX_ROWS*MAX_COLS*WIDTH_BLOCK-1:0] h_matrix;
  reg [WIDTH_BLOCK-1:0] block_size;
  reg [WIDTH_ROWS-1:0] rows, row_index, next_row;
  reg [WIDTH_COLS-1:0] col_index, cols;
  reg [WIDTH_ITERATION-1:0] iterations;
  reg [WIDTH_ITERATION-1:0] iteration;
  reg [WIDTH_BLOCK-1:0] row[0:MAX_COLS-1];
  reg start_row;
  reg reset_n;

  reg [8:0] state, next_state;

  wire start_pcub, done_pcub;
  wire [MAX_COLS*WIDTH_LLR-1:0] llr_to_pcub;
  wire [MAX_COLS-1:0] signs_to_pcub;

  wire [MAX_COLS*WIDTH_LLR-1:0] llr_to_router;
  wire [MAX_COLS-1:0] signs_to_router;
  wire [MAX_COLS-1:0] add_pbub;
  wire [MAX_COLS-1:0] row_done_router;
  wire [MAX_COLS-1:0] start_parallel_adder_from_router;
  wire start_parallel_adder;
  wire ready_validator;
  wire row_done;
  wire last_col;
  wire change_memory;
  wire [WIDTH_BLOCK-1:0] indexes_pbub[0:MAX_COLS-1];
  wire [MAX_COLS-1:0] pbub_ready;
  wire all_pbub_ready;
  wire [MAX_COLS-1:0] sign_from_pbub;
  wire [MAX_COLS*(WIDTH_LLR+1)-1:0] llr_from_pbub;
  wire [MAX_CODE_LEN-1:0] hard_decision;
  wire [MAX_COLS*WIDTH_LLR-1:0] llr_from_router;
  wire [MAX_COLS-1:0] sign_from_router;
  wire last_row;
  wire last_iteration;
  wire start_validation;
  wire valid_validator;
  wire reset_modules_n;

  // State machine
  localparam IDLE = 9'h1;
  localparam INPUT_METADATA = 9'h2;
  localparam INPUT_MATRIX = 9'h4;
  localparam INPUT_DATA = 9'h8;
  localparam ITER = 9'h10;
  localparam PRP = 9'h20;
  localparam CALC_ROW = 9'h40;
  localparam CHECK = 9'h80;
  localparam RETURN = 9'h100;

  genvar i_pbub, i_route;
  integer i;

  // ADD Bit Update Block
  generate
    for (i_pbub = 0; i_pbub < MAX_COLS; i_pbub = i_pbub + 1) begin
      parallel_bit_update #(
          .WIDTH_LLR(WIDTH_LLR),
          .INITIAL_LLR(INITIAL_LLR),
          .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE)
      ) pbub (
          .received_data_in(codeword[i_pbub*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE]),
          .clk(clk),
          .rst_n(reset_modules_n),
          .add(add_pbub[i_pbub]),
          .change_memory(change_memory),
          .llr_in(llr_to_router[i_pbub*WIDTH_LLR+:WIDTH_LLR]),
          .sign_llr_in(signs_to_router[i_pbub]),
          .index(indexes_pbub[i_pbub]),
          .sign_llr_out(sign_from_pbub[i_pbub]),
          .llr_out(llr_from_pbub[i_pbub*(WIDTH_LLR+1)+:(WIDTH_LLR+1)]),
          .hard_decision(hard_decision[i_pbub*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE]),
          .ready(pbub_ready[i_pbub])
      );
    end
  endgenerate

  // ADD Router
  generate
    for (i_route = 0; i_route < MAX_COLS; i_route = i_route + 1) begin
      route #(
          .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE),
          .MAX_ROWS(MAX_ROWS),
          .WIDTH_LLR(WIDTH_LLR)
      ) route (
          .clk(clk),
          .rst_n(reset_modules_n),
          .start_row(start_row),
          .block_size_in(block_size),
          .pcub_done(done_pcub),
          .cell_in(row[i_route]),
          .row_index_in(row_index),
          .llr_in(llr_to_router[i_route*WIDTH_LLR+:WIDTH_LLR]),
          .sign_in(signs_to_router[i_route]),
          .llr_to_parallel_adder(llr_from_router[i_route*WIDTH_LLR+:WIDTH_LLR]),
          .sign_to_parallel_adder(sign_from_router[i_route]),
          .col_out(indexes_pbub[i_route]),
          .add_pbub(add_pbub[i_route]),
          .row_done(row_done_router[i_route]),
          .start_parallel_adder(start_parallel_adder_from_router[i_route]),
          .pbub_ready(pbub_ready[i_route])
      );
    end
  endgenerate

  // Instantiate the pcub module
  pcub #(
      .MAX_COLS (MAX_COLS),
      .WIDTH_LLR(WIDTH_LLR)
  ) pcub (
      .clk(clk),
      .rst_n(reset_modules_n),
      .start(start_pcub),
      .llr_in(llr_to_pcub),
      .sign_in(signs_to_pcub),
      .llr_out(llr_to_router),
      .sign_out(signs_to_router),
      .done(done_pcub)
  );

  parallel_adder #(
      .MAX_COLS (MAX_COLS),
      .WIDTH_LLR(WIDTH_LLR)
  ) p_adder (
      .clk(clk),
      .add(start_parallel_adder),
      .rst_n(reset_modules_n),
      .llr_from_memory(llr_from_router),
      .llr_from_pbub(llr_from_pbub),
      .sign_from_memory(sign_from_router),
      .sign_from_pbub(sign_from_pbub),
      .llr_out(llr_to_pcub),
      .sign_out(signs_to_pcub),
      .done(start_pcub)
  );

  validator #(
      .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE),
      .MAX_ROWS(MAX_ROWS),
      .MAX_COLS(MAX_COLS)
  ) validator (
      .clk(clk),
      .rst_n(reset_modules_n),
      .start(start_validation),
      .codeword_in(estimate),
      .h_matrix_in(h_matrix),
      .block_size_in(block_size),
      .rows_in(rows),
      .cols_in(cols),
      .ready(ready_validator),
      .valid(valid_validator)
  );

  // Next state logic
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
          next_state = CHECK;
        end else begin
          next_state = INPUT_DATA;
        end
      end
      ITER: begin
        if (valid_validator) begin
          next_state = RETURN;
        end else begin
          next_state = PRP;
        end
      end
      PRP: begin
        if (valid_validator) begin
          next_state = RETURN;
        end else begin
          next_state = CALC_ROW;
        end
      end
      CALC_ROW: begin
        if (valid_validator) begin
          next_state = RETURN;
        end else if (~row_done) begin
          next_state = CALC_ROW;
        end else if (last_row) begin
          next_state = CHECK;
        end else begin
          next_state = PRP;
        end
      end
      CHECK: begin
        if (valid_validator) begin
          next_state = RETURN;
        end else if (~ready_validator | ~all_pbub_ready) begin
          next_state = CHECK;
        end else if (last_iteration & ~ready_validator) begin
          next_state = CHECK;
        end else if (last_iteration & ready_validator) begin
          next_state = RETURN;
        end else begin
          next_state = ITER;
        end
      end
      RETURN: begin
        if (last_col) begin
          next_state = IDLE;
        end else begin
          next_state = RETURN;
        end
      end
      default: begin
        next_state = IDLE;
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

  // Receive parity check matrix
  always @(posedge clk) begin
    if (state == IDLE & start_conf_input) begin
      rows <= data_in[WIDTH_ROWS-1:0];
      cols <= data_in[WIDTH_COLS+7:8];
      iterations <= data_in[WIDTH_ITERATION+15:16];
      block_size <= data_in[WIDTH_BLOCK+23:24];
    end else if (state == INPUT_MATRIX) begin
      h_matrix[iteration*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= data_in;
    end else if (state == INPUT_DATA) begin
      codeword[col_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE] <= data_in;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reset_n <= 0;  // reset or stop all modules to run
    end else if (valid_validator | last_col) begin
      reset_n <= 0;  // reset or stop all modules to run
    end else begin
      reset_n <= 1;
    end
  end

  // Calculate iteration number
  always @(posedge clk) begin
    if (start_input | state == IDLE) begin
      iteration <= 0;
    end else if (state == ITER | state == INPUT_MATRIX) begin
      iteration <= iteration + 1;
    end
  end

  // Calculate indexes
  always @(posedge clk) begin
    if (start_input) begin
      col_index <= 0;
    end else if (state == INPUT_MATRIX | state == INPUT_DATA | state == RETURN) begin
      col_index <= col_index + 1;
    end else if (state == PRP) begin
      row_index <= next_row;
      next_row  <= next_row + 1;
      start_row <= 1'b1;
      for (i = 0; i < MAX_COLS; i = i + 1) begin
        if (i < cols) begin
          row[i] <= h_matrix[(next_row*MAX_COLS+i)*WIDTH_BLOCK+:WIDTH_BLOCK];
        end else begin
          row[i] <= (1 << WIDTH_BLOCK) - 1;
        end
      end
    end else if (state == CHECK) begin
      col_index <= 0;
      row_index <= 0;
      next_row  <= 0;
    end else begin
      start_row <= 1'b0;
    end
  end

  // Get estimated codeword
  always @(posedge clk) begin
    if (state == CHECK) begin
      if (iteration == 0) begin
        estimate <= codeword;
      end else begin
        estimate <= hard_decision;
      end
    end
  end

  // Output valid signal if codeword is valid
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid <= 0;
    end else if (valid_validator) begin
      valid <= 1;
    end else if (state == ITER) begin
      valid <= 0;
    end else begin
      valid <= valid;
    end
  end

  assign data_out = estimate[col_index*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
  assign last_row = (next_row == rows) ? 1'b1 : 1'b0;
  assign last_col = (col_index == MAX_COLS - 1) ? 1'b1 : 1'b0;
  assign last_iteration = (iteration == iterations) ? 1'b1 : 1'b0;
  assign start_validation = 
                    (state == ITER) && (ready_validator) ? 1'b1 : 1'b0;
  assign row_done = &row_done_router;
  assign reset_modules_n = rst_n & reset_n;
  assign change_memory = (state == ITER);
  assign start_parallel_adder = &start_parallel_adder_from_router;
  assign done = (state == RETURN);
  assign all_pbub_ready = &pbub_ready;

endmodule
