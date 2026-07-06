`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] drdata,
    output [31:0] instr_addr,
    output        dwe,
    output [ 2:0] o_funct3,
    output [31:0] daddr,
    output [31:0] dwdata
);

    logic rf_we, alu_src;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;
    logic jal, jalr;

    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .rst(rst),
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .rf_we(rf_we),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .rfwd_src(rfwd_src),
        .o_funct3(o_funct3),
        .dwe(dwe)
    );

    rv32i_datapath U_RV32I_DATAPATH (.*);

endmodule


module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    output logic       pc_en,
    output logic       rf_we,
    output logic       branch,
    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic [2:0] rfwd_src,
    output logic [2:0] o_funct3,
    output logic       dwe,
    output logic       jal,
    output logic       jalr
);

    typedef enum logic {
        FETCH,
        DECODE,
        EXECUTE,
        EXE_R,
        EXE_I,
        EXE_B,
        EXE_IL,
        EXE_S,
        EXE_UL,
        EXE_UA,
        EXE_J,
        EXE_JR,
        MEM,
        MEM_S,
        MEM_IL,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @( posedge clk, posedge rst ) begin // 버튼이기 때문에 posedge나 negedge나 상관이 없다. fpga에서 버튼으로 rst를 하니까.
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    // next CL
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                //
            end
            MEM: begin
                // 
            end
            WB: begin
                n_state = FETCH;
            end
        endcase
    end

    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        rfwd_src    = 2'b00;
        o_funct3    = 3'b000;
        dwe         = 1'b0;
        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECODE: begin
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        alu_src = 1'b1;
                        if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                    end
                    `B_TYPE: begin
                        branch      = 1'b1;
                        alu_src     = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                        o_funct3    = funct3;
                        dwe         = 1'b1;
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                        o_funct3    = funct3;
                        dwe         = 1'b0;
                    end
                    `UL_TYPE: begin
                        // 
                    end
                    `UA_TYPE: begin
                        //
                    end
                    `J_TYPE: begin
                        jal = 1'b1;
                    end
                    `JR_TYPE: begin
                        jalr = 1'b1;
                    end


                endcase
            end
        endcase
    end
    //    always_comb begin
    //        rf_we       = 1'b0;
    //        branch      = 1'b0;
    //        alu_src     = 1'b0;
    //        alu_control = 4'b0000;
    //        rfwd_src    = 2'b00;
    //        o_funct3    = 3'b000;
    //        dwe         = 1'b0;
    //        case (opcode)
    //            `R_TYPE: begin
    //                rf_we       = 1'b1;
    //                branch      = 1'b0;  // don't care
    //                jal         = 1'b0;  // don't care
    //                jalr        = 1'b0;  // don't care
    //                alu_src     = 1'b0;
    //                alu_control = {funct7[5], funct3};
    //                rfwd_src    = 3'b000;
    //                o_funct3    = 3'b000;  // don't care
    //                dwe         = 1'b0;  // don't care
    //            end
    //            `B_TYPE: begin
    //                rf_we       = 1'b0;
    //                branch      = 1'b1;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                alu_src     = 1'b0;
    //                alu_control = {1'b0, funct3};
    //                rfwd_src    = 3'b000;
    //                o_funct3    = 3'b000;
    //                dwe         = 1'b0;
    //            end
    //            `S_TYPE: begin
    //                rf_we       = 1'b0;
    //                branch      = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                alu_src     = 1'b1;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'b000;
    //                o_funct3    = funct3;
    //                dwe         = 1'b1;
    //            end
    //            `IL_TYPE: begin
    //                rf_we       = 1'b1;
    //                branch      = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                alu_src     = 1'b1;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'b001;
    //                o_funct3    = funct3;
    //                dwe         = 1'b0;
    //            end
    //            `I_TYPE: begin
    //                rf_we = 1'b1;
    //                branch = 1'b0;
    //                jal = 1'b0;
    //                jalr = 1'b0;
    //                alu_src = 1'b1;
    //                if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
    //                else alu_control = {1'b0, funct3};
    //                rfwd_src = 3'b000;
    //                o_funct3 = funct3;
    //                dwe      = 1'b0;
    //            end
    //            `UL_TYPE: begin
    //                rf_we = 1'b1;
    //                branch = 1'b0;
    //                jal = 1'b0;
    //                jalr = 1'b0;
    //                alu_src = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src = 3'b010;
    //                o_funct3 = 3'b000;
    //                dwe = 1'b0;
    //            end
    //            `UA_TYPE: begin
    //                rf_we = 1'b1;
    //                branch = 1'b0;
    //                jal = 1'b0;
    //                jalr = 1'b0;
    //                alu_src = 1'b0;
    //                alu_control = 4'b000;
    //                rfwd_src = 3'b011;
    //                o_funct3 = 3'b000;
    //                dwe = 1'b0;
    //            end
    //            `J_TYPE: begin
    //                rf_we = 1'b1;
    //                branch = 1'b0;
    //                jal = 1'b1;
    //                jalr = 1'b0;
    //                alu_src = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src = 3'b100;
    //                o_funct3 = 3'b000;
    //                dwe = 1'b0;
    //            end
    //            `JR_TYPE: begin
    //                rf_we = 1'b1;
    //                branch = 1'b0;
    //                jal = 1'b0;
    //                jalr = 1'b1;
    //                alu_src = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src = 3'b100;
    //                o_funct3 = 3'b000;
    //                dwe = 1'b0;
    //            end
    //        endcase
    //    end

`ifdef SIMULATION
    logic [63:0] opcode_type;
    logic [63:0] alu_ctrl_mode;

    always_comb begin
        case (opcode)
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

    // 2. 명령어 세부 문자열 디코딩 (Opcode 기반 1차 분류 후 세부 디코딩)
    always_comb begin
        alu_ctrl_mode = "NONE";  // 기본값 할당

        case (opcode)
            `R_TYPE: begin
                // R-Type은 alu_control(4비트)을 기준으로 판별
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
                // I-Type ALU 연산은 R-Type과 alu_control 값을 공유하므로 문자열 끝에 'I'만 붙여 출력
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
                // B-Type은 4비트로 정의된 매크로와 alu_control을 매칭
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
                // Load 명령어는 Control Unit으로 들어오는 funct3(3비트)를 직접 디코딩
                case (funct3)
                    `LB   : alu_ctrl_mode = "LB";
                    `LH   : alu_ctrl_mode = "LH";
                    `LW   : alu_ctrl_mode = "LW";
                    `LBU  : alu_ctrl_mode = "LBU";
                    `LHU  : alu_ctrl_mode = "LHU";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `S_TYPE: begin
                // Store 명령어 역시 funct3(3비트)를 직접 디코딩
                case (funct3)
                    `SB   : alu_ctrl_mode = "SB";
                    `SH   : alu_ctrl_mode = "SH";
                    `SW   : alu_ctrl_mode = "SW";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            // 기타 단일 명령어 처리
            `J_TYPE:  alu_ctrl_mode = "JAL";
            `JR_TYPE: alu_ctrl_mode = "JALR";
            `UL_TYPE: alu_ctrl_mode = "LUI";
            `UA_TYPE: alu_ctrl_mode = "AUIPC";

            default: alu_ctrl_mode = "NONE";
        endcase
    end
`endif
endmodule

