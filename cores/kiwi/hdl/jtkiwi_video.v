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

module jtkiwi_video(
    input               rst,
    input               clk,
    input               clk_cpu,
    output              pxl2_cen,
    output              pxl_cen,

    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    output              flip,
    // PROMs
    // input      [ 7:0]   prog_addr,
    // input      [ 3:0]   prog_data,
    // input               prom_we,
    // CPU      interface
    input               pal_cs,
    output     [ 7:0]   pal_dout,
    input               cpu_rnw,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    input               vram_cs,
    input               vctrl_cs,
    output     [ 7:0]   vram_dout,
    // SDRAM interface
    output     [19:2]   scr_addr,
    input      [31:0]   scr_data,
    input               scr_ok,
    output              scr_cs,

    output     [19:2]   obj_addr,
    input      [31:0]   obj_data,
    input               obj_ok,
    output              obj_cs,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // Test
    input      [ 3:0]   gfx_en
);

wire [ 8:0] vrender, vrender1, vdump, hdump;
wire [ 8:0] scr_pxl, obj_pxl;

jtframe_frac_cen #(.WC(4),.W(2)) u_cen48(
    .clk    ( clk       ),    // 48 MHz
    .n      ( 4'd1      ),
    .m      ( 4'd8      ),
    .cen    ( { pxl_cen, pxl2_cen } ),
    .cenb   (           )
);

jtframe_vtimer #(
    .HB_START( 9'd255 ),
    .HS_START( 9'd297 ),
    .HB_END  ( 9'd383 ),
    .V_START ( 9'd016 ),
    .VS_START( 9'd254 ),
    .VB_START( 9'd239 ),
    .VB_END  ( 9'd279 )
) u_timer(
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .vdump      ( vdump      ),
    .vrender    ( vrender    ),
    .vrender1   ( vrender1   ),
    .H          ( hdump      ),
    .Hinit      (            ),
    .Vinit      (            ),
    .LHBL       ( LHBL       ),
    .LVBL       ( LVBL       ),
    .HS         ( HS         ),
    .VS         ( VS         )
);

jtkiwi_gfx u_gfx(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    .pxl2_cen   ( pxl2_cen       ),
    // PROMs
    // .prog_addr  ( prog_addr      ),
    // .prog_data  ( prog_data      ),
    // .prom_we    ( prom_we        ),
    // Screen
    .flip       ( flip           ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .vs         ( VS             ),
    .hs         ( HS             ),
    .vdump      ( vdump          ),
    .vrender    ( vrender        ),
    .hdump      ( hdump          ),
    // CPU interface
    .vram_cs    ( vram_cs        ),
    .vctrl_cs   ( vctrl_cs       ),
    .cpu_din    ( vram_dout      ),
    .cpu_addr   ( cpu_addr       ),
    .cpu_rnw    ( cpu_rnw        ),
    .cpu_dout   ( cpu_dout       ),
    // SDRAM
    .scr_addr   ( scr_addr       ),
    .scr_data   ( scr_data       ),
    .scr_ok     ( scr_ok         ),
    .scr_cs     ( scr_cs         ),

    .obj_addr   ( obj_addr       ),
    .obj_data   ( obj_data       ),
    .obj_ok     ( obj_ok         ),
    .obj_cs     ( obj_cs         ),
    // Color address to palette
    .scr_pxl    ( scr_pxl        )
);

jtkiwi_colmix u_colmix(
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    // Screen
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    // CPU interface
    .cpu_addr   ( cpu_addr[9:0]  ),
    .cpu_rnw    ( cpu_rnw        ),
    .cpu_dout   ( cpu_dout       ),
    .cpu_din    ( pal_dout       ),
    .pal_cs     ( pal_cs         ),
    // Colour output
    .col_addr   ( scr_pxl        ),
    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           )
);

endmodule
