`timescale 1ns / 1ps
`include "define.vh"

module data_mem (
    input         clk,
    input         dwe,
    input  [ 2:0] i_funct3,
    input  [31:0] daddr,
    input  [31:0] dwdata,
    output logic [31:0] drdata
);

    // S_TYPE: store
    logic [31:0] dmem[0:255];
    always_ff @(posedge clk) begin
        if (dwe) begin
            case (i_funct3)
                `SW: begin
                    dmem[daddr[31:2]] <= dwdata;
                end
                `SH: begin
                    if (daddr[1] == 0) dmem[daddr[31:2]][15:0] <= dwdata[15:0];
                    else dmem[daddr[31:2]][31:16] <= dwdata[15:0];
                end
                `SB: begin
                    case (daddr[1:0])
                        2'b00: dmem[daddr[31:2]][7:0] <= dwdata[7:0];
                        2'b01: dmem[daddr[31:2]][15:8] <= dwdata[7:0];
                        2'b10: dmem[daddr[31:2]][23:16] <= dwdata[7:0];
                        2'b11: dmem[daddr[31:2]][31:24] <= dwdata[7:0];
                    endcase
                end
            endcase
        end
    end

    // IL_TYPE: load
    logic [31:0] rw;

    assign rw = dmem[daddr[31:2]];

    always_comb begin
        drdata = 32'd0;
        case (i_funct3)
            `LW: begin
                drdata = rw;
            end
            `LH: begin
                if (daddr[1] == 1'b0) drdata = {{16{rw[15]}}, rw[15:0]};
                else drdata = {{16{rw[15]}}, rw[31:16]};
            end
            `LHU: begin
                if(daddr[1] == 1'b0) drdata = {16'b0, rw[15:0]};
                else drdata = {16'b0, rw[31:16]};
            end
            `LB: begin
                case (daddr[1:0])
                    2'b00: drdata = {{24{rw[7]}}, rw[7:0]};
                    2'b01: drdata = {{24{rw[15]}}, rw[15:8]};
                    2'b10: drdata = {{24{rw[23]}}, rw[23:16]};
                    2'b11: drdata = {{24{rw[31]}}, rw[31:24]};
                endcase
            end
            `LBU: begin
                case (daddr[1:0])
                    2'b00: drdata = {24'b0, rw[7:0]};
                    2'b01: drdata = {24'b0, rw[15:8]};
                    2'b10: drdata = {24'b0, rw[23:16]};
                    2'b11: drdata = {24'b0, rw[31:24]};
                endcase
            end
            default : drdata = rw;
        endcase
    end

endmodule



// byte address
// logic [7:0] dmem[0:31];

// assign drdata = {dmem[daddr], dmem[daddr+1], dmem[daddr+3], dmem[daddr+4]};

// always_ff @(posedge clk) begin
//     if (dwe) begin
//         dmem[daddr+0] <= ddata[7:0];
//         dmem[daddr+1] <= ddata[15:8];
//         dmem[daddr+2] <= ddata[23:16];
//         dmem[daddr+3] <= ddata[31:24];
//     end
// end
