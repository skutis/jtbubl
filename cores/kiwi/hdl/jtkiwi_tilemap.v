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
    Date: 7-11-2022 */

// This is tile map section of the SETA chip
// This one uses an independent line buffer
// from that of the sprites

module jtkiwi_tilemap(
    input               rst,
    input               clk,
    input               tm_cen,

    input               hs,
    input               flip,
    input               page,
    input      [15:0]   col_xmsb,
    input      [ 3:0]   col_cfg,
    input      [ 1:0]   col0,

    output     [11:0]   tm_addr,
    input      [15:0]   tm_data,

    // Column scroll
    output     [ 7:0]   col_addr,
    input      [ 7:0]   col_data,

    output     [19:2]   rom_addr,
    output              rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    input      [ 8:0]   vrender,
    input      [ 8:0]   hdump,
    output     [ 8:0]   pxl,

    input      [ 7:0]   debug_bus
);

reg         line, done, hsl;
reg  [ 4:0] col_cnt;
reg  [ 3:0] dr_ysub, col_end;
reg  [ 8:0] eff_h, eff_v, dr_xpos;
reg  [ 7:0] yscr;
reg  [ 8:0] xscr;
wire [ 8:0] vf;
reg  [ 1:0] st;
reg         dr_draw;
reg  [15:0] code, dr_code, dr_attr;
wire        dr_busy;
wire [ 8:0] buf_din, buf_addr;
wire        buf_we;

assign tm_addr  = { page, 1'b1, st[0], eff_h[8:5], eff_v[7:4], eff_h[4] }; // 1 + 1 + 1 + 4 + 5 = 12
assign col_addr = { col_cnt[4:1], 1'd0, st[0], 2'd0 };
assign vf       = {9{flip}} ^ vrender;

always @* begin
    eff_v = vf + { 1'b0, yscr };
    eff_h = { col_cnt + {col0,3'd0}, 4'b0 };
end

// Columns are 32-pixel wide
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        col_cnt <= 0;
        line    <= 0;
        hsl     <= 0;
    end else begin
        hsl <= hs;
        dr_draw <= 0;
        if ( hs & ~hsl ) line <= ~line;
        if( hs || (vrender>9'hf0 && vrender<9'h116) || col_cfg==0 ) begin
            col_cnt <= 0;
            done    <= col_cfg==0; // don't do anything for col_cfg==0
            st      <= 0;
            dr_draw <= 0;
            dr_code <= 0;
            dr_attr <= 0;
            dr_xpos <= 0;
            dr_ysub <= 0;
            col_end <= col_cfg==1 ? 4'hf : col_cfg-4'd1;
        end else if( !done && tm_cen ) begin
            st <= st + 1'd1;
            case( st )
                0: yscr <= col_data;
                1: xscr <= { col_xmsb[col_cnt[4:1]], col_data };
                2: code <= tm_data;
                3: begin
                    if( !dr_busy )  begin
                        dr_draw <= 1;
                        dr_code <= code;
                        dr_attr <= tm_data ^ 16'hc000;
                        dr_xpos <= { 4'd0, col_cnt[0], 4'd0 } + xscr;
                        dr_ysub <= eff_v[3:0];
                        col_cnt <=  col_cnt + 1'd1;
                        done    <= col_cnt[4:1]==col_end && col_cnt[0];
                    end else begin
                        st <= st;
                    end
                end
            endcase
        end
    end
end

jtkiwi_draw u_draw(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .draw       ( dr_draw       ),
    .busy       ( dr_busy       ),
    .code       ( dr_code       ),
    .attr       ( dr_attr       ),
    .xpos       ( dr_xpos       ),
    .ysub       ( dr_ysub       ),
    .flip       ( flip          ),

    .rom_addr   ( rom_addr      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .rom_data   ( rom_data      ),

    .buf_addr   ( buf_addr      ),
    .buf_we     ( buf_we        ),
    .buf_din    ( buf_din       ),
    .debug_bus  ( debug_bus     )
);

// During HS the contents of the memory are cleared
wire [8:0] mux_din  = hs ? 9'd0  : buf_din;
wire [8:0] mux_addr = hs ? hdump : buf_addr;
wire       mux_we   = hs ? 1'b1  : buf_we;

jtframe_dual_ram #(.aw(10),.dw(9)) u_linebuf(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // New line writting
    .data0  ( mux_din   ),
    .addr0  ( { line, mux_addr}  ),
    .we0    ( mux_we    ),
    .q0     (           ),
    // Previous line reading
    .data1  ( 9'd0      ),
    .we1    ( 1'b0      ),
    .addr1  ( {~line, hdump } ),
    .q1     ( pxl       )
);


endmodule