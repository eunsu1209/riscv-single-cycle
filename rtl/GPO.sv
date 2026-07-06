`timescale 1ns / 1ps

module GPO (
    input logic        pclk,
    input logic        presetn,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic        pwrite,
    input logic        psel,
    input logic        penable,

    output logic [31:0] prdata,
    output logic        pready,

    output logic [15:0] o_gpo,
    output logic [15:0] o_gpo_oe
);

    localparam [11:0] GPO_CTL_ADDR = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;

    logic [15:0] gpo_ctl_reg;
    logic [15:0] gpo_odata_reg;

    assign pready = 1'b1;

    always_comb begin
        prdata = 32'h0000_0000;

        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                GPO_CTL_ADDR:   prdata = {16'h0000, gpo_ctl_reg};
                GPO_ODATA_ADDR: prdata = {16'h0000, gpo_odata_reg};
            endcase
        end
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpo_ctl_reg   <= 16'h0000;
            gpo_odata_reg <= 16'h0000;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    GPO_CTL_ADDR:   gpo_ctl_reg <= pwdata[15:0];
                    GPO_ODATA_ADDR: gpo_odata_reg <= pwdata[15:0];
                endcase
            end
        end
    end

    assign o_gpo    = gpo_odata_reg;
    assign o_gpo_oe = gpo_ctl_reg;

endmodule
