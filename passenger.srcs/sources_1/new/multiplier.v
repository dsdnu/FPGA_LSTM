`timescale 1ns / 1ps

module multiplier #(parameter integer DATA_WIDTH = 32)
(
    input clock,
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] c
);
    reg [2*DATA_WIDTH-3:0] total; //[61:0], length = 62
    
    always @(posedge clock) begin
        c[DATA_WIDTH-1] <= (a[DATA_WIDTH-1] != b[DATA_WIDTH-1]);    //[31] bit is for sign
        total <= a[DATA_WIDTH-2:0] * b[DATA_WIDTH-2:0]; //62 bits [2 bits for integer, 60 frac] = 31 bits [1 int, 30 frac] * 31 bits [1 int, 30 frac]
    end
    
    always @(*) begin
        if(total[2*DATA_WIDTH-3]) //overflow: number of bits for integer became 2, i.e. [61] bit is set
            c[DATA_WIDTH-2:0] <= ~0;
        else
            c[DATA_WIDTH-2:0] <= total[2*DATA_WIDTH-4:DATA_WIDTH-2];    //[30:0] = [60:30], length = 31
    end
    
endmodule
