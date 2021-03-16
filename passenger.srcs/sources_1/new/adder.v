`timescale 1ns / 1ps

module adder #(parameter integer DATA_WIDTH = 32)
(
    input clock,
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] c
);
    reg [DATA_WIDTH-1:0] total;
        
    always @(*) begin
        total <= a[DATA_WIDTH-2:0] + b[DATA_WIDTH-2:0];
    end
    
    always @(posedge clock) begin
        if(a[DATA_WIDTH-1] == b[DATA_WIDTH-1]) begin
            c[DATA_WIDTH-1] <= a[DATA_WIDTH-1];
            if(total[DATA_WIDTH-1])
                c[DATA_WIDTH-2:0] <= ~0;
            else
                c[DATA_WIDTH-2:0] <= total[DATA_WIDTH-2:0];
        end else if(a[DATA_WIDTH-2:0] > b[DATA_WIDTH-2:0]) begin
            c[DATA_WIDTH-1] <= a[DATA_WIDTH-1];
            c[DATA_WIDTH-2:0] <= a[DATA_WIDTH-2:0] - b[DATA_WIDTH-2:0];
        end else begin
            c[DATA_WIDTH-1] <= b[DATA_WIDTH-1];
            c[DATA_WIDTH-2:0] <= b[DATA_WIDTH-2:0] - a[DATA_WIDTH-2:0];
        end
    end
    
endmodule