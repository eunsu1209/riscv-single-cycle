`timescale 1ns / 1ps

module instruction_mem (
    input  [31:0] instr_addr,
    output [31:0] instr_data
);

    logic [31:0] rom[0:255];

    initial begin
        $readmemh("rv32i_rom_data.mem", rom);

    end

    assign instr_data = rom[instr_addr[31:2]];

endmodule