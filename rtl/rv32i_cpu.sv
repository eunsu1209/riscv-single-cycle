`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst_n,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,
    output [31:0] instr_addr,
    output        bus_wreq,
    output        bus_rreq,
    output [31:0] bus_addr,
    output [31:0] bus_wdata,
    output [ 3:0] bus_wstrb
);

    logic pc_en, rf_we, alu_src;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;
    logic jal, jalr;

    rv32i_control_unit U_CONTROL_UNIT (
        .clk(clk),
        .rst_n(rst_n),
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .pc_en(pc_en),
        .rf_we(rf_we),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .rfwd_src(rfwd_src),
        .ready(bus_ready),
        .wreq(bus_wreq),
        .rreq(bus_rreq)
    );

    rv32i_datapath U_RV32I_DATAPATH (
        .clk        (clk),
        .rst_n      (rst_n),
        .pc_en      (pc_en),
        .rf_we      (rf_we),
        .branch     (branch),
        .alu_src    (alu_src),
        .jal        (jal),
        .jalr       (jalr),
        .bus_wreq   (bus_wreq),
        .alu_control(alu_control),
        .instr_data (instr_data),
        .bus_rdata  (bus_rdata),
        .rfwd_src   (rfwd_src),
        .instr_addr (instr_addr),
        .bus_addr   (bus_addr),
        .bus_wdata  (bus_wdata),
        .bus_wstrb  (bus_wstrb)
    );


`ifdef SIMULATION
    logic [63:0] opcode_type;
    logic [63:0] alu_ctrl_mode;

    always_comb begin
        case (instr_data[6:0])
            `R_TYPE:  opcode_type = "R_TYPE";
            `I_TYPE:  opcode_type = "I_TYPE";
            `S_TYPE:  opcode_type = "S_TYPE";
            `B_TYPE:  opcode_type = "B_TYPE";
            `IL_TYPE: opcode_type = "IL_TYPE";
            `J_TYPE:  opcode_type = "J_TYPE";
            `JR_TYPE: opcode_type = "JR_TYPE";
            `UL_TYPE: opcode_type = "UL_TYPE";
            `UA_TYPE: opcode_type = "UA_TYPE";
            default:  opcode_type = "UNKNOWN";
        endcase
    end

    always_comb begin
        alu_ctrl_mode = "NONE";

        case (instr_data[6:0])
            `R_TYPE: begin
                case (alu_control)
                    `ADD  : alu_ctrl_mode = "ADD";
                    `SUB  : alu_ctrl_mode = "SUB";
                    `SLL  : alu_ctrl_mode = "SLL";
                    `SLT  : alu_ctrl_mode = "SLT";
                    `SLTU : alu_ctrl_mode = "SLTU";
                    `XOR  : alu_ctrl_mode = "XOR";
                    `SRL  : alu_ctrl_mode = "SRL";
                    `SRA  : alu_ctrl_mode = "SRA";
                    `OR   : alu_ctrl_mode = "OR";
                    `AND  : alu_ctrl_mode = "AND";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `I_TYPE: begin
                case (alu_control)
                    `ADD  : alu_ctrl_mode = "ADDI";
                    `SLL  : alu_ctrl_mode = "SLLI";
                    `SLT  : alu_ctrl_mode = "SLTI";
                    `SLTU : alu_ctrl_mode = "SLTIU";
                    `XOR  : alu_ctrl_mode = "XORI";
                    `SRL  : alu_ctrl_mode = "SRLI";
                    `SRA  : alu_ctrl_mode = "SRAI";
                    `OR   : alu_ctrl_mode = "ORI";
                    `AND  : alu_ctrl_mode = "ANDI";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `B_TYPE: begin
                case (alu_control)
                    `BEQ: alu_ctrl_mode = "BEQ";
                    `BNE: alu_ctrl_mode = "BNE";
                    `BLT: alu_ctrl_mode = "BLT";
                    `BGE: alu_ctrl_mode = "BGE";
                    `BLTU: alu_ctrl_mode = "BLTU";
                    `BGEU: alu_ctrl_mode = "BGEU";
                    default: alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `IL_TYPE: begin
                case (instr_data[14:12])
                    `LB   : alu_ctrl_mode = "LB";
                    `LH   : alu_ctrl_mode = "LH";
                    `LW   : alu_ctrl_mode = "LW";
                    `LBU  : alu_ctrl_mode = "LBU";
                    `LHU  : alu_ctrl_mode = "LHU";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `S_TYPE: begin
                case (instr_data[14:12])
                    `SB   : alu_ctrl_mode = "SB";
                    `SH   : alu_ctrl_mode = "SH";
                    `SW   : alu_ctrl_mode = "SW";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `J_TYPE:  alu_ctrl_mode = "JAL";
            `JR_TYPE: alu_ctrl_mode = "JALR";
            `UL_TYPE: alu_ctrl_mode = "LUI";
            `UA_TYPE: alu_ctrl_mode = "AUIPC";

            default: alu_ctrl_mode = "NONE";
        endcase
    end
`endif

endmodule