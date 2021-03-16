`timescale 1ns / 1ps

module multipadd #(parameter integer DATA_WIDTH = 32)
(
    input clock,
    input reset,
    input enable,
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    input [DATA_WIDTH-1:0] c,
    output reg [DATA_WIDTH-1:0] out,
    output reg ready,
    output reg valid
);

    reg [DATA_WIDTH-1:0] mult_ina, mult_inb, add_ina, add_inb;
    wire [DATA_WIDTH-1:0] mult_out, add_out;
    multiplier #(DATA_WIDTH) mult(clock, mult_ina, mult_inb, mult_out);
    adder #(DATA_WIDTH) add(clock, add_ina, add_inb, add_out);
    integer counter;
    
    always @(posedge clock) begin
        if(reset) begin
            ready <= 1;
            valid <= 0;
            counter <= 0;
        end else begin
            if(enable) begin
                ready <= 0;
                mult_ina <= a;
                mult_inb <= b;
                add_ina <= c;
                add_inb <= mult_out;
                out <= add_out;
                counter <= counter + 1;
                if(counter == 3)
                    valid <= 1;
            end else begin
                valid <= 0;
                ready <= 1;
                counter <= 0;
            end
        end
    end
    
endmodule
