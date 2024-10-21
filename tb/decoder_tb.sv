`timescale 1ns / 1ps
`define INPUT_FILE "matrix.txt" // Parity Check Matrix input file

module ldpc_decoder_tb;

  // Parameters
  parameter MAX_BLOCK_SIZE = 64;  // 
  parameter MAX_ROWS = 18;
  parameter MAX_COLS = 32;
  parameter MAX_ITERATIONS = 50;
  parameter WIDTH_LLR = 6;
  parameter INITIAL_LLR = 5'b10110;
  localparam MAX_CODE_LEN = MAX_COLS * MAX_BLOCK_SIZE;
  localparam MAX_MSG_LEN = MAX_ROWS * MAX_BLOCK_SIZE;
  localparam WIDTH_CODE_LEN = $clog2(MAX_CODE_LEN + 1);
  localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE);
  localparam WIDTH_ROWS = $clog2(MAX_ROWS + 1);
  localparam WIDTH_COLS = $clog2(MAX_COLS + 1);
  localparam WIDTH_ITERATION = $clog2(MAX_ITERATIONS + 1);

  // Inputs
  reg clk;
  reg rst_n;
  reg start_conf_input;
  reg start_input;
  reg [WIDTH_CODE_LEN-1:0] codeword_len_in;
  reg [MAX_CODE_LEN-1:0] codeword_in;
  reg [MAX_CODE_LEN-1:0] original;
  reg [MAX_CODE_LEN-1:0] codeword_out;
  reg [MAX_CODE_LEN-1:0] codeword_inital;
  reg [MAX_ROWS*MAX_COLS*WIDTH_BLOCK-1:0] h_matrix_in;
  reg [WIDTH_BLOCK-1:0] block_size_in;
  reg [WIDTH_ROWS-1:0] rows_in;
  reg [WIDTH_COLS-1:0] cols_in;
  reg [WIDTH_ITERATION-1:0] iterations_in;
  reg [MAX_BLOCK_SIZE-1:0] data_in, data_out;
  reg [MAX_BLOCK_SIZE-1:0] temp_num;

  // Outputs
  wire [MAX_CODE_LEN-1:0] estimate;
  wire valid;
  wire done;

  integer i, j, i_max;
  integer data_file;
  integer scan_file;
  integer num;
  reg [MAX_BLOCK_SIZE-1:0] str;  // String to hold the number


  // Instantiate the DUT (Device Under Test)
  ldpc_decoder #(
      .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE),
      .MAX_ROWS(MAX_ROWS),
      .MAX_COLS(MAX_COLS),
      .MAX_ITERATIONS(MAX_ITERATIONS),
      .WIDTH_LLR(WIDTH_LLR),
      .INITIAL_LLR(INITIAL_LLR)
  ) decoder (
      .clk(clk),
      .rst_n(rst_n),
      .start_input(start_input),
      .start_conf_input(start_conf_input),
      .data_in(data_in),
      .data_out(data_out),
      .valid(valid),
      .done(done)
  );

  // Clock generation
  initial begin
    clk = 1;
    forever #5 clk = ~clk;  // 10 ns clock period
  end

  // Test stimulus
  initial begin
    // Initialize inputs
    rst_n = 0;
    codeword_len_in = 0;
    codeword_in = 0;
    original = 0;
    codeword_inital = 0;
    h_matrix_in = 0;
    block_size_in = 0;
    rows_in = 0;
    cols_in = 0;
    iterations_in = 0;

    // Apply reset
    #10 rst_n = 1;

    // Get matrix configurations from file
    data_file = $fopen(`INPUT_FILE, "r");
    if (data_file == 0) begin
      $display("Error: Could not open file.");
      $finish;
    end

    scan_file = $fscanf(data_file, "%d\n", num);
    rows_in = num;
    scan_file = $fscanf(data_file, "%d\n", num);
    cols_in = num;
    scan_file = $fscanf(data_file, "%d\n", num);
    block_size_in = num;

    // get matrix
    h_matrix_in = {(MAX_COLS * MAX_COLS * WIDTH_BLOCK) {1'b1}};

    for (i = 0; i < rows_in; i++) begin
      for (j = 0; j < cols_in; j++) begin
        scan_file = $fscanf(data_file, "%d\n", num);
        if (num == -1) begin
          h_matrix_in[(i*MAX_COLS+j)*WIDTH_BLOCK+:WIDTH_BLOCK] = 
                                          {(WIDTH_BLOCK) {1'b1}};
        end else begin
          h_matrix_in[(i*MAX_COLS+j)*WIDTH_BLOCK+:WIDTH_BLOCK] = 
                                            num % MAX_BLOCK_SIZE;
        end
      end
    end

    $display("Rows: %d, Columns: %d, Block Size: %d",
                                           rows_in, cols_in, block_size_in);

    $fclose(data_file);

    // Send Parity Check Matrix to Decoder module
    iterations_in = 50;  // Maximum iterations (50)

    data_in = 0;
    data_in[7:0] = {(8) {1'b0}} | rows_in;
    data_in[15:8] = {(8) {1'b0}} | cols_in;
    data_in[23:16] = {(8) {1'b0}} | iterations_in;
    data_in[31:24] = {(8) {1'b0}} | block_size_in;
    start_conf_input = 1;
    #10 start_conf_input = 0;
    #20;
    i_max = 
      ((MAX_COLS * MAX_ROWS * WIDTH_BLOCK + MAX_BLOCK_SIZE - 1) / MAX_BLOCK_SIZE);
    for (i = 0; i < i_max; i = i + 1) begin
      if (i == i_max - 1) begin
        start_conf_input = 1;
        data_in = 
          h_matrix_in[MAX_COLS*MAX_ROWS*WIDTH_BLOCK-1:
                                MAX_COLS*MAX_ROWS*WIDTH_BLOCK-1-MAX_BLOCK_SIZE];
      end else begin
        data_in = 
          {(MAX_BLOCK_SIZE) {1'b0}} | h_matrix_in[i*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
      end
      #10;
    end

    start_conf_input = 0;

    $display("8: Expected Fail");
    // input codeword
    original = ; // original codeword
    codeword_in = ; // Codeword with errors

    // Process decode
    send_codeword(codeword_in);
    wait (done);
    receive_codeword();
    print_result();

    // Stop simulation
    #10 $finish;
  end

  // Send codeword to decoder module
  task automatic send_codeword;
    input [MAX_COLS*MAX_BLOCK_SIZE-1:0] codeword;  // Input codeword

    integer i;  // Loop variable
    reg [MAX_BLOCK_SIZE-1:0] temp_num;

    begin
      #10 start_input = 1;
      #10 start_input = 0;
      #10;
      for (i = 0; i < MAX_COLS; i = i + 1) begin
        if (i < cols_in) begin
          temp_num = codeword[MAX_BLOCK_SIZE-1:0];
          temp_num = temp_num << (MAX_BLOCK_SIZE - block_size_in);
          codeword = codeword >> block_size_in;
          data_in  = temp_num;
        end else begin
          data_in = 0;
        end
        #10;  // Simulation delay
      end
    end
  endtask

  // Receive codeword from decoder module
  task automatic receive_codeword;
    codeword_out = 0;
    for (i = 0; i < MAX_COLS; i = i + 1) begin
      #10;
      codeword_out[i*block_size_in+:MAX_BLOCK_SIZE] = 
                        (data_out >> (MAX_BLOCK_SIZE-block_size_in));
    end
  endtask

  task automatic print_result;
    // Print vectors
    // $display("%h", original);
    // $display("%h", codeword_out);

    if (valid) begin
      $display("\tDecoded output is valid");
      if (codeword_out == original) begin
        $display("\tCodeword restored");
      end else begin
        $display("\tCodeword not restored");
      end
    end else begin
      $display("\tDecoding failed");
    end
  endtask

endmodule
