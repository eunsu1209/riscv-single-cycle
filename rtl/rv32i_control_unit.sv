`timescale 1ns / 1ps
`include "define.vh"

module rv32i_control_unit (
    input [6:0] funct7,
    input [2:0] funct3,
    input [6:0] opcode,

    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic       branch,
    output logic       jal,
    output logic       jalr,

    output logic mem_wreq,
    output logic mem_rreq,

    output logic       rf_we,
    output logic [2:0] rfwd_src

);

    always_comb begin
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        mem_wreq    = 1'b0;
        mem_rreq    = 1'b0;
        rf_we       = 1'b0;
        rfwd_src    = 3'b000;

        case (opcode)
            `R_TYPE: begin
                // execute
                alu_src     = 1'b0;
                alu_control = {funct7[5], funct3};
                // wb
                rf_we       = 1'b1;
                rfwd_src    = 3'b000;
            end
            `I_TYPE: begin
                // execute
                alu_src = 1'b1;
                if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                else alu_control = {1'b0, funct3};
                // wb
                rf_we    = 1'b1;
                rfwd_src = 3'b000;
            end
            `IL_TYPE: begin
                // execute
                alu_src     = 1'b1;
                alu_control = 4'b0000;
                // mem
                mem_rreq    = 1'b1;
                // wb
                rf_we       = 1'b1;
                rfwd_src    = 3'b001;
            end
            `S_TYPE: begin
                // execute
                alu_src     = 1'b1;
                alu_control = 4'b0000;
                // mem
                mem_wreq    = 1'b1;
            end
            `B_TYPE: begin
                // execute
                alu_src     = 1'b0;
                alu_control = {1'b0, funct3};
                branch      = 1'b1;
            end
            `UL_TYPE: begin
                // wb
                rf_we    = 1'b1;
                rfwd_src = 3'b010;
            end
            `UA_TYPE: begin
                // wb
                rf_we    = 1'b1;
                rfwd_src = 3'b011;
            end
            `J_TYPE: begin
                // execute
                jal      = 1'b1;
                // wb
                rf_we    = 1'b1;
                rfwd_src = 3'b100;
            end
            `JR_TYPE: begin
                // execute
                jalr     = 1'b1;
                // wb
                rf_we    = 1'b1;
                rfwd_src = 3'b100;
            end
        endcase
    end

endmodule
