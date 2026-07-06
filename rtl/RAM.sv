`timescale 1ns / 1ps

module RAM (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        pwrite,
    input  logic        penable,
    input  logic        psel0,
    input  logic [ 3:0] pstrb,    // funct3 역할 
    output logic [31:0] prdata0,
    output logic        pready0
);
    logic [3:0] ram_byte_we;  // 4비트 바이트 스위치 선언

    // [수정: 통역의 핵심] 쓰기가 유효할 때만 pstrb를 RAM으로 전달
    always_comb begin
        if (psel0 && penable && pwrite) begin
            ram_byte_we = pstrb;
        end else begin
            ram_byte_we = 4'b0000;
        end
    end

    assign pready0 = 1'b1;  // psel0 && penable;

    data_mem U_DATA_MEM (
        .clk(pclk),
        .byte_we(ram_byte_we),  // [수정: dwe 대신 4비트 스위치 연결]
        .daddr(paddr),
        .dwdata(pwdata),
        .drdata(prdata0)
    );
endmodule

module data_mem (
    input  logic        clk,
    input  logic [ 3:0] byte_we,
    input  logic [31:0] daddr,
    input  logic [31:0] dwdata,
    output logic [31:0] drdata
);
    logic [31:0] dmem[0:1023];

    initial begin
        for (int i = 0; i < 1024; i++) begin
            dmem[i] = 32'h0;
        end
    end

    always_ff @(posedge clk) begin
        if (byte_we[0]) dmem[daddr[11:2]][7:0] <= dwdata[7:0];
        if (byte_we[1]) dmem[daddr[11:2]][15:8] <= dwdata[15:8];
        if (byte_we[2]) dmem[daddr[11:2]][23:16] <= dwdata[23:16];
        if (byte_we[3]) dmem[daddr[11:2]][31:24] <= dwdata[31:24];

        drdata <= dmem[daddr[11:2]];
    end

endmodule


module counter_4bit (
    input wire clk,
    input wire rst_n,
    input wire enable,
    output reg [3:0] cnt
);

    // 동기식 리셋이므로 sensitivity list에는 clk만 존재
    always @(posedge clk) begin
        if (!rst_n) begin  // 1순위: 동기식 Active-low 리셋
            cnt <= 4'b0000;
        end else begin
            if (enable) begin  // 2순위: Enable이 1일 때만 동작
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule
