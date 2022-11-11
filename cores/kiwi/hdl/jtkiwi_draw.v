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

module jtkiwi_draw(
    input               rst,
    input               clk,

    input               draw,
    output reg          busy,
    input      [15:0]   code,
    input      [15:0]   attr,
    input      [ 8:0]   xpos,
    input      [ 3:0]   ysub,

    output     [19:2]   rom_addr,
    output              rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    output reg [ 8:0]   buf_addr,
    output              buf_we,
    output     [ 8:0]   buf_din
);

reg  [31:0] pxl_data;
reg         rom_lsb;
reg  [ 3:0] cnt;
wire [ 4:0] pal;
wire [ 3:0] ysubf;
wire        hflip, vflip;

assign ysubf    = ysub^{4{~vflip}};
assign buf_din  = { pal, hflip ?
    { pxl_data[31], pxl_data[23], pxl_data[15], pxl_data[7] } :
    { pxl_data[24], pxl_data[16], pxl_data[8], pxl_data[0] } };
assign rom_addr = { code[12:0], ysubf[3], rom_lsb, ysubf[2:0] };
assign { hflip, vflip, pal } = attr[15:9];
assign buf_we   = busy;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs   <= 0;
        buf_addr <= 0;
        pxl_data <= 0;
        busy     <= 0;
        cnt      <= 0;
    end else begin
        if( !busy ) begin
            if( draw ) begin
                rom_lsb  <= hflip; // 14+4 = 18 (+2=20)
                rom_cs   <= 1;
                buf_addr <= xpos;
                busy     <= 1;
                cnt      <= 8;
            end
        end else begin
            if( rom_ok && rom_cs && cnt[3]) begin
                pxl_data <= rom_data;
                cnt[3]   <= 0;
                if( rom_lsb^hflip ) begin
                    rom_cs <= 0;
                end else begin
                    rom_cs <= 1;
                end
            end
            if( !cnt[3] ) begin
                cnt      <= cnt+1'd1;
                buf_addr <= buf_addr+1'd1;
                pxl_data <= hflip ? pxl_data << 1 : pxl_data >> 1;
                rom_lsb  <= ~hflip;
                if( cnt[2:0]==7 && !rom_cs ) busy <= 0;
            end
        end
    end
end

endmodule