`timescale 1ns / 1ps

module GPI (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        pwrite,
    input  logic        psel,
    input  logic        penable,

    output logic [31:0] prdata,
    output logic        pready,

    input  logic [15:0] i_gpi
);

    localparam [11:0] GPI_CTL_ADDR   = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;

    // 제어 레지스터 (자물쇠 역할, CPU가 덮어쓸 수 있음)
    logic [15:0] gpi_ctl_reg;

    // 외부 신호 동기화를 위한 레지스터 (2-Stage Synchronizer)
    // 물리적인 핀에서 들어오는 신호를 내부 클럭에 맞게 정돈합니다.
    logic [15:0] sync1_reg;
    logic [15:0] sync2_reg;

    // 대기 시간이 없는 슬레이브이므로 항상 준비 완료 상태를 보냅니다.
    assign pready = 1'b1;

    // --- [1] 안전한 읽기(Read) 및 입력 마스킹 로직 ---
    always_comb begin
        prdata = 32'h0000_0000; 

        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                GPI_CTL_ADDR: prdata = {16'h0000, gpi_ctl_reg};
                
                GPI_IDATA_ADDR: begin
                    // 교수님 그림의 '안쪽을 향하는 Tri-state 버퍼' 구현
                    // ctl_reg가 1인 비트는 외부 신호(sync2_reg)를 통과시키고,
                    // 0인 비트는 외부 신호를 무시하고 강제로 0을 만듭니다.
                    prdata = {16'h0000, (sync2_reg & gpi_ctl_reg)};
                end
            endcase
        end
    end

    // --- [2] 쓰기(Write) 보호 및 동기화 로직 ---
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpi_ctl_reg <= 16'h0000;
            sync1_reg   <= 16'h0000;
            sync2_reg   <= 16'h0000;
        end else begin
            // 2단 동기화: 매 클럭마다 밖에서 들어오는 신호를 안전하게 캡처합니다.
            sync1_reg <= i_gpi;
            sync2_reg <= sync1_reg;

            // CPU 쓰기 동작: 제어 레지스터(자물쇠)만 값을 변경할 수 있습니다.
            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    GPI_CTL_ADDR: gpi_ctl_reg <= pwdata[15:0];
                    // GPI_IDATA_ADDR는 '입력 전용'이므로 쓰기 로직이 아예 존재하지 않습니다.
                    // 소프트웨어가 실수로 값을 쓰려고 해도 하드웨어가 철저히 무시합니다.
                endcase
            end
        end
    end

endmodule
