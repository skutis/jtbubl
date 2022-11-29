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

// This is object processor section of the SETA chip

module jtkiwi_obj(
    input               rst,
    input               clk,
    input               lut_cen,
    input               pxl_cen,

    input               hs,
    input               flip,
    input               page,

    output     [11:0]   lut_addr,
    input      [15:0]   lut_data,

    output     [ 8:0]   y_addr,
    input      [ 7:0]   y_data,

    output     [19:2]   rom_addr,
    output              rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    input      [ 8:0]   vrender,
    input      [ 8:0]   hdump,
    output     [ 8:0]   pxl,

    input      [ 7:0]   debug_bus
);

reg         done;
reg  [ 8:0] objcnt;
reg  [ 4:0] pal;
reg  [ 3:0] dr_ysub, ysub;
reg  [ 8:0] ydiff, dr_xpos;
reg  [ 8:0] xpos;
wire [ 8:0] vf;
reg  [ 1:0] st;
reg         dr_draw, match, vflip, hflip;
reg  [15:0] code, dr_code, dr_attr;
wire        dr_busy;
wire [ 8:0] buf_din, buf_addr;
wire        buf_we;

assign lut_addr = { page, 1'b0, st[1], objcnt }; // 1 + 1 + 1 + 9 = 12
assign y_addr   = objcnt;
assign vf       = {9{flip}} ^ vrender;

always @* begin
    ydiff = { 1'b0, vf[7:0] } - {1'b0, y_data };
    match = ydiff[8:4]==0;
end

// Columns are 32-pixel wide
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st      <= 0;
        objcnt  <= 0;
        dr_draw <= 0;
        dr_code <= 0;
        dr_attr <= 0;
        dr_xpos <= 0;
        dr_ysub <= 0;
    end else begin
        dr_draw <= 0;
        if( hs || vrender>9'hf0 ) begin
            objcnt  <= 0;
            done    <= 0;
            st      <= 0;
            dr_draw <= 0;
            dr_code <= 0;
            dr_attr <= 0;
            dr_xpos <= 0;
            dr_ysub <= 0;
        end else if( !done && lut_cen ) begin
            st <= st + 1'd1;
            case( st )
                0: begin
                    ysub <= ydiff[3:0];
                    if( !match ) begin
                        objcnt <= objcnt + 1'd1;
                        st     <= 0;
                        done   <= &objcnt;
                    end
                end
                1: { pal, code[15:14], xpos } <= lut_data;
                2: { vflip, hflip, code[13:0] } <= lut_data;
                3: begin
                    if( !dr_busy )  begin
                        dr_draw <= 1;
                        dr_code <= code;
                        dr_attr <= { vflip, hflip, pal, 9'd0 };
                        dr_xpos <= xpos ^ 9'h100;
                        dr_ysub <= ysub;
                        objcnt <=  objcnt + 1'd1;
                        done    <= &objcnt;
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

jtframe_obj_buffer #(.DW(9)) u_linebuf(
    .clk    ( clk       ),
    .flip   ( flip      ),
    .LHBL   ( ~hs       ),
    // New line writting
    .we     ( buf_we    ),
    .wr_data( buf_din   ),
    .wr_addr( buf_addr  ),
    // Previous line reading
    .rd     ( pxl_cen   ),
    .rd_addr( hdump     ),
    .rd_data( pxl       )
);


endmodule