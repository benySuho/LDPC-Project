`timescale 1ns / 1ps

module parallel_bit_update #(
    parameter WIDTH_LLR = 6,
    parameter INITIAL_LLR = 5'b10110,  // 2.75
    parameter MAX_BLOCK_SIZE = 64,
    localparam WIDTH_BLOCK = $clog2(MAX_BLOCK_SIZE)
) (
    input wire [0:MAX_BLOCK_SIZE-1] received_data_in,
    input wire clk,
    input wire rst_n,
    input wire add,
    input wire change_memory,
    input wire [WIDTH_LLR-1:0] llr_in,
    input wire sign_llr_in,  // 1 negative, 0 positive
    input wire [WIDTH_BLOCK-1:0] index,
    output wire ready,
    output wire sign_llr_out,
    output wire [WIDTH_LLR:0] llr_out,
    output wire [MAX_BLOCK_SIZE-1:0] hard_decision

);
  reg [WIDTH_LLR:0] column_sum_memories[0:1][MAX_BLOCK_SIZE-1:0];
  reg sign_column_sum_memories[0:1][MAX_BLOCK_SIZE-1:0];
  reg choose_memory;
  reg sign_llr;
  reg [WIDTH_LLR+1:0] llr;
  reg [WIDTH_LLR+1:0] temp;
  reg temp_sign;

  wire [0:MAX_BLOCK_SIZE-1] sign_column_sum_memoriesA;
  wire [0:MAX_BLOCK_SIZE-1] sign_column_sum_memoriesB;

  reg [WIDTH_BLOCK-1:0] last_index;
  reg [4:0] state, next_state;

  localparam IDLE = 5'b00001;
  localparam NEW_ITERATION = 5'b00010;
  localparam ADD = 5'b00100;
  localparam SAVE_TO_COLUMN_SUM = 5'b01000;
  localparam RST = 5'b10000;

  integer i;

  genvar k;
  generate
    for (k = 0; k < MAX_BLOCK_SIZE; k = k + 1) begin
      assign sign_column_sum_memoriesA[k] = sign_column_sum_memories[0][k];
      assign sign_column_sum_memoriesB[k] = sign_column_sum_memories[1][k];
    end
  endgenerate

  // Next state logic
  always @* begin
    case (state)
      IDLE: begin
        if (add) next_state = ADD;
        else if (change_memory) next_state = NEW_ITERATION;
        else next_state = IDLE;
      end
      NEW_ITERATION: begin
        next_state = IDLE;
      end
      ADD: begin
        next_state = SAVE_TO_COLUMN_SUM;
      end
      SAVE_TO_COLUMN_SUM: begin
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
      state <= RST;  // Reset state
    end else begin
      state <= next_state;  // Update state
    end
  end

  // Receive new 
  always @(posedge clk) begin
    if (add) begin
      last_index <= index;
      sign_llr <= sign_llr_in;
      llr <= {2'b00, llr_in};
    end else begin
      last_index <= last_index;
      sign_llr <= sign_llr;
      llr <= llr;
    end
  end

  // Add new llr
  always @(posedge clk) begin
    if (add) begin
      temp_sign <= sign_column_sum_memories[choose_memory][index];
      temp <= {1'b0, column_sum_memories[choose_memory][index]};
    end else if (state == ADD) begin
      if (temp_sign == sign_llr) begin
        temp_sign <= temp_sign;
        temp <= temp + llr;
      end else if (temp > llr) begin
        temp_sign <= temp_sign;
        temp <= temp - llr;
      end else begin
        temp_sign <= sign_llr;
        temp <= llr - temp;
      end
    end else begin
      temp_sign <= temp_sign;
      temp <= temp;
    end
  end

  always @(posedge clk) begin
    case (state)
      RST: begin
        for (i = 0; i < MAX_BLOCK_SIZE; i = i + 1) begin
          column_sum_memories[0][i] <= 
                        {INITIAL_LLR, {(WIDTH_LLR - 5) {1'b0}}};
          sign_column_sum_memories[0][i] <= received_data_in[i];
          column_sum_memories[1][i] <= 
                        {INITIAL_LLR, {(WIDTH_LLR - 5) {1'b0}}};
          sign_column_sum_memories[1][i] <= received_data_in[i];
        end
      end
      SAVE_TO_COLUMN_SUM: begin
        if (last_index != (1 << WIDTH_BLOCK) - 1) begin
          if (temp[WIDTH_LLR+1] == 1'b1) begin
            column_sum_memories[choose_memory][last_index] <= 
                                              {(WIDTH_LLR + 1) {1'b1}};
          end else column_sum_memories[choose_memory][last_index] <= 
                                                      temp[WIDTH_LLR:0];

          if (temp == 0) begin 
            sign_column_sum_memories[choose_memory][last_index] <= 0; 
          end else begin 
            sign_column_sum_memories[choose_memory][last_index] <= 
                                                            temp_sign; 
          end
        end
      end
      NEW_ITERATION: begin
        for (i = 0; i < MAX_BLOCK_SIZE; i = i + 1) begin
          sign_column_sum_memories[!choose_memory][i] <= 
                                                  received_data_in[i];
          column_sum_memories[!choose_memory][i] <= 
                              {INITIAL_LLR, {(WIDTH_LLR - 5) {1'b0}}};
        end
      end
      default: begin
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      choose_memory <= 1'b0;
    end else if (state == NEW_ITERATION) begin
      choose_memory <= ~choose_memory;
    end else begin
      choose_memory <= choose_memory;
    end
  end

  assign llr_out = 
    (&index) ? 
    (1 << (WIDTH_LLR+1)) - 1 : 
    column_sum_memories[!choose_memory][index];
  assign sign_llr_out = 
    (&index) ? 
    1'b0 : 
    sign_column_sum_memories[!choose_memory][index];
  assign ready = (state == IDLE);
  assign hard_decision = 
    choose_memory ? 
    sign_column_sum_memoriesB : 
    sign_column_sum_memoriesA;

endmodule
