`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        reset,
    input        uart_rx,
    output       uart_tx,
    
    // TX Interface (Sender가 데이터를 넣는 곳)
    input  [7:0] i_tx_data,
    input        i_tx_push,     // Sender의 o_tx_start와 연결
    output       o_tx_full,     // Sender의 i_tx_busy와 연결
    
    // RX Interface (Decoder가 데이터를 가져가는 곳)
    output [7:0] o_rx_data,     // FIFO에서 나온 데이터
    output       o_rx_empty,    // FIFO 상태
    input        i_rx_pop       // Decoder의 o_rx_fifo_pop과 연결
);

    // 내부 신호
    wire w_b_tick;
    wire [7:0] w_rx_raw_data;
    wire       w_rx_raw_done;
    
    wire [7:0] w_tx_fifo_out;
    wire       w_tx_fifo_empty;
    wire       w_tx_pop_sig;

    // 1. Baud Rate Generator
    baud_tick U_BAUD_TICK (
        .clk(clk),
        .reset(reset),
        .b_tick(w_b_tick)
    );

    // 2. UART RX (Raw 데이터 수신)
    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_raw_data),
        .rx_done(w_rx_raw_done)
    );

    // 3. RX FIFO (수신된 데이터를 보관)
    fifo #(.DEPTH(16), .BIT_WIDTH(8)) U_RX_FIFO (
        .clk(clk),
        .rst(reset),
        .push(w_rx_raw_done),    // RX 완료 시 push
        .pop(i_rx_pop),          // Decoder가 pop
        .push_data(w_rx_raw_data),
        .pop_data(o_rx_data),
        .full(),
        .empty(o_rx_empty)
    );

    // 4. TX FIFO (보낼 데이터를 보관)
    fifo #(.DEPTH(16), .BIT_WIDTH(8)) U_TX_FIFO (
        .clk(clk),
        .rst(reset),
        .push(i_tx_push),        // Sender가 push
        .pop(w_tx_pop_sig),      // TX 모듈이 pop
        .push_data(i_tx_data),
        .pop_data(w_tx_fifo_out),
        .full(o_tx_full),
        .empty(w_tx_fifo_empty)
    );

    // 5. UART TX (FIFO에서 데이터를 꺼내 전송)
    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .b_tick(w_b_tick),
        .i_tx_fifo_empty(w_tx_fifo_empty),
        .i_tx_fifo_data(w_tx_fifo_out),
        .o_tx_fifo_pop(w_tx_pop_sig),
        .tx_busy(),              // 내부 FIFO가 관리하므로 외부 연결 불필요
        .tx_done(),
        .uart_tx(uart_tx)
    );

endmodule

module uart_rx (
    input        clk,
    input        reset,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg [1:0] current_state, next_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_next, bit_cnt_reg;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state  <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            current_state  <= next_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    // next, output
    always @(*) begin
        next_state      = current_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;
        case (current_state)
            IDLE: begin
                done_next       = 1'b0;
                b_tick_cnt_next = 5'd0;
                bit_cnt_next    = 3'd0;
                if (b_tick & !rx) begin
                    buf_next   = 8'd0;
                    next_state = START;
                end
            end
            START: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        next_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            next_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 15) begin
                        next_state = IDLE;
                        done_next  = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
        endcase
    end

endmodule

module uart_tx (
    input        clk,
    input        reset,
    input        b_tick,
    input        i_tx_fifo_empty, // TX FIFO 상태 확인
    input  [7:0] i_tx_fifo_data,  // FIFO에서 나온 데이터
    output reg   o_tx_fifo_pop,   // FIFO에서 데이터를 빼오는 신호
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);

    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    // state reg
    reg [1:0] current_state, next_state;
    reg tx_reg, tx_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    
    // baud tick counter
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    
    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    
    // data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // --- FIFO Pop 로직 ---
    // 송신기가 IDLE 상태이고 FIFO에 데이터가 있을 때 1클럭 동안 Pop 신호를 발생시킵니다.
    always @(posedge clk or posedge reset) begin
        if (reset) o_tx_fifo_pop <= 1'b0;
        else       o_tx_fifo_pop <= (!i_tx_fifo_empty && (current_state == IDLE) && !o_tx_fifo_pop);
    end

    // state register (Sequential Logic)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state   <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 3'd0;
            b_tick_cnt_reg  <= 4'h0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            current_state   <= next_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // Next State & Output Logic (Combinational Logic)
    always @(*) begin
        next_state       = current_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = 1'b0; // done 신호는 한 클럭만 발생하도록 기본값 0 설정
        data_in_buf_next = data_in_buf_reg;

        case (current_state)
            IDLE: begin
                tx_next         = 1'b1;
                bit_cnt_next    = 3'd0;
                b_tick_cnt_next = 4'h0;
                busy_next       = 1'b0;
                
                // 기존 tx_start 대신 o_tx_fifo_pop이 발생했을 때 시작하도록 수정
                if (o_tx_fifo_pop) begin
                    next_state       = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = i_tx_fifo_data; // FIFO에서 나온 데이터를 버퍼에 저장
                end
            end

            START: begin
                tx_next = 1'b0; // Start Bit
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        next_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 4'h0;
                        if (bit_cnt_reg == 7) begin
                            next_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1; // Stop Bit
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next  = 1'b1;
                        next_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule

`timescale 1ns / 1ps
module fifo #(
    parameter DEPTH = 8,
    parameter BIT_WIDTH = 8
) (
    input                           clk,
    input                           rst,
    input                           push,
    input                           pop,
    input      [BIT_WIDTH-1:0]      push_data,
    output     [BIT_WIDTH-1:0]      pop_data,
    output                          full,
    output                          empty
);
    
    wire [$clog2(DEPTH)-1:0] wptr;
    wire [$clog2(DEPTH)-1:0] rptr;
    wire                     we;
    
    assign we = (~full) & push;

    register_file_fifo #(.DEPTH(DEPTH), .BIT_WIDTH(BIT_WIDTH))
        U_REG_FI (
                    .clk(clk),
                    .r_addr(rptr),
                    .w_addr(wptr),
                    .we(we),
                    .push_data(push_data),
                    .pop_data(pop_data)
    );

    fifo_control_unit #(.DEPTH(DEPTH)) 
        U_CTRL_UNIT(
            .clk    (clk),
            .rst    (rst),
            .push   (push),
            .pop    (pop),
            .wptr   (wptr),
            .rptr   (rptr),
            .full   (full),
            .empty  (empty)
    );

endmodule

module register_file_fifo #(
    parameter DEPTH = 4,
    parameter BIT_WIDTH = 8
) (
    input                           clk,
    input      [$clog2(DEPTH)-1:0]  r_addr,
    input      [$clog2(DEPTH)-1:0]  w_addr,
    input                           we,
    input      [BIT_WIDTH-1:0]      push_data,
    output     [BIT_WIDTH-1:0]      pop_data
);
    reg [BIT_WIDTH-1:0] register_file [0:DEPTH-1];

    // push (write) => Register file
    always @(posedge clk) begin
        if (we) register_file[w_addr] <= push_data; // push
        //else pop_data <= register_file[r_addr];
    end

    // read
    assign pop_data = register_file[r_addr];

endmodule

module fifo_control_unit #(
    parameter DEPTH = 4
) (
    input                           clk,
    input                           rst,
    input                           push,
    input                           pop,
    output     [$clog2(DEPTH)-1:0]  wptr,
    output     [$clog2(DEPTH)-1:0]  rptr,
    output                          full,
    output                          empty
);  
    reg [1:0] c_state, n_state;

    // pointer registers
    reg [$clog2(DEPTH)-1:0] wptr_reg, wptr_next;
    reg [$clog2(DEPTH)-1:0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;
    assign wptr = wptr_reg;
    assign rptr = rptr_reg;
    assign full = full_reg;
    assign empty = empty_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= 2'b00;
            
            wptr_reg <= 0;
            rptr_reg <= 0;
            full_reg <= 0;
            empty_reg <= 1;
        end
        else begin
            c_state <= n_state;

            wptr_reg <= wptr_next;
            rptr_reg <= rptr_next;
            full_reg <= full_next;
            empty_reg <= empty_next;
        end
    end

    // next st, output
    always @(*) begin
        n_state = c_state;
        
        wptr_next = wptr_reg;
        rptr_next = rptr_reg;
        full_next = full_reg;
        empty_next = empty_reg;
        
        case ({push, pop})
            2'b10: begin
                // push only
                if (!full_reg) begin
                    wptr_next = wptr_reg + 1;
                    empty_next = 1'b0;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b01: begin
                // pop only
                if (!empty_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                    if (wptr_reg == rptr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b11: begin
                // push pop at same time
                if (full_reg == 1) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end
                else if (empty_reg == 1) begin
                    wptr_next = wptr_reg + 1;
                    empty_next = 1'b0;
                end
                else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end

endmodule

module baud_tick (
    input      clk,
    input      reset,
    output reg b_tick
);

    parameter BAUDRATE = 9600 * 16;
    parameter F_COUNT = 100_000_000 / BAUDRATE;

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end

endmodule

