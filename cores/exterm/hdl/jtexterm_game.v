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
    Date: 02-05-2020 */

module jtexterm_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [4:0]  red,
    output   [4:0]  green,
    output   [4:0]  blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 6:0]  joystick1,
    input   [ 6:0]  joystick2,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel,
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Memory interface
    output          main_cs,
    output          sub_cs,
    output          gfx_cs,
    input           main_ok,
    input           sub_ok,
    input           gfx_ok,
    input    [ 7:0] main_data,
    input    [ 7:0] sub_data,
    input    [31:0] gfx_data,
    output   [19:0] gfx_addr,
    output   [16:0] main_addr,
    output   [15:0] sub_addr,
    // Debug
    input   [ 3:0]  gfx_en
);

wire        shr_we, snd_rstn;
wire [ 7:0] shr_din, shr_dout,
            vram_dout, pal_dout, cpu_dout;
wire [12:0] shr_addr, cpu_addr;
wire        cen6, cen3, cen1p5;

wire        vram_cs,  pal_cs, flip;
wire        cpu_rnw, vctrl_cs;

assign dip_flip   = flip;

jtframe_frac_cen #(.WC(4),.W(3)) u_cen24(
    .clk    ( clk24     ),    // 24 MHz
    .n      ( 4'd1      ),
    .m      ( 4'd4      ),
    .cen    ( { cen1p5, cen3, cen6 } ),
    .cenb   (           )
);

`ifndef NOMAIN
jtexterm_main u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),        // 24 MHz
    .cen6           ( cen6          ),

    .LVBL           ( LVBL          ),
    // Main CPU ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    .rom_data       ( main_data     ),

    // Sub CPU access to shared RAM
    .shr_addr       ( shr_addr      ),
    .shr_dout       ( shr_dout      ),
    .shr_we         ( shr_we        ),
    .shr_din        ( shr_din       ),
    // Sound
    .snd_rstn       ( snd_rstn      ),

    // Video
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vctrl_cs       ( vctrl_cs      ),
    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),

    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),
    .dip_pause      ( dip_pause     )
);
`else
    assign main_cs = 0;
    assign cpu_rnw = 1;
    assign vram_cs = 0;
    assign pal_cs  = 0;
    assign cpu_cen = 0;
`endif

jtexterm_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_cpu        ( clk24         ),

    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( flip          ),
    // PROMs
    // .prom_we        ( prom_we       ),
    // .prog_addr      ( prog_addr[7:0]),
    // .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),

    .vram_cs        ( vram_cs       ),
    .vctrl_cs       ( vctrl_cs      ),
    .vram_dout      ( vram_dout     ),

    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),
    // SDRAM
    .rom_addr       ( gfx_addr      ),
    .rom_data       ( gfx_data      ),
    .rom_ok         ( gfx_ok        ),
    .rom_cs         ( gfx_cs        ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        )
);

`ifndef NOSOUND
jtexterm_snd u_sound(
    .rst        ( rst24         ),
    .clk        ( clk24         ), // 24 MHz
    .snd_rstn   ( snd_rstn      ),
    .cen6       ( cen6          ),
    .cen1p5     ( cen1p5        ),
    .LVBL       ( LVBL          ),

    // cabinet I/O
    .start_button( start_button ),
    .coin_input ( coin_input    ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .service    ( service       ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw      ( dipsw[15:0]   ),

    // Shared RAM
    .ram_addr   ( shr_addr      ),
    .ram_din    ( shr_din       ),
    .ram_dout   ( shr_dout      ),
    .ram_we     ( shr_we        ),

    // ROM
    .rom_addr   ( sub_addr      ),
    .rom_cs     ( sub_cs        ),
    .rom_data   ( sub_data      ),
    .rom_ok     ( sub_ok        ),

    // Sound output
    .snd        ( snd           ),
    .sample     ( sample        ),
    .peak       ( game_led      )
);
`else
assign snd_cs   = 0;
assign snd_addr = 15'd0;
assign snd      = 16'd0;
assign sample   = 0;
assign snd_flag = 0;
assign main_stb = 0;
`endif

endmodule