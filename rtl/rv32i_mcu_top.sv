`timescale 1ns / 1ps

module rv32i_mcu (
    input               clk,
    input               rst_n,
    input        [15:0] switch,
    output       [15:0] led,
    inout  wire  [15:0] gpio,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data,
    input  logic        i_uart_rx,
    output logic        o_uart_tx
);
    logic [31:0] instr_addr, instr_data;
    logic [31:0] bus_addr, bus_wdata, bus_rdata;
    logic [3:0] bus_wstrb;
    logic bus_wreq, bus_rreq, bus_ready;

    logic [31:0] paddr, pwdata;
    logic [3:0] pstrb;
    logic pwrite, penable;
    logic [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5;
    logic psel0, psel1, psel2, psel3, psel4, psel5;
    logic pready0, pready1, pready2, pready3, pready4, pready5;
    logic pslverr, slverr;

    assign pslverr = 1'b0;

    logic [15:0] gpo_data_out;
    logic [15:0] gpo_oe_out;

    logic [15:0] gpio_in_wire;
    logic [15:0] gpio_out_wire;
    logic [15:0] gpio_oe_wire;

    instruction_mem U_INSTRUCTION_MEM (
        .instr_addr(instr_addr),
        .instr_data(instr_data)
    );

    rv32i_cpu U_RV32I (
        .clk       (clk),
        .rst_n     (rst_n),
        .instr_data(instr_data),
        .bus_rdata (bus_rdata),
        .bus_ready (bus_ready),
        .instr_addr(instr_addr),
        .bus_wreq  (bus_wreq),
        .bus_rreq  (bus_rreq),
        .bus_addr  (bus_addr),
        .bus_wdata (bus_wdata),
        .bus_wstrb (bus_wstrb)
    );

    APB_MASTER U_APB_MASTER (
        .pclk   (clk),
        .presetn(rst_n),
        .addr   (bus_addr),
        .wdata  (bus_wdata),
        .wreq   (bus_wreq),
        .rreq   (bus_rreq),
        .wstrb  (bus_wstrb),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pstrb  (pstrb),
        .penable(penable),
        .pwrite (pwrite),
        .psel0  (psel0),
        .psel1  (psel1),
        .psel2  (psel2),
        .psel3  (psel3),
        .psel4  (psel4),
        .psel5  (psel5),
        .pslverr(pslverr),
        .pready0(pready0),
        .pready1(pready1),
        .pready2(pready2),
        .pready3(pready3),
        .pready4(pready4),
        .pready5(pready5),
        .prdata0(prdata0),
        .prdata1(prdata1),
        .prdata2(prdata2),
        .prdata3(prdata3),
        .prdata4(prdata4),
        .prdata5(prdata5),
        .slverr (slverr),
        .rdata  (bus_rdata),
        .ready  (bus_ready)
    );

    RAM U_APB_RAM (
        .pclk   (clk),
        .presetn(rst_n),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pwrite (pwrite),
        .penable(penable),
        .psel0  (psel0),
        .pstrb  (pstrb),
        .prdata0(prdata0),
        .pready0(pready0)
    );

    GPO U_APB_GPO (
        .pclk(clk),
        .presetn(rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel1),
        .penable(penable),
        .prdata(prdata1),
        .pready(pready1),
        .o_gpo   (gpo_data_out),
        .o_gpo_oe(gpo_oe_out)
    );

    GPI U_APB_GPI (
        .pclk(clk),
        .presetn(rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel2),
        .penable(penable),
        .prdata(prdata2),
        .pready(pready2),
        .i_gpi(switch)
    );

    GPIO U_APB_GPIO (
        .pclk(clk),
        .presetn(rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel3),
        .penable(penable),
        .prdata(prdata3),
        .pready(pready3),
        .i_gpio   (gpio_in_wire),
        .o_gpio   (gpio_out_wire),
        .o_gpio_oe(gpio_oe_wire)
    );

    FND U_APB_FND (
        .pclk(clk),
        .presetn(rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel4),
        .penable(penable),
        .prdata(prdata4),
        .pready(pready4),
        .o_fnd_digit(fnd_digit),
        .o_fnd_data(fnd_data)
    );

    apb_uart_slave U_APB_UART (
        .pclk   (clk),
        .presetn(rst_n),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pwrite (pwrite),
        .psel   (psel5),
        .penable(penable),
        .prdata (prdata5),
        .pready (pready5),

        .i_uart_rx(i_uart_rx),
        .o_uart_tx(o_uart_tx)
    );

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : gen_led_out
            assign led[i] = gpo_oe_out[i] ? gpo_data_out[i] : 1'b0;
        end
    endgenerate

    genvar j;
    generate
        for (j = 0; j < 16; j++) begin : gen_gpio_inout
            assign gpio[j] = gpio_oe_wire[j] ? gpio_out_wire[j] : 1'bz;
        end
    endgenerate
    
    assign gpio_in_wire = gpio;

endmodule
