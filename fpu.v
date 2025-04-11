`timescale 1ns / 1ps
`default_nettype none

module fpu(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [2:0]  opcode,
    input  wire        i_fpu_valid,
    output reg         o_fpu_ready,
    output reg  [31:0] O
);

    // Operation codes
    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_MUL = 3'b011;
    localparam OP_DIV = 3'b100;

    // Internal signals
    wire        a_sign;
    wire [7:0]  a_exponent;
    wire [23:0] a_mantissa;
    wire        b_sign;
    wire [7:0]  b_exponent;
    wire [23:0] b_mantissa;

    // Functional unit inputs
    reg  [31:0] adder_a_in;
    reg  [31:0] adder_b_in;
    wire [31:0] adder_out;

    reg  [31:0] multiplier_a_in;
    reg  [31:0] multiplier_b_in;
    wire [31:0] multiplier_out;

    reg  [31:0] divider_a_in;
    reg  [31:0] divider_b_in;
    wire [31:0] divider_out;

    // Input decomposition
    assign a_sign = A[31];
    assign a_exponent = A[30:23];
    assign a_mantissa = (a_exponent == 0) ? {1'b0, A[22:0]} : {1'b1, A[22:0]};

    assign b_sign = B[31];
    assign b_exponent = B[30:23];
    assign b_mantissa = (b_exponent == 0) ? {1'b0, B[22:0]} : {1'b1, B[22:0]};

    // Instantiate functional units
    adder fpu_adder (
        .a(adder_a_in),
        .b(adder_b_in),
        .out(adder_out)
    );

    multiplier fpu_multiplier (
        .a(multiplier_a_in),
        .b(multiplier_b_in),
        .out(multiplier_out)
    );

    divider fpu_divider (
        .a(divider_a_in),
        .b(divider_b_in),
        .out(divider_out)
    );

    // Main processing pipeline
    reg [2:0] pipeline_stage;
    reg [2:0] operation_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all outputs and pipeline
            O <= 32'b0;
            o_fpu_ready <= 1'b0;
            pipeline_stage <= 3'b0;
            operation_reg <= 3'b0;
        end
        else begin
            // Default ready signal
            o_fpu_ready <= 1'b0;

            if (i_fpu_valid) begin
                case (opcode)
                    OP_ADD: begin // ADD
                        // Corner cases
                        if ((a_exponent == 255 && a_mantissa != 0) || 
                            (b_exponent == 0 && b_mantissa == 0)) begin
                            // NaN or b is zero - return a
                            O <= A;
                            o_fpu_ready <= 1'b1;
                        end
                        else if ((b_exponent == 255 && b_mantissa != 0) || 
                                (a_exponent == 0 && a_mantissa == 0)) begin
                            // NaN or a is zero - return b
                            O <= B;
                            o_fpu_ready <= 1'b1;
                        end
                        else if (a_exponent == 255 || b_exponent == 255) begin
                            // Infinity cases
                            O <= {a_sign ^ b_sign, 8'hFF, 23'h0};
                            o_fpu_ready <= 1'b1;
                        end
                        else begin
                            // Normal addition
                            adder_a_in <= A;
                            adder_b_in <= B;
                            pipeline_stage <= 3'b001;
                            operation_reg <= OP_ADD;
                        end
                    end

                    OP_SUB: begin // SUB
                        // Similar to ADD but flip sign of B
                        if ((a_exponent == 255 && a_mantissa != 0) || 
                            (b_exponent == 0 && b_mantissa == 0)) begin
                            O <= A;
                            o_fpu_ready <= 1'b1;
                        end
                        else if ((b_exponent == 255 && b_mantissa != 0) || 
                                (a_exponent == 0 && a_mantissa == 0)) begin
                            O <= B;
                            o_fpu_ready <= 1'b1;
                        end
                        else if (a_exponent == 255 || b_exponent == 255) begin
                            O <= {a_sign ^ b_sign, 8'hFF, 23'h0};
                            o_fpu_ready <= 1'b1;
                        end
                        else begin
                            adder_a_in <= A;
                            adder_b_in <= {~B[31], B[30:0]}; // Flip sign for subtraction
                            pipeline_stage <= 3'b001;
                            operation_reg <= OP_SUB;
                        end
                    end

                    OP_MUL: begin // MUL
                        // Multiplication corner cases
                        if (a_exponent == 255 && a_mantissa != 0) begin
                            // a is NaN
                            O <= {a_sign, 8'hFF, a_mantissa[22:0]};
                            o_fpu_ready <= 1'b1;
                        end
                        else if (b_exponent == 255 && b_mantissa != 0) begin
                            // b is NaN
                            O <= {b_sign, 8'hFF, b_mantissa[22:0]};
                            o_fpu_ready <= 1'b1;
                        end
                        else if ((a_exponent == 0 && a_mantissa == 0) || 
                                (b_exponent == 0 && b_mantissa == 0)) begin
                            // Multiply by zero
                            O <= {a_sign ^ b_sign, 31'b0};
                            o_fpu_ready <= 1'b1;
                        end
                        else if (a_exponent == 255 || b_exponent == 255) begin
                            // Infinity cases
                            O <= {a_sign ^ b_sign, 8'hFF, 23'h0};
                            o_fpu_ready <= 1'b1;
                        end
                        else begin
                            // Normal multiplication
                            multiplier_a_in <= A;
                            multiplier_b_in <= B;
                            pipeline_stage <= 3'b010;
                            operation_reg <= OP_MUL;
                        end
                    end

                    OP_DIV: begin // DIV
                        // Division corner cases
                        if ((a_exponent == 255 && a_mantissa != 0) || 
                            (b_exponent == 255 && b_mantissa != 0)) begin
                            // NaN in numerator or denominator
                            O <= {a_sign ^ b_sign, 8'hFF, a_mantissa[22:0] | b_mantissa[22:0]};
                            o_fpu_ready <= 1'b1;
                        end
                        else if (a_exponent == 0 && a_mantissa == 0) begin
                            // Division of zero
                            if (b_exponent == 0 && b_mantissa == 0) begin
                                // 0/0 = NaN
                                O <= {1'b0, 8'hFF, 23'h1};
                            end else begin
                                // 0/x = 0
                                O <= {a_sign ^ b_sign, 31'b0};
                            end
                            o_fpu_ready <= 1'b1;
                        end
                        else if (b_exponent == 0 && b_mantissa == 0) begin
                            // Division by zero
                            O <= {a_sign ^ b_sign, 8'hFF, 23'h0}; // Infinity
                            o_fpu_ready <= 1'b1;
                        end
                        else if (a_exponent == 255) begin
                            // Infinity divided by something
                            O <= {a_sign ^ b_sign, 8'hFF, 23'h0};
                            o_fpu_ready <= 1'b1;
                        end
                        else if (b_exponent == 255) begin
                            // Something divided by infinity
                            O <= {a_sign ^ b_sign, 31'b0};
                            o_fpu_ready <= 1'b1;
                        end
                        else begin
                            // Normal division
                            divider_a_in <= A;
                            divider_b_in <= B;
                            pipeline_stage <= 3'b100; // Division takes more cycles
                            operation_reg <= OP_DIV;
                        end
                    end

                    default: begin
                        // Invalid opcode
                        O <= 32'hFFFFFFFF;
                        o_fpu_ready <= 1'b1;
                    end
                endcase
            end
            else if (pipeline_stage != 0) begin
                // Pipeline advance
                pipeline_stage <= pipeline_stage - 1;
                
                if (pipeline_stage == 1) begin
                    // Operation complete
                    case (operation_reg)
                        OP_ADD, OP_SUB: O <= adder_out;
                        OP_MUL: O <= multiplier_out;
                        OP_DIV: O <= divider_out;
                    endcase
                    o_fpu_ready <= 1'b1;
                end
            end
        end
    end

endmodule



