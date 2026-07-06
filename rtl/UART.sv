`timescale 1ns / 1ps

module apb_uart_slave (
    // 1. APB 버스 인터페이스
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        pwrite,
    input  logic        psel,
    input  logic        penable,

    // 2. APB 응답 인터페이스
    output logic [31:0] prdata,
    output logic        pready,

    // 3. 외부 물리적 핀 (UART TX, RX)
    input  logic        i_uart_rx,
    output logic        o_uart_tx
);

    // --- [1] 레지스터 주소 매핑 (3개의 독립된 공간) ---
    localparam [11:0] UART_TX_ADDR   = 12'h000; // 쓰기 전용: 보낼 데이터 넣기
    localparam [11:0] UART_RX_ADDR   = 12'h004; // 읽기 전용: 받은 데이터 빼기
    localparam [11:0] UART_STAT_ADDR = 12'h008; // 읽기 전용: FIFO 상태 확인

    // 내부 상태 연결용 wire
    logic [7:0] w_rx_data;
    logic       w_rx_empty;
    logic       w_tx_full;
    
    // 제어 신호 펄스(Pulse) 생성용 wire
    logic       w_tx_push;
    logic       w_rx_pop;

    // Zero-wait-state 표준 (통신 즉시 응답)
    assign pready = 1'b1;

    // --- [2] 제어 신호 동기화 로직 (매우 중요) ---
    // APB 버스의 통신 확정 단계(psel && penable)에서만 딱 1클럭 동안 FIFO 동작 신호를 줍니다.
    
    // CPU가 TX_ADDR에 '쓰기(pwrite)'를 할 때 1클럭 동안 Push
    assign w_tx_push = (psel && penable &&  pwrite && (paddr[11:0] == UART_TX_ADDR));
    
    // CPU가 RX_ADDR에서 '읽기(!pwrite)'를 할 때 1클럭 동안 Pop
    assign w_rx_pop  = (psel && penable && !pwrite && (paddr[11:0] == UART_RX_ADDR));

    // --- [3] 읽기(Read) 및 상태 모니터링 로직 ---
    always_comb begin
        prdata = 32'h0000_0000; 

        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                UART_RX_ADDR: begin
                    // 수신된 데이터를 버스에 올립니다. (w_rx_pop이 동시에 켜져서 다음 클럭에 FIFO가 넘어감)
                    prdata = {24'h000000, w_rx_data}; 
                end
                UART_STAT_ADDR: begin
                    // 소프트웨어 프로그래머를 위한 상태 정보 제공
                    // 비트 [1] = TX Full, 비트 [0] = RX Empty
                    prdata = {30'h00000000, w_tx_full, w_rx_empty};
                end
                // TX_ADDR는 쓰기 전용이므로 읽으려 시도하면 0을 반환합니다.
            endcase
        end
    end

    // *참고: UART 모듈의 쓰기(Write) 데이터(pwdata)는 별도의 always_ff 레지스터에 
    // 저장할 필요 없이, 곧바로 은수님의 FIFO 모듈(i_tx_data)로 직행하도록 설계합니다.

    // --- [4] 은수님의 UART Top 모듈 인스턴스화 ---
    uart_top U_UART_TOP (
        .clk        (pclk),
        .reset      (~presetn),       // APB의 Active-Low를 Active-High로 뒤집어줌
        .uart_rx    (i_uart_rx),
        .uart_tx    (o_uart_tx),
        
        // TX 방향 (CPU -> UART)
        .i_tx_data  (pwdata[7:0]),    // CPU가 버스에 올린 데이터가 FIFO 입구에 대기
        .i_tx_push  (w_tx_push),      // 쓰기 명령이 떨어지면 FIFO 안으로 Push!
        .o_tx_full  (w_tx_full),      
        
        // RX 방향 (UART -> CPU)
        .o_rx_data  (w_rx_data),      // FIFO 맨 앞에 있는 데이터
        .o_rx_empty (w_rx_empty),     
        .i_rx_pop   (w_rx_pop)        // 읽기 명령이 떨어지면 FIFO에서 Pop!
    );

endmodule