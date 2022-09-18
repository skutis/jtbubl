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

module jtexterm_sdram(
    input           rst,
    input           clk,

    // Main CPU
    input            main_cs,
    input     [16:0] main_addr,
    output    [ 7:0] main_data,
    output           main_ok,

    // Sound CPU
    input            sub_cs,
    output           sub_ok,
    input     [15:0] sub_addr,
    output    [ 7:0] sub_data,

    // PCM ROM
    // input     [15:0] pcm_addr,
    // input            pcm_cs,
    // output    [ 7:0] pcm_data,
    // output           pcm_ok,

    // Scroll layers
    input            gfx_cs,
    output           gfx_ok,
    input    [19:0]  gfx_addr,  // 2 MB
    output   [31:0]  gfx_data,

    // Bank 0: allows R/W
    output    [21:0] ba0_addr,
    output    [21:0] ba1_addr,
    output    [21:0] ba2_addr,
    output    [21:0] ba3_addr,
    output    [ 3:0] ba_rd,
    input     [ 3:0] ba_ack,
    input     [ 3:0] ba_dst,
    input     [ 3:0] ba_dok,
    input     [ 3:0] ba_rdy,

    input     [15:0] data_read,

    // ROM LOAD
    input            downloading,
    output           dwnld_busy,

    input    [24:0]  ioctl_addr,
    input    [ 7:0]  ioctl_dout,
    input            ioctl_wr,
    output reg [21:0] prog_addr,
    output    [15:0] prog_data,
    output    [ 1:0] prog_mask,
    output    [ 1:0] prog_ba,
    output           prog_we,
    output           prog_rd,
    input            prog_ack,
    input            prog_rdy
);

/* verilator lint_off WIDTH */
localparam [24:0] BA1_START   = `BA1_START,
                  BA2_START   = `BA2_START,
                  BA3_START   = `BA3_START;

/* verilator lint_on WIDTH */

// wire [21:0] pre_addr;
// wire        is_tiles, is_obj;
wire prom_we;

assign dwnld_busy = downloading;
// assign is_tiles   = prog_ba==2 && ioctl_addr<SCR2_START;
// assign is_obj     = prog_ba==3 && !prom_we;

// always @* begin
//     prog_addr = pre_addr;
//     // moves the H address bit to the LSBs
//     if( is_tiles )
//         prog_addr[3:0] = { pre_addr[2:0], pre_addr[3] };
//     if( is_obj )
//         prog_addr[5:0] = { pre_addr[3:0], pre_addr[5:4] };
// end

jtframe_dwnld #(
    .BA1_START ( BA1_START ), // sub CPU
    .BA2_START ( BA2_START ), // audio CPU
    .BA3_START ( BA3_START ), // gfx
    .SWAB      ( 1         )
) u_dwnld(
    .clk          ( clk            ),
    .downloading  ( downloading    ),
    .ioctl_addr   ( ioctl_addr     ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .prog_addr    ( prog_addr      ),
    .prog_data    ( prog_data      ),
    .prog_mask    ( prog_mask      ), // active low
    .prog_we      ( prog_we        ),
    .prog_rd      ( prog_rd        ),
    .prog_ba      ( prog_ba        ),
    .prom_we      ( prom_we        ),
    .header       (                ),
    .sdram_ack    ( prog_ack       )
);

/* verilator tracing_off */
jtframe_rom_1slot #(
    .SLOT0_DW( 8),
    .SLOT0_AW(17)
) u_bank0(
    .rst         ( rst        ),
    .clk         ( clk        ),

    .slot0_addr  ( main_addr  ),
    .slot0_dout  ( main_data  ),
    .slot0_cs    ( main_cs    ),
    .slot0_ok    ( main_ok    ),

    // SDRAM controller interface
    .sdram_ack   ( ba_ack[0]  ),
    .sdram_req   ( ba_rd[0]   ),
    .sdram_addr  ( ba0_addr   ),
    .data_dst    ( ba_dst[0]  ),
    .data_rdy    ( ba_rdy[0]  ),
    .data_read   ( data_read  )
);

// Bank 1: sub CPU
jtframe_rom_1slot #(
    .SLOT0_DW(   8),
    .SLOT0_AW(  16)
) u_bank1(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( sub_addr  ),
    .slot0_dout ( sub_data  ),
    .slot0_cs   ( sub_cs    ),
    .slot0_ok   ( sub_ok    ),

    // SDRAM controller interface
    .sdram_addr ( ba1_addr  ),
    .sdram_req  ( ba_rd[1]  ),
    .sdram_ack  ( ba_ack[1] ),
    .data_dst   ( ba_dst[1] ),
    .data_rdy   ( ba_rdy[1] ),
    .data_read  ( data_read )
);

// Bank 2: sound CPU
// jtframe_rom_1slot #(
//     .SLOT0_DW(   8),
//     .SLOT0_AW(  16)
// ) u_bank2(
//     .rst        ( rst       ),
//     .clk        ( clk       ),

//     .slot0_addr ( sub_addr  ),
//     .slot0_dout ( sub_data  ),
//     .slot0_cs   ( sub_cs    ),
//     .slot0_ok   ( sub_ok    ),

//     // SDRAM controller interface
//     .sdram_addr ( ba2_addr  ),
//     .sdram_req  ( ba_rd[2]  ),
//     .sdram_ack  ( ba_ack[2] ),
//     .data_dst   ( ba_dst[2] ),
//     .data_rdy   ( ba_rdy[2] ),
//     .data_read  ( data_read )
// );
assign ba2_addr = 0;
assign ba_rd[2] = 0;

// Bank 3: graphics

jtframe_rom_1slot #(
    .SLOT0_DW   (  32        ),
    .SLOT0_AW   (  20        )
) u_bank3(
    .rst        ( rst        ),
    .clk        ( clk        ),

    .slot0_addr ( gfx_addr   ),
    .slot0_dout ( gfx_data   ),
    .slot0_cs   ( gfx_cs     ),
    .slot0_ok   ( gfx_ok     ),

    // SDRAM controller interface
    .sdram_addr ( ba3_addr   ),
    .sdram_req  ( ba_rd[3]   ),
    .sdram_ack  ( ba_ack[3]  ),
    .data_dst   ( ba_dst[3]  ),
    .data_rdy   ( ba_rdy[3]  ),
    .data_read  ( data_read  )
);
/* verilator tracing_on */
endmodule