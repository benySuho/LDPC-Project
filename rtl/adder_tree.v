`timescale 1ns / 1ps 

module augmented_adder_tree #(
    parameter WIDTH = 5,  // Width of the input data
    parameter INPUTS_NUM = 8,  // Number of inputs
    localparam STAGES = $clog2(INPUTS_NUM) // Stages in the adder tree
) (
    input wire clk,  // Clock signal
    input wire rst_n,  // Active low reset signal
    input wire start,  // Start calculation signal
    input wire [INPUTS_NUM*WIDTH-1:0] input_data, // Input data bus
    output wire [WIDTH+STAGES-1:0] sum,  // Output sum
    output wire done  // Done signal
);

  // Internal signals
  reg [2:0] state, next_state; // State registers
  reg [STAGES:0] index; // Index to track the current stage in the adder tree
  reg [WIDTH+STAGES-1:0] temp[(1<<STAGES)-1:0]; // Temporary registers

  // State encoding
  localparam IDLE = 3'b001; // Idle state
  localparam CLC = 3'b010;  // Calculation state
  localparam RETURN = 3'b100; // Return result state

  // Loop counters
  integer i, j; 

  // Calculate next state based on current state and input signals
  always @* begin 
    case (state)
      IDLE: begin
        if (start) begin // Transition to calculation state
          next_state = CLC;
        end else next_state = IDLE; // Remain in idle state otherwise
      end
      CLC: begin
        if (index == STAGES - 1) next_state = RETURN; 
        else next_state = CLC; // Remain in calculation state 
      end
      RETURN: begin
        next_state = IDLE; // Transition back to idle state 
      end
      default: begin
        next_state = IDLE; // Default to idle state for any unknown state
      end
    endcase
  end

  // State register
  always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
      state <= IDLE; // Reset to idle state
    end else begin
      state <= next_state; // Update state with the calculated next state
    end
  end

  // Index counter
  always @(posedge clk) begin
    if (start) index <= 0; // Reset index to 0 when start signal is high
    else if (state == CLC) begin
      index <= index + 1; // Increment index in calculation state
    end
  end

  // Adder tree logic
  always @(posedge clk) begin
    if (start) begin // Initialize temp registers with input data
      for (i = 0; i < INPUTS_NUM; i = i + 1) begin
        temp[i] <= {{STAGES{1'b0}}, input_data[i*WIDTH+:WIDTH]}; // Input
      end
    end else begin
      if (state == CLC) begin // Perform addition in each stage
        for (i = 0; i < ((1 << STAGES) / 2); i = i + 1) begin
          temp[i] <= temp[2*i] + temp[2*i+1]; // Summate temp registers
        end
      end
    end
  end

  // Output assignments
  assign done = (state == RETURN) ? 1'b1 : 1'b0; // Assert done signal
  assign sum  = temp[0]; // Assign the final sum from temp[0] to the output

endmodule