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
    input               vctrl_cs,
    output     [ 7:0]   cpu_din,

    // SDRAM interface
    output     [19:0]   rom_addr,
    input      [31:0]   rom_data,
    input               rom_ok,
    output              rom_cs,
    output     [ 8:0]   col_addr
);

wire        vram_we, vctrl_we;
reg  [12:0] scan_addr;
reg  [10:0] ctrl_addr;
wire [ 7:0] scan_dout, attr2cpu, vram2cpu;
reg  [ 5:0] col;
reg  [ 7:0] attr, xpos, ypos;
reg         scan_cen, done, dr_start, dr_busy,
            match, xflip, yflip;
reg  [ 2:0] st;
reg  [13:0] code;

assign vram_we  = vram_cs  & ~cpu_rnw;
assign vctrl_we = vctrl_cs & ~cpu_rnw;
assign rom_cs = 0;
assign rom_addr = 0;
assign col_addr = 0;
assign flip = 0;
assign cpu_din = vctrl_cs ? attr2cpu : vram2cpu;

// always @* begin
//     case( st )
//         0: ctrl_addr = { 1'b1, }
//     endcase
// end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_cen <= 0;
        done     <= 0;
    end else begin
        scan_cen <= ~scan_cen;
        dr_start <= 0;
        if( hs ) begin
            st  <= 0;
            col <= 0;
            done  <= 0;
        end else if(scan_cen && !done) begin
            case( st )
                0: begin
                    ypos <= scan_dout + vdump[7:0];
                end
                1: begin
                    if( !match ) st <= 7;
                    xpos <= scan_dout;
                end
                2: code[7:0] <= scan_dout;
                3: { xflip, yflip, code[13:8] } <= scan_dout;
                4: attr <= scan_dout;
                5: begin
                    if( dr_busy ) st <= 5;
                    dr_start <= 1;
                end
                default: begin
                    col   <= col+1;
                    done  <= &col;
                    st    <= 0;
                end
            endcase
        end
    end
end

// This seems to be time multiplexed with no bus contention
jtframe_dual_ram #(.aw(13)) u_vram(
    .clk0   ( clk        ),
    .clk1   ( clk_cpu    ),
    // Main CPU
    .addr0  ( cpu_addr   ),
    .data0  ( cpu_dout   ),
    .we0    ( vram_we    ),
    .q0     ( vram2cpu   ),
    // GFX
    .addr1  ( scan_addr  ),
    .data1  ( 8'd0       ),
    .we1    ( 1'd0       ),
    .q1     ( scan_dout  )
);

jtframe_dual_ram #(.aw(10)) u_attr(
    .clk0   ( clk        ),
    .clk1   ( clk_cpu    ),
    // Main CPU
    .addr0  ( cpu_addr   ),
    .data0  ( cpu_dout   ),
    .we0    ( vctrl_we   ),
    .q0     ( attr2cpu   ),
    // GFX
    .addr1  ( ctrl_addr  ),
    .data1  ( 8'd0       ),
    .we1    ( 1'd0       ),
    .q1     ( ctrl_dout  )
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