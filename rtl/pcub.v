`timescale 1ns / 1ps  // Define time unit and precision

module pcub #(
    parameter MAX_COLS  = 8,  // Maximum number of columns (inputs)
    parameter WIDTH_LLR = 6   // Bit width for LLR values
) (
    input wire clk,  // Clock signal
    input wire rst_n,  // Asynchronous reset (active low)
    input wire start,  // Start signal for the PCUB computation
    input wire [MAX_COLS*WIDTH_LLR-1:0] llr_in,  // Input LLR values
    input wire [MAX_COLS-1:0] sign_in,  // Input signs (1 => -1, 0 => 1)
    output reg [MAX_COLS*WIDTH_LLR-1:0] llr_out,  // Output LLR values
    output reg [MAX_COLS-1:0] sign_out,  // Output signs (1 => -1, 0 => 1)
    output wire done  // Done signal, indicates completion of computation
);
  // State and next state registers for the state machine
  reg [5:0] state, next_state;

  wire [MAX_COLS*WIDTH_LLR-1:0] psi_out;  // Output of the psi function
  wire [WIDTH_LLR+$clog2(MAX_COLS)-1:0] sum;  // Sum of LLR values
  wire sign_parity;  // Parity of the output signs (1 => odd, 0 => even)

  reg adder_tree_start;  // Start signal for the adder tree
  wire adder_tree_done;  // Done signal from the adder tree

  genvar i;  // Generate variable for the loop
  integer j;  // Integer for the loop

  // Instantiate psi modules for each input LLR
  for (i = 0; i < MAX_COLS; i = i + 1) begin
    psi #(
        .WIDTH(WIDTH_LLR)  // Pass the LLR width to the psi module
    ) psi_lut (
        .psi_in (llr_out[i*WIDTH_LLR+WIDTH_LLR-1:i*WIDTH_LLR]),
        .psi_out(psi_out[i*WIDTH_LLR+WIDTH_LLR-1:i*WIDTH_LLR])
    );
  end

  // Instantiate the augmented adder tree
  augmented_adder_tree #(
      .WIDTH     (WIDTH_LLR),  // Pass the LLR width to the adder tree
      .INPUTS_NUM(MAX_COLS)    // Pass the number of inputs to the adder tree
  ) adder_tree (
      .clk       (clk),               // Connect clock signal
      .rst_n     (rst_n),             // Connect reset signal
      .start     (adder_tree_start),  // Connect start signal
      .input_data(llr_out),           // Connect input LLR values
      .sum       (sum),               // Connect sum output
      .done      (adder_tree_done)    // Connect done signal
  );

  // State machine encoding
  localparam IDLE = 6'b000001;  // Idle state
  localparam PSI_IN = 6'b000010;  // Calculate psi(LLR)
  localparam ADD = 6'b000100;  // Add LLR values using adder tree
  localparam SUB = 6'b001000;  // Subtract LLR from sum
  localparam PSI_OUT = 6'b010000;  // Calculate psi(LLR) again
  localparam RETURN = 6'b100000;  // Return state

  // Next state logic
  always @* begin  // Combinational logic for next state
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PSI_IN;  // Transition to PSI_IN state
        end else begin
          next_state = IDLE;  // Remain in IDLE state otherwise
        end
      end
      PSI_IN: begin
        next_state = ADD;  // Transition to ADD state
      end
      ADD: begin
        if (adder_tree_done) begin
          next_state = SUB;  // Transition to SUB state
        end else begin
          next_state = ADD;  // Remain in ADD state otherwise
        end
      end
      SUB: begin
        next_state = PSI_OUT;  // Transition to PSI_OUT state
      end
      PSI_OUT: begin
        next_state = RETURN;  // Transition to RETURN state
      end
      RETURN: begin
        next_state = IDLE;  // Transition to IDLE state
      end
      default: begin
        next_state = IDLE;  // Default to IDLE state
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

  // LLR update logic
  always @(posedge clk) begin
    if (start) begin
      llr_out <= llr_in;  // Initialize LLR with input values
    end else if (state == PSI_IN | state == PSI_OUT) begin
      llr_out <= psi_out;  // Update LLR with psi output
    end else if (state == SUB) begin
      for (j = 0; j < MAX_COLS; j = j + 1) begin
        // Subtract LLR from sum, saturate to maximum value if needed
        if ((sum - {{$clog2(
                MAX_COLS
            ) {1'b0}}, llr_out[j*WIDTH_LLR+:WIDTH_LLR]}) >
                                      (1 << WIDTH_LLR) - 1) begin
          llr_out[j*WIDTH_LLR+:WIDTH_LLR] <= (1 << WIDTH_LLR) - 1;
        end else begin
          llr_out[j*WIDTH_LLR+:WIDTH_LLR] <=
              (sum - {{$clog2(MAX_COLS) {1'b0}}, 
                                llr_out[j*WIDTH_LLR+:WIDTH_LLR]});
        end
      end
    end
  end

  // Sign update logic
  always @(posedge clk) begin
    if (start) begin
      sign_out <= sign_in;  // Initialize sign with input values
    end else if (state == PSI_OUT & sign_parity) begin
      sign_out <= ~sign_out;  // Invert signs if parity is odd
    end else begin
      sign_out <= sign_out;  // Keep signs unchanged otherwise
    end
  end

  // Adder tree control logic
  always @(posedge clk) begin
    if (state == PSI_IN) begin
      adder_tree_start <= 1'b1;  // Start adder tree calculation
    end else begin
      adder_tree_start <= 1'b0;  // Stop adder tree calculation
    end
  end

  assign done        = (state == RETURN);  // Assert done signal
  assign sign_parity = {^sign_out};  // Calculate parity of the output signs

endmodule
