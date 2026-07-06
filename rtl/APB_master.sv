`timescale 1ns / 1ps

module APB_MASTER (
    input logic pclk,
    input logic presetn,

    // cpu -> APB master (request)
    input logic [31:0] addr,
    input logic [31:0] wdata,
    input logic        wreq,
    input logic        rreq,
    input logic [ 3:0] wstrb,

    // APB master -> APB bus (to slave)
    output logic [31:0] paddr,
    output logic [31:0] pwdata,
    output logic        penable,
    output logic        pwrite, // read까지 하면 선 낭비 pwrite하나로 하고 psel로 제어
    output logic [ 3:0] pstrb,
    output logic        psel0,
    output logic        psel1,
    output logic        psel2,
    output logic        psel3,
    output logic        psel4,
    output logic        psel5,

    // APB bus -> APB master (from slave)
    input logic        pslverr,
    input logic        pready0,
    input logic        pready1,
    input logic        pready2,
    input logic        pready3,
    input logic        pready4,
    input logic        pready5,
    input logic [31:0] prdata0,
    input logic [31:0] prdata1,
    input logic [31:0] prdata2,
    input logic [31:0] prdata3,
    input logic [31:0] prdata4,
    input logic [31:0] prdata5,

    // APB master -> cpu (response)
    output logic        slverr,
    output logic [31:0] rdata,
    output logic        ready
);

    logic [31:0] paddr_next, pwdata_next;
    logic        pwrite_next;
    logic [ 3:0] pstrb_next;
    logic        decode_en;

    logic        mux_ready;
    logic [31:0] mux_rdata;
    logic        dec_error;

    apb_mux U_APB_MUX (
        .pready0(pready0),
        .pready1(pready1),
        .pready2(pready2),
        .pready3(pready3),
        .pready4(pready4),
        .pready5(pready5),
        .sel(paddr),
        .ready(mux_ready),
        .rdata(mux_rdata),
        .prdata0(prdata0),
        .prdata1(prdata1),
        .prdata2(prdata2),
        .prdata3(prdata3),
        .prdata4(prdata4),
        .prdata5(prdata5)
    );

    addr_decoder U_ADDR_DECODER (
        .en(decode_en),
        .addr(paddr),
        .dec_error(dec_error),
        .psel0(psel0),
        .psel1(psel1),
        .psel2(psel2),
        .psel3(psel3),
        .psel4(psel4),
        .psel5(psel5)
    );

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;
    state_t c_state, n_state;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            c_state <= IDLE;
            paddr   <= 32'b0;
            pwdata  <= 32'b0;
            pwrite  <= 1'b0;
            pstrb   <= 4'b0;
        end else begin
            c_state <= n_state;
            paddr   <= paddr_next;
            pwdata  <= pwdata_next;
            pwrite  <= pwrite_next;
            pstrb   <= pstrb_next;
        end
    end

    always_comb begin
        decode_en   = 1'b0;
        penable     = 1'b0;
        paddr_next  = paddr;
        pwdata_next = pwdata;
        pwrite_next = pwrite;
        pstrb_next  = pstrb;
        n_state     = c_state;

        case (c_state)
            IDLE: begin
                decode_en = 1'b0;
                if (wreq | rreq) begin
                    paddr_next  = addr;
                    pwdata_next = wdata;
                    pwrite_next = wreq;
                    pstrb_next  = wstrb;
                    n_state     = SETUP;
                end
            end

            SETUP: begin
                decode_en = 1'b1;
                penable   = 1'b0;

                if (dec_error) n_state = IDLE;
                else n_state = ACCESS;
            end

            ACCESS: begin
                decode_en = 1'b1;
                penable   = 1'b1;

                if (mux_ready) begin
                    if (wreq | rreq) begin
                        paddr_next  = addr;
                        pwdata_next = wdata;
                        pwrite_next = wreq;
                        pstrb_next  = wstrb;
                        n_state     = SETUP;
                    end else begin
                        n_state = IDLE;
                    end
                end
            end

            default: n_state = IDLE;
        endcase
    end

    assign ready  = (c_state == ACCESS && mux_ready) || (c_state == SETUP && dec_error);
    assign rdata = mux_rdata;
    assign slverr = pslverr || (c_state == SETUP && dec_error);

endmodule


module addr_decoder (
    input  logic        en,
    input  logic [31:0] addr,
    output logic        dec_error,
    output logic        psel0,
    output logic        psel1,
    output logic        psel2,
    output logic        psel3,
    output logic        psel4,
    output logic        psel5
);

    always_comb begin
        psel0 = 1'b0;
        psel1 = 1'b0;
        psel2 = 1'b0;
        psel3 = 1'b0;
        psel4 = 1'b0;
        psel5 = 1'b0;
        dec_error = 1'b0;

        if (en) begin
            case (addr[31:28])
                4'h1: psel0 = 1'b1;
                4'h2: begin
                    case (addr[15:12])
                        4'h0: psel1 = 1'b1;
                        4'h1: psel2 = 1'b1;
                        4'h2: psel3 = 1'b1;
                        4'h3: psel4 = 1'b1;
                        4'h4: psel5 = 1'b1;
                        default: dec_error = 1'b1;
                    endcase
                end
                default: dec_error = 1'b1;
            endcase
        end
    end
endmodule

module apb_mux (
    input  logic        pready0,
    input  logic        pready1,
    input  logic        pready2,
    input  logic        pready3,
    input  logic        pready4,
    input  logic        pready5,
    input  logic [31:0] sel,
    input  logic [31:0] prdata0,
    input  logic [31:0] prdata1,
    input  logic [31:0] prdata2,
    input  logic [31:0] prdata3,
    input  logic [31:0] prdata4,
    input  logic [31:0] prdata5,
    output logic        ready,
    output logic [31:0] rdata
);

    always_comb begin
        rdata = 32'h0000_0000;
        ready = 1'b0;

        case (sel[31:28])
            4'h1: begin
                rdata = prdata0;
                ready = pready0;
            end
            4'h2: begin
                case (sel[15:12])
                    4'h0: begin
                        rdata = prdata1;
                        ready = pready1;
                    end
                    4'h1: begin
                        rdata = prdata2;
                        ready = pready2;
                    end
                    4'h2: begin
                        rdata = prdata3;
                        ready = pready3;
                    end
                    4'h3: begin
                        rdata = prdata4;
                        ready = pready4;
                    end
                    4'h4: begin
                        rdata = prdata5;
                        ready = pready5;
                    end
                endcase
            end
            default: begin
                rdata = 32'h0000_0000;
                ready = 1'b1;
            end
        endcase
    end
endmodule
