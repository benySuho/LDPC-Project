`timescale 1ns / 1ps
`define INPUT_FILE "../input/matrix.txt"

module ldpc_encoder_tb;

  // Parameters
  parameter MAX_BLOCK_SIZE = 64;

  parameter MAX_ROWS = 12;
  parameter MAX_COLS = 24;
  parameter CODE_LEN = MAX_COLS * MAX_BLOCK_SIZE;
  parameter RAND_NUMS = 1;
  localparam WIDTH_COLS = $clog2(MAX_COLS + 1);
  localparam WIDTH_ROWS = $clog2(MAX_ROWS + 1);
  localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE);  // Bit width for block size


  // Inputs
  reg clk;
  reg rst_n;
  reg start_conf_input;
  reg start_input;
  reg [CODE_LEN-1:0] msg, msg_original;
  reg [MAX_ROWS*MAX_COLS*WIDTH_BLOCK-1:0] matrix_in;
  reg [WIDTH_ROWS-1:0] rows_in;
  reg [WIDTH_COLS-1:0] cols_in;
  reg [WIDTH_BLOCK-1:0] block_size;
  reg [MAX_BLOCK_SIZE-1:0] data_in, data_out;

  // Outputs
  reg [CODE_LEN-1:0] codeword;
  reg [CODE_LEN-1:0] rec_msg;
  reg [CODE_LEN-1:0] original;

  wire done;

  integer i, j, i_max;
  integer scan_file, data_file;
  integer num;


  // Instantiate the Unit Under Test (UUT)
  ldpc_encoder #(
      .MAX_BLOCK_SIZE(MAX_BLOCK_SIZE),
      .MAX_ROWS(MAX_ROWS),
      .MAX_COLS(MAX_COLS)
  ) uut (
      .clk(clk),
      .rst_n(rst_n),
      .start_input(start_input),
      .start_conf_input(start_conf_input),
      .data_in(data_in),
      .data_out(data_out),
      .done(done)
  );
  

  // Clock generationBLOCK_SIZE
  initial begin
    clk = 1;
    forever #5 clk = ~clk;  // Toggle clock every 5 time units
  end

  // Testbench process
  initial begin
    // Initialize inputs
    rst_n = 0;
    msg = 0;
    matrix_in = 0;
    block_size = 0;
    rows_in = 0;
    cols_in = 0;
    start_conf_input = 0;
    start_input = 0;

    // Apply reset
    #10 rst_n = 1;


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
    block_size = num;

    // input matrix
    matrix_in = {(MAX_COLS * MAX_COLS * WIDTH_BLOCK) {1'b1}};

    for (i = 0; i < rows_in; i++) begin
      for (j = 0; j < cols_in; j++) begin
        scan_file = $fscanf(data_file, "%d\n", num);
        if (num == -1) begin
          matrix_in[(i*MAX_COLS+j)*WIDTH_BLOCK+:WIDTH_BLOCK] = {(WIDTH_BLOCK) {1'b1}};
        end else begin
          matrix_in[(i*MAX_COLS+j)*WIDTH_BLOCK+:WIDTH_BLOCK] = num % MAX_BLOCK_SIZE;
        end
      end
    end

    $fclose(data_file);

    data_in = 0;
    data_in[7:0] = {(8) {1'b0}} | rows_in;
    data_in[15:8] = {(8) {1'b0}} | cols_in;
    data_in[23:16] = {(8) {1'b0}} | block_size;
    start_conf_input = 1;
    #10 start_conf_input = 0;
    #20;
    i_max = ((MAX_COLS * MAX_ROWS * WIDTH_BLOCK + MAX_BLOCK_SIZE - 1) / MAX_BLOCK_SIZE);
    for (i = 0; i < i_max; i = i + 1) begin
      if (i == i_max - 1) begin
        start_conf_input = 1;
        data_in = matrix_in[MAX_COLS*MAX_ROWS*WIDTH_BLOCK-1:MAX_COLS*MAX_ROWS*WIDTH_BLOCK-1-MAX_BLOCK_SIZE];
      end else begin
        data_in = {(MAX_BLOCK_SIZE) {1'b0}} | matrix_in[i*MAX_BLOCK_SIZE+:MAX_BLOCK_SIZE];
        // $display("Out: %h", data_in);
      end
      #10;
    end
    start_conf_input = 0;

    msg = 1368'b011111110011000001100010011111011110101111011001100101100100011111111010100100111111001010001001101000101000010010001101101100110101010011101010111101100111101001000000010110100000111001010000011011000111100011100010111101110011101001010001111110011010010001011100110011100110011001000011011111110100100110111100110101011010001011111100001000100011001111110000100000000011000100101101010111010011110111101010010111001011100011011001110110001111001111010111100010111101001101010100000110111010100101110110110011101100111011101110010000010010010010100111001101110100101010000011000010011110111010011101100001011110101001011111000101000101100100110010011111111110100011000011110011001010110000001101010100001011010110010111111011100110011010101010111100101000011010010001001001011011011110100001100101000111000000111000001010101100100000000000101101110100100100000010001100110000111001000001111101101110100111001110001010111011110011111101000100000101111011110001010101101110110000100110000001111101100101111110011100100110110011;
    original = 1368'b011111110011000001100010011111011110101111011001100101100100011111111010100100111111001010001001101000101000010010001101101100110101010011101010111101100111101001000000010110100000111001010000011011000111100011100010111101110011101001010001111110011010010001011100110011100110011001000011011111110100100110111100110101011010001011111100001000100011001111110000100000000011000100101101010111010011110111101010010111001011100011011001110110001111001111010111100010111101001101010100000110111010100101110110110011101100111011101110010000010010010010100111001101110100101010000011000010011110111010011101100001011110101001011111000101000101100100110010011111111110100011000011110011001010110000001101010100001011010110010111111011100110011010101010111100101000011010010001001001011011011110100001100101000111000000111000001010101100100000000000101101110100100100000010001100110000111001000001111101101110100111001110001010111011110011111101000100000101111011110001010101101110110000100110000001111101100101111110011100100110110011011001011111100000110110101110000001011100010010101110000010010010101101011110110100111101001000001011110110001101110100001011101000110111110010001010000001010100011010000000000011111001101101000010001111011010101101001001011011011110111111101010111001111101101010111000011110110011000110100110101100111111011011110101101111000001001000111000;

    send_codeword(msg);
    wait (done);
    receive_codeword();

    // Result
    $display("%b", codeword == original);

    $display("%h", msg);

    #20 $finish;

  end

  task automatic send_codeword;
    input [MAX_COLS*MAX_BLOCK_SIZE-1:0] codeword;  // Input codeword

    integer i;  // Loop variable
    reg [MAX_BLOCK_SIZE-1:0] temp_num;

    begin
      msg_original = codeword;
      #10 start_input = 1;
      #10 start_input = 0;
      #10;
      for (i = 0; i < MAX_COLS - rows_in; i = i + 1) begin
        if (i < cols_in) begin
          temp_num = codeword[MAX_BLOCK_SIZE-1:0];
          temp_num = temp_num << (MAX_BLOCK_SIZE - block_size);
          codeword = codeword >> block_size;
          data_in  = temp_num;
        end else begin
          data_in = 0;
        end
        #10;  // Simulation delay
      end
    end
  endtask

  task automatic receive_codeword;
    codeword = 0;
    for (i = 0; i < MAX_COLS; i = i + 1) begin
      #10;
      codeword[i*block_size+:MAX_BLOCK_SIZE] = (data_out >> (MAX_BLOCK_SIZE - block_size));
    end
  endtask

endmodule
