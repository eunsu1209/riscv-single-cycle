`timescale 1ns / 1ps

module instruction_mem (
    input  [31:0] instr_addr,
    output [31:0] instr_data
);

    logic [31:0] rom[0:255];

    initial begin
        $readmemh("risc_rv32i_rom_data.mem", rom);
    
    end

    assign instr_data = rom[instr_addr[31:2]];

endmodule

// R-type
// rom[0]  = 32'h002182b3;  //ADD X5, X3, X2  -> 5
// rom[1]  = 32'h402182b3;  //SUB X5, X3, X2  -> 1
// rom[2]  = 32'h40310233;  //SUB X4, X2, X3  -> -1
// rom[3]  = 32'h002192b3;  //SLL X5, X3, X2 ->  12
// rom[4]  = 32'h0041a2b3;  //SLT X5, X3, X4  -> 0
// rom[5]  = 32'h0041b2b3;  //SLTU X5, X3, X4 -> 1
// rom[6]  = 32'h0011c2b3;  //XOR X5, X3, X1  -> 2
// rom[7]  = 32'h002252b3;  //SRL X5, X4, X2  -> 1073751823
// rom[8]  = 32'h402252b3;  //SRA X5, X4, X2  -> -1
// rom[9] = 32'h0021e2b3;  //OR X5, X3, X2  -> 3
// rom[10] = 32'h0021f2b3;  //AND X5, X3, X2 -> 2

// B-type
// rom[0] = 32'403081b3h;  // SUB X3, X1, X3
// rom[1] = 32'h00108463;  // BEQ X1, X1, +8
// rom[2] = 32'h001081b3;  // ADD X3, X1, x1
// rom[3] = 32'h0011c463;  // BLT X3, X1, +8
// rom[4] = 32'h001081b3;  // ADD X3, X1, x1
// rom[5] = 32'h0030d463;  // BGE X1, X3, +8
// rom[6] = 32'h001081b3;  // ADD X3, X1, x1
// rom[7] = 32'h00109463;  // BNE X1, X1, +8
// rom[8] = 32'h00108233;  // ADD X4, X1, x1
// rom[9] = 32'h0011e463;  // BLTU X3, X1, +8
// rom[10] = 32'h00108233; // ADD X4, X2, x1
// rom[11] = 32'h0030f463; // BGEU X1, X3, +8
// rom[12] = 32'h001082b3; // ADD X4, X3, x1

// S-type
// rom[0] = 32'h401000b3;  // SUB X1, X0, X1
// rom[1] = 32'h00102223;  // SW X1, 4(X0) 
// rom[2] = 32'h00102423;  // SW X1, 8(X0) 
// rom[4] = 32'h00201423;  // SH X2, 8(X0) 
// rom[5] = 32'h00301523;  // SH X3, 10(X0)
// rom[6] = 32'h00400223;  // SB X4, 4(X0)
// rom[7] = 32'h005002a3;  // SB X5, 5(X0)
// rom[8] = 32'h00600523;  // SB X6, 10(X0)
// rom[9] = 32'h007005a3;  // SB X7, 11(X0)
// rom[10] = 32'h001014a3; // SH X1, 9(X0)

// IL-type
// rom[0] = 32'h00402083;  // LW X1, 4(X0))
// rom[1] = 32'h00401083;  // LH X1, 4(X0) Signed
// rom[2] = 32'h00501083;  // LH X1, 5(X0) Signed
// rom[3] = 32'h00605083;  // LHU X1, 6(X0) Unsigned
// rom[4] = 32'h00400083;  // LB X1, 4(X0) Signed
// rom[5] = 32'h00504083;  // LBU X1, 5(X0) Unsigned
// rom[6] = 32'h00600083;  // LB X1, 6(X0) 5(2's byte)
// rom[7] = 32'h00700083;  // LB X1, 7(X0) 7(4's byte)

// I-type
// rom[0] = 32'hffd00093;  // ADDI X1, X0, -3  -> 0 + (-3) = -3. (X1 = 0xFFFFFFFD)
// rom[1] = 32'h00300113;  // ADDI X2, X0, 3   -> 0 + 3 = 3. (X2 = 3)
// rom[2] = 32'h00714193;  // XORI X3, X2, 7   -> 3(0011) ^ 7(0111) = 4(0100). (X3 = 4)
// rom[3] = 32'h00416193;  // ORI X3, X2, 4    -> 3(0011) | 4(0100) = 7(0111). (X3 = 7)
// rom[4] = 32'h00717193;  // ANDI X3, X2, 7   -> 3(0011) & 7(0111) = 3(0011). (X3 = 3)
// rom[5] = 32'h00111193;  // SLLI X3, X2, 1   -> 3 << 1 = 6. (X3 = 6)
// rom[6] = 32'h0020d193;  // SRLI X3, X1, 2   -> 논리 우측 시프트. 빈자리를 0으로. (X3 = 0x3FFFFFFF = 1073741823)
// rom[7] = 32'h4020d193;  // SRAI X3, X1, 2   -> 산술 우측 시프트. 부호 비트(1) 복사. (X3 = 0xFFFFFFFF = -1)
// rom[8] = 32'h0000a193;  // SLTI X3, X1, 0   -> Signed 비교. -3 < 0 은 참. (X3 = 1)
// rom[9] = 32'h0000b193;  // SLTIU X3, X1, 0  -> Unsigned 비교. 4294967293 < 0 은 거짓. (X3 = 0)

// UL/UA-type
// rom[0] = 32'h123450b7;  // LUI X1, 0x12345  -> X1 = 0x12345000
// rom[1] = 32'hfffff137;  // LUI X2, 0xFFFFF  -> X2 = 0xFFFFF000
// rom[2] = 32'h00001197;  // AUIPC X3, 0x00001 -> X3 = 8 + 0x1000 = 0x00001008
// rom[3] = 32'hfffff217;  // AUIPC X4, 0xFFFFF -> X4 = 12 + 0xFFFFF000 = 0xFFFFF00C

// J/JR-type
// rom[0] = 32'h00c000ef;  // JAL X1, +12      -> PC = 12로 점프! (X1 = 4)
// rom[1] = 32'h0000006f;  // JAL X0, 0        -> Trap!
// rom[2] = 32'h0000006f;  // JAL X0, 0        -> Trap!
// // PC = 12. X1(4) + 16 = 20번지로 점프. 돌아올 주소(12+4=16)를 X2에 저장.
// rom[3] = 32'h01008167;  // JALR X2, X1, 16  -> PC = 4 + 16 = 20으로 점프! (X2 = 16)
// rom[4] = 32'h0000006f;  // JAL X0, 0        -> Trap!
// // PC = 20. X2(16) - 16 = 0번지로 점프. 돌아올 주소(20+4=24)를 X3에 저장.
// rom[5] = 32'hff4101e7;  // JALR X3, X2, -12 -> PC = 16 - 12 = 4로 되돌아감! (X3 = 24)
/*
int adder (int a, int b);

void main(void) {
    int i = 0;
    int sum = 0;
    while (i < 11) {
        i = i + 1;
        sum = adder(i, sum);
    }
    return;
}

int adder(int a, int b) {
    return a + b;
}

int adder(int a, int b) {
    return a + b;
}

int main(void) {
    int i = 1;
    int sum = 0;
    
    while (i <= 10) {
        sum = adder(i, sum);
        i = i + 1;
    }
    
    while(1);
    
    return 0;
}

*/
/*
// main 함수
FE010113 // 00: addi x2, x2, -32
00112E23 // 04: sw x1, 28(x2)
00812C23 // 08: sw x8, 24(x2)
02010413 // 12: addi x8, x2, 32
00100793 // 16: addi x15, x0, 1
FEF42623 // 20: sw x15, -20(x8)
FE042423 // 24: sw x0, -24(x8)
0200006F // 28: jal x0, 32
*/