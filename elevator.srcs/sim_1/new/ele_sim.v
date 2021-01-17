`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/12/15 21:39:30
// Design Name: 
// Module Name: ele_sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ele_sim(

    );
    wire clk1, clk;
    reg sys_clk;
    fdivision(sys_clk, clk1, clk);
    initial begin 
        sys_clk = 0;
        #100 sys_clk = 1;
        #10 sys_clk = 0;
    end
    always #10 sys_clk = ~sys_clk;
endmodule
