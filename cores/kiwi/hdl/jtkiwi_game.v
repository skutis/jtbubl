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

module jtkiwi_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        sub_rnw, shr_cs, mshramen, snd_rstn;
wire [ 7:0] shr_din, shr_dout, main_st, gfx_st,
            vram_dout, pal_dout, cpu_dout;
wire [ 8:0] hdump;
wire [12:0] shr_addr, cpu_addr;
wire        cen6, cen3, cen1p5;

wire        vram_cs,  pal_cs, flip;
wire        cpu_rnw, vctrl_cs, vflag_cs;

assign  dip_flip   = flip;
always @* debug_view = gfx_st;
// main_st;

jtframe_frac_cen #(.WC(4),.W(3)) u_cen24(
    .clk    ( clk       ),    // 24 MHz
    .n      ( 4'd1      ),
    .m      ( 4'd8      ),
    .cen    ( { cen1p5, cen3, cen6 } ),
    .cenb   (           )
);

jtkiwi_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),

    .LVBL           ( LVBL          ),
    .hcnt           ( hdump         ),
    // Main CPU ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    .rom_data       ( main_data     ),

    // Sub CPU access to shared RAM
    .shr_addr       ( shr_addr      ),
    .shr_dout       ( shr_dout      ),
    .sub_rnw        ( sub_rnw       ),
    .shr_din        ( shr_din       ),
    .shr_cs         ( shr_cs        ),
    .mshramen       ( mshramen      ),
    // Sound
    .snd_rstn       ( snd_rstn      ),

    // Video
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vctrl_cs       ( vctrl_cs      ),
    .vram_cs        ( vram_cs       ),
    .vflag_cs       ( vflag_cs      ),
    .vram_dout      ( vram_dout     ),

    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),
    .dip_pause      ( dip_pause     ),
    .debug_bus      ( debug_bus     ),
    .st_dout        ( main_st       )
);

jtkiwi_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_cpu        ( clk           ),

    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( flip          ),
    .hdump          ( hdump         ),
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
    .vflag_cs       ( vflag_cs      ),
    .vram_dout      ( vram_dout     ),

    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),
    // SDRAM
    .scr_addr       ( scr_addr      ),
    .scr_data       ( scr_data      ),
    .scr_ok         ( scr_ok        ),
    .scr_cs         ( scr_cs        ),

    .obj_addr       ( obj_addr      ),
    .obj_data       ( obj_data      ),
    .obj_ok         ( obj_ok        ),
    .obj_cs         ( obj_cs        ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     ),
    .st_dout        ( gfx_st        )
);

jtkiwi_snd u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
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
    .dipsw      ( dipsw[15:0]   ),
    .dip_pause  ( dip_pause     ),

    // Shared RAM
    .ram_addr   ( shr_addr      ),
    .ram_din    ( shr_din       ),
    .ram_dout   ( shr_dout      ),
    .cpu_rnw    ( sub_rnw       ),
    .ram_cs     ( shr_cs        ),
    .mshramen   ( mshramen      ),

    // ROM
    .rom_addr   ( sub_addr      ),
    .rom_cs     ( sub_cs        ),
    .rom_data   ( sub_data      ),
    .rom_ok     ( sub_ok        ),

    // Sound output
    .fx_level   ( dip_fxlevel   ),
    .snd        ( snd           ),
    .sample     ( sample        ),
    .peak       ( game_led      )
);

endmodule