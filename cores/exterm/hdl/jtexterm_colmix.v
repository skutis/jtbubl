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

module jtexterm_colmix(
    input        clk,
    input        clk_cpu,
    input        pxl_cen,
    input        LHBL,
    input        LVBL,

    input  [8:0] col_addr,

    input  [9:0] cpu_addr,
    input  [7:0] cpu_dout,
    input        cpu_rnw,
    output [7:0] cpu_din,
    input        pal_cs,

    output reg [4:0] red,
    output reg [4:0] green,
    output reg [4:0] blue
);

wire [7:0] pal_dout;
wire [9:0] pal_addr = 0;
reg  [7:0] pall;
wire       pal_we;

assign pal_addr = { half, coll }
assign pal_we = pal_cs & ~cpu_rnw;

always @(posedge clk) begin
    half <= ~half;
    if( pxl_cen ) begin
        { red, green, blue } <= { pal_dout, pall };
        half <= 1;
        coll <= col_addr;
    end
    pall <= pal_dout;
end

// Palette RAM X1-007 chip
jtframe_dual_ram #(.aw(10)) u_comm(
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