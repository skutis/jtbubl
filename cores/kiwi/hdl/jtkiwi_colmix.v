/*  This file is part of JTBUBL.
    JTBUBL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTBUBL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTBUBL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-9-2022 */

module jtkiwi_colmix(
    input        clk,
    input        clk_cpu,
    input        pxl_cen,
    input        LHBL,
    input        LVBL,

    input  [8:0] scr_pxl,
    input  [8:0] obj_pxl,

    input  [9:0] cpu_addr,
    input  [7:0] cpu_dout,
    input        cpu_rnw,
    output [7:0] cpu_din,
    input        pal_cs,

    input      [3:0] gfx_en,
    output     [4:0] red,
    output     [4:0] green,
    output     [4:0] blue
);

wire [7:0] pal_dout;
wire [9:0] pal_addr;
reg  [7:0] pall;
reg  [8:0] coll, col_addr;
reg  [14:0] rgb;
wire       pal_we;
wire       blank;
reg        half, obj_sel;

assign pal_addr = { coll, half };
assign pal_we   = pal_cs & ~cpu_rnw;
assign blank    = ~(LVBL & LHBL);
assign {red,green,blue} = {15{~blank}} & rgb;

always @* begin
    obj_sel = obj_pxl[3:0] != 4'h0;
    if( !gfx_en[0] ) obj_sel = 1;
    if( !gfx_en[3] ) obj_sel = 0;
    col_addr = obj_sel ? obj_pxl : scr_pxl; // simple priority for now.
end

always @(posedge clk) begin
    half <= ~half;
    if( pxl_cen ) begin
`ifdef GRAY
        rgb <= ~{3{ {coll[3:0]}, 1'b0 } };
`else
        rgb <= { pal_dout[6:0], pall };
`endif
        half <= 1;
        coll <= col_addr;
    end
    pall <= pal_dout;
end

// Palette RAM X1-007 chip
jtframe_dual_ram #(.aw(10),.simfile("pal.bin")) u_comm(
    .clk0   ( clk_cpu      ),
    .clk1   ( clk          ),
    // Main CPU
    .addr0  ( cpu_addr     ),
    .data0  ( cpu_dout     ),
    .we0    ( pal_we       ),
    .q0     ( cpu_din      ),
    // Color mixer
    .addr1  ( pal_addr     ),
    .data1  (              ),
    .we1    ( 1'b0         ),
    .q1     ( pal_dout     )
);

endmodule