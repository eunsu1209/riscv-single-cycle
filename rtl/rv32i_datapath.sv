`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input         clk,
    input         rst_n,
    input         pc_en,
    input         rf_we,
    input         branch,
    input         alu_src,
    input         jal,
    input         jalr,
    input         bus_wreq,
    input  [ 3:0] alu_control,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input  [ 2:0] rfwd_src,
    output [31:0] instr_addr,
    output [31:0] bus_addr,
    output [31:0] bus_wdata,
    output [ 3:0] bus_wstrb
);
    logic [31:0] alu_result, alurs2_data, rfwb_data, imm_data;
    logic [31:0] pc_ua_out;
    logic [31:0] pc_jal_out;
    logic btaken;
    logic [31:0] lsu_wdata, lsu_rdata;
    logic [3:0] lsu_wstrb;

    assign bus_addr = o_exe_alu_result;

    load_store_unit U_LSU (
        .funct3   (instr_data[14:12]),
        .addr     (o_exe_alu_result),
        .wreq     (bus_wreq),
        // Store 경로
        .cpu_wdata(o_exe_rs2),
        .bus_wdata(lsu_wdata),
        .pstrb    (lsu_wstrb),
        // Load 경로
        .bus_rdata(bus_rdata),
        .cpu_rdata(lsu_rdata)
    );

    assign bus_wdata = lsu_wdata;
    assign bus_wstrb = lsu_wstrb;

    // fetch, execute
    program_counter U_PC (
        .clk(clk),
        .rst_n(rst_n),
        .btaken(btaken),
        .branch(branch),  // from alu comparator
        .jal(jal),
        .jalr(jalr),
        .pc_en(pc_en),
        .rd1_data(o_dec_rs1),
        .imm_data(o_dec_imm),
        .pc_out(instr_addr),  // from control unit for B-type
        .pc_ua_out(pc_ua_out),
        .pc_jal_out(pc_jal_out)
    );

    // decode
    register_file U_REG_FILE (
        .clk  (clk),
        .rst_n  (rst_n),
        .raddr1  (instr_data[19:15]),
        .raddr2  (instr_data[24:20]),
        .waddr   (instr_data[11:7]),
        .wdata(rfwb_data),
        .rf_we(rf_we),
        .rdata1  (rs1),
        .rdata2  (rs2)
    );
    imm_extender U_IMM_EXTEND (
        .instr_data(instr_data),
        .imm_data  (imm_data)
    );

    // execute
    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0    (rs2),
        .in1    (imm_data),
        .mux_sel(alu_src),
        .out_mux(alurs2_data)
    );
    alu U_ALU (
        .rd1        (rs1),
        .rd2        (alurs2_data),
        .alu_control(alu_control),
        .alu_result (alu_result),
        .btaken     (btaken)
    );

    mux_8x1 U_WB_MUX (
        .in0(alu_result),    // from ALU result, because process with execute state
        .in1(o_mem_drdata),  // from data memory
        .in2(imm_data),  // from imm extend, for LUI
        .in3(pc_ua_out),  // from pc + imm extend, for AUIPC
        .in4(pc_jal_out),  // from PC + 4, for JAL/JALR
        .mux_sel(rfwd_src),
        .out_mux(rfwb_data)
    );
endmodule

module load_store_unit (
    input        [ 2:0] funct3,
    input        [31:0] addr,
    input               wreq,       // [추가] Store일 때만 pstrb 활성화
    // Store 경로
    input        [31:0] cpu_wdata,
    output logic [31:0] bus_wdata,
    output logic [ 3:0] pstrb,
    // Load 경로
    input        [31:0] bus_rdata,
    output logic [31:0] cpu_rdata
);

    // Store 정렬 + pstrb 생성
    always_comb begin
        bus_wdata = cpu_wdata;
        pstrb     = 4'b0000;        // [수정] 기본값을 0으로. wreq일 때만 활성화
        if (wreq) begin
            case (funct3)
                3'b000: begin  // SB
                    case (addr[1:0])
                        2'b00: begin
                            pstrb = 4'b0001;
                            bus_wdata = {24'b0, cpu_wdata[7:0]};
                        end
                        2'b01: begin
                            pstrb = 4'b0010;
                            bus_wdata = {16'b0, cpu_wdata[7:0], 8'b0};
                        end
                        2'b10: begin
                            pstrb = 4'b0100;
                            bus_wdata = {8'b0, cpu_wdata[7:0], 16'b0};
                        end
                        2'b11: begin
                            pstrb = 4'b1000;
                            bus_wdata = {cpu_wdata[7:0], 24'b0};
                        end
                    endcase
                end
                3'b001: begin  // SH
                    case (addr[1])
                        1'b0: begin
                            pstrb = 4'b0011;
                            bus_wdata = {16'b0, cpu_wdata[15:0]};
                        end
                        1'b1: begin
                            pstrb = 4'b1100;
                            bus_wdata = {cpu_wdata[15:0], 16'b0};
                        end
                    endcase
                end
                3'b010: begin  // SW
                    pstrb     = 4'b1111;
                    bus_wdata = cpu_wdata;
                end
                default: begin
                    pstrb     = 4'b0000;
                    bus_wdata = cpu_wdata;
                end
            endcase
        end
    end

    // Load sign/zero-extend (이 부분은 이전과 동일)
    always_comb begin
        cpu_rdata = bus_rdata;
        case (funct3)
            3'b000: begin  // LB
                case (addr[1:0])
                    2'b00: cpu_rdata = {{24{bus_rdata[7]}}, bus_rdata[7:0]};
                    2'b01: cpu_rdata = {{24{bus_rdata[15]}}, bus_rdata[15:8]};
                    2'b10: cpu_rdata = {{24{bus_rdata[23]}}, bus_rdata[23:16]};
                    2'b11: cpu_rdata = {{24{bus_rdata[31]}}, bus_rdata[31:24]};
                endcase
            end
            3'b001: begin  // LH
                case (addr[1])
                    1'b0: cpu_rdata = {{16{bus_rdata[15]}}, bus_rdata[15:0]};
                    1'b1: cpu_rdata = {{16{bus_rdata[31]}}, bus_rdata[31:16]};
                endcase
            end
            3'b010:  cpu_rdata = bus_rdata;  // LW
            3'b100: begin  // LBU
                case (addr[1:0])
                    2'b00: cpu_rdata = {24'b0, bus_rdata[7:0]};
                    2'b01: cpu_rdata = {24'b0, bus_rdata[15:8]};
                    2'b10: cpu_rdata = {24'b0, bus_rdata[23:16]};
                    2'b11: cpu_rdata = {24'b0, bus_rdata[31:24]};
                endcase
            end
            3'b101: begin  // LHU
                case (addr[1])
                    1'b0: cpu_rdata = {16'b0, bus_rdata[15:0]};
                    1'b1: cpu_rdata = {16'b0, bus_rdata[31:16]};
                endcase
            end
            default: cpu_rdata = bus_rdata;
        endcase
    end

endmodule

module mux_2x1 (
    input        [31:0] in0,      // sel 0
    input        [31:0] in1,      // sel 1
    input               mux_sel,
    output logic [31:0] out_mux
);
    assign out_mux = (mux_sel) ? in1 : in0;

endmodule

module mux_8x1 (
    input [31:0] in0,
    input [31:0] in1,
    input [31:0] in2,
    input [31:0] in3,
    input [31:0] in4,
    input [2:0] mux_sel,
    output logic [31:0] out_mux
);

    always_comb begin
        case (mux_sel)
            3'b000:  out_mux = in0;
            3'b001:  out_mux = in1;
            3'b010:  out_mux = in2;
            3'b011:  out_mux = in3;
            3'b100:  out_mux = in4;
            default: out_mux = 32'b0;
        endcase
    end
endmodule

module imm_extender (
    input        [31:0] instr_data,
    output logic [31:0] imm_data
);
    always_comb begin
        imm_data = 32'd0;
        case (instr_data[6:0])  // opcode
            `S_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]
                };
            end
            `I_TYPE, `IL_TYPE: begin  // load
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `B_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}},
                    instr_data[7],  // imm bit 11
                    instr_data[30:25],
                    instr_data[11:8],
                    1'b0
                };
            end
            `UL_TYPE, `UA_TYPE: begin
                imm_data = {instr_data[31:12], 12'b0};
            end
            `JR_TYPE: begin
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `J_TYPE: begin
                imm_data = {
                    {12{instr_data[31]}},
                    instr_data[19:12],
                    instr_data[20],
                    instr_data[30:21],
                    1'b0
                };
            end
        endcase
    end
endmodule

module register_file (
    input         clk,
    input         rst_n,
    input  [ 4:0] raddr1,  // instruction code RS1
    input  [ 4:0] raddr2,  // instruction code RS1
    input  [ 4:0] waddr,   // instruction code RD
    input  [31:0] wdata,   // instruction RD write data
    input         rf_we,   // Register File Write Enable
    output [31:0] rdata1,  // Register File RS1 output
    output [31:0] rdata2   // Register File RS2 output
);
    logic [31:0] register_file[1:31];  //x0 must have zero

    // `ifdef SIMULATION
    //     initial begin
    //         for (int i = 0; i < 32; i++) begin
    //             register_file[i] = i;
    //         end
    //     end
    // `endif

    //output CL
    assign rdata1 = (raddr1 != 0) ? register_file[raddr1] : 32'h0;
    assign rdata2 = (raddr2 != 0) ? register_file[raddr2] : 32'h0;

    always_ff @(posedge clk) begin
        if (rst_n & rf_we) begin
            register_file[waddr] <= wdata;
        end
    end
endmodule

module alu (
    input        [31:0] rd1,          // RS1
    input        [31:0] rd2,          // RS2
    input        [ 3:0] alu_control,  // funct7[5], funct3 : 4bit
    output logic [31:0] alu_result,
    output logic        btaken
);

    always_comb begin
        alu_result = 0;
        case (alu_control)
            `ADD: alu_result = rd1 + rd2;  // add rd = rs1 + rs2
            `SUB: alu_result = rd1 - rd2;  // sub rd = rs1 - rs2
            `SLL: alu_result = rd1 << rd2[4:0];  //sll rd = rs1 << rs2
            `SLT:
            alu_result = ($signed(rd1) < $signed(rd2));  //slt rd = rs1 < rs2 
            `SLTU: alu_result = (rd1 < rd2);  //sltu rd = rs1 < rs2
            `XOR: alu_result = rd1 ^ rd2;  // xor rd = rs1 ^ rs2
            `SRL: alu_result = rd1 >> rd2[4:0];  // srl rd = rs1 >> rs2
            `SRA:
            alu_result = $signed(rd1) >>>
                rd2[4:0];  // sra rd = rs1 >>> rs2, msb extenstion
            `OR: alu_result = rd1 | rd2;  // or rd = rs1 | rs2
            `AND: alu_result = rd1 & rd2;  // and rd = rs1 & rs2
        endcase
    end

    always_comb begin
        btaken = 0;
        case (alu_control)
            `BEQ: begin
                if (rd1 == rd2) btaken = 1;
            end
            `BNE: begin
                if (rd1 != rd2) btaken = 1;
            end
            `BLT: begin
                if ($signed(rd1) < $signed(rd2)) btaken = 1;
            end
            `BGE: begin
                if ($signed(rd1) >= $signed(rd2)) btaken = 1;
            end
            `BLTU: begin
                if (rd1 < rd2) btaken = 1;
            end
            `BGEU: begin
                if (rd1 >= rd2) btaken = 1;
            end
        endcase
    end

endmodule

module program_counter (
    input               clk,
    input               rst_n,
    input               btaken,     // from alu for B-type
    input               branch,     // from control unit for B-type
    input               jal,
    input               jalr,
    input               pc_en,
    input        [31:0] rd1_data,
    input        [31:0] imm_data,
    output logic [31:0] pc_out,
    output logic [31:0] pc_ua_out,
    output logic [31:0] pc_jal_out
);
    logic [31:0] pc_next, o_exe_pcnext, pc_imm_out, o_jal_oc, pc_4_out;
    logic [31:0] pc_rd1i_out;  // pc_rd1_imm_out
    logic [31:0] pc_jrr_out;  // pc_jalr_rs1_out
    logic [31:0] pc_next_in1;
    logic        pc_next_sel;

    assign pc_next_in1 = jalr ? {pc_imm_out[31:1], 1'b0} : pc_imm_out;
    assign pc_next_sel = (btaken & branch) | jal | jalr;

    // execute
    mux_2x1 U_JALR_MUX (
        .in0(pc_out),
        .in1(rd1_data),
        .mux_sel(jalr),
        .out_mux(pc_jrr_out)
    );

    pc_alu U_PC_IMM (
        .a(imm_data),
        .b(pc_jrr_out),
        .pc_alu_out(pc_imm_out)
    );
    pc_alu U_PC_4 (
        .a(32'd4),
        .b(pc_out),
        .pc_alu_out(pc_4_out)
    );
    mux_2x1 PC_NEXT_MUX (
        .in0    (pc_4_out),
        .in1    (pc_next_in1),
        .mux_sel(pc_next_sel),
        .out_mux(pc_next)
    );

    register U_PCNEXT_REG (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(pc_next),
        .data_out(o_exe_pcnext)
    );
    // execute
    register U_UA_REG (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(pc_imm_out),
        .data_out(pc_ua_out)
    );
    register U_JAL_REG (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(pc_4_out),
        .data_out(pc_jal_out)
    );
    // fetch
    register_en U_PC_REG (
        .clk(clk),
        .rst_n(rst_n),
        .en(pc_en),
        .data_in(o_exe_pcnext),
        .data_out(pc_out)
    );
endmodule

module pc_alu (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] pc_alu_out
);
    assign pc_alu_out = a + b;
endmodule

module register (
    input         clk,
    input         rst_n,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    assign data_out = register;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            register <= 0;
        end else begin
            register <= data_in;
        end
    end

endmodule


module register_en (
    input         clk,
    input         rst_n,
    input         en,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    assign data_out = register;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            register <= 0;
        end else begin
            if (en) register <= data_in;
        end
    end

endmodule
