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
    Date: 18-09-2022 */

module jtexterm_gfx(
    input               rst,
    input               clk,
    input               clk_cpu,

    input               pxl2_cen,
    input               pxl_cen,

    input               LHBL,
    input               LVBL,
    input               hs,
    input               vs,
    output              flip,

    input      [ 8:0]   vdump,
    input      [ 8:0]   hdump,

    input               cpu_rnw,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    input               vram_cs,
    output     [ 7:0]   cpu_din,

    // SDRAM interface
    output     [19:0]   rom_addr,
    input      [31:0]   rom_data,
    input               rom_ok,
    output              rom_cs,
    output     [ 8:0]   col_addr
);

wire        vram_we;
wire [12:0] scan_addr;
wire [ 7:0] scan_dout;

assign scan_addr = 0;
assign vram_we = vram_cs & ~cpu_rnw;
assign rom_cs = 0;
assign rom_addr = 0;
assign col_addr = 0;
assign flip = 0;

// TODO: add bus contention
jtframe_dual_ram #(.aw(13)) u_vram(
    .clk0   ( clk        ),
    .clk1   ( clk_cpu    ),
    // Main CPU
    .addr0  ( cpu_addr   ),
    .data0  ( cpu_dout   ),
    .we0    ( vram_we    ),
    .q0     ( cpu_din    ),
    // MCU
    .addr1  ( scan_addr  ),
    .data1  ( 8'd0       ),
    .we1    ( 1'd0       ),
    .q1     ( scan_dout  )
);

jtframe_obj_buffer #(.FLIP_OFFSET(9'h100)) u_line(
    .clk    ( clk           ),
    .LHBL   ( ~hs           ),
    .flip   ( flip          ),
    // New data writes
    .wr_data( line_din      ),
    .wr_addr( line_addr     ),
    .we     ( line_we       ),
    // Old data reads (and erases)
    .rd_addr( hdump         ),
    .rd     ( pxl_cen       ),  // data will be erased after the rd event
    .rd_data( col_addr      )
);

endmodule