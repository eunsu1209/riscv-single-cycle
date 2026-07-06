`timescale 1ns / 1ps

module tb_rv32i ();
    logic clk, rst;

    rv32i_top dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;

        @(negedge clk);
        rst = 0;

        // dut.U_DATA_MEM.dmem[1] = 32'hF1F2F3F4;
        // repeat (20) @(negedge clk);
        #1000;
        $stop;
    end
endmodule
