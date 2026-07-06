`timescale 1ns / 1ps

module GPIO (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        pwrite,
    input  logic        psel,
    input  logic        penable,

    output logic [31:0] prdata,
    output logic        pready,

    input logic [15:0] i_gpio,
    output logic [15:0] o_gpio,
    output logic [15:0] o_gpio_oe
);

    // --- [1] 레지스터 주소 매핑 (3개의 레지스터 필요) ---
    localparam [11:0] GPIO_DIR_ADDR  = 12'h000; // 방향 설정 (1: 출력, 0: 입력)
    localparam [11:0] GPIO_OUT_ADDR  = 12'h004; // 출력할 데이터
    localparam [11:0] GPIO_IN_ADDR   = 12'h008; // 입력된 데이터 (읽기 전용)

    // 내부 레지스터 선언
    logic [15:0] gpio_dir_reg;
    logic [15:0] gpio_out_reg;
    
    // 외부 신호 동기화를 위한 2단 레지스터 (메타스테빌리티 방지)
    logic [15:0] sync1_reg;
    logic [15:0] sync2_reg;

    // 대기 시간이 없는 슬레이브의 APB 표준 (항상 준비 완료)
    assign pready = 1'b1;

    // --- [2] 안전한 읽기(Read-back 및 입력 확인) 로직 ---
    always_comb begin
        prdata = 32'h0000_0000; // 물리적 X값 전파 방지

        // 읽기 요청(!pwrite)이고 통신 확정(psel && penable)일 때
        if (psel && !pwrite) begin
            case (paddr[11:0])
                GPIO_DIR_ADDR: prdata = {16'h0000, gpio_dir_reg};
                GPIO_OUT_ADDR: prdata = {16'h0000, gpio_out_reg};
                GPIO_IN_ADDR:  prdata = {16'h0000, sync2_reg}; // 동기화된 핀의 현재 상태 읽기
            endcase
        end
    end

    // --- [3] 쓰기(Write) 및 동기화 로직 ---
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            // 리셋 시 가장 안전한 상태인 '입력(0)' 모드로 초기화합니다.
            gpio_dir_reg <= 16'h0000; 
            gpio_out_reg <= 16'h0000;
            sync1_reg    <= 16'h0000;
            sync2_reg    <= 16'h0000;
        end else begin
            // [입력 처리] 방향(DIR)에 상관없이 핀의 물리적 상태는 매 클럭 동기화하여 읽어들입니다.
            sync1_reg <= i_gpio;
            sync2_reg <= sync1_reg;

            // [출력 처리] CPU가 레지스터에 값을 쓰는 동작
            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    GPIO_DIR_ADDR: gpio_dir_reg <= pwdata[15:0];
                    GPIO_OUT_ADDR: gpio_out_reg <= pwdata[15:0];
                    // GPIO_IN_ADDR는 읽기 전용이므로 쓰기 로직이 없습니다.
                endcase
            end
        end
    end

    assign o_gpio = gpio_out_reg;
    assign o_gpio_oe = gpio_dir_reg;

endmodule
