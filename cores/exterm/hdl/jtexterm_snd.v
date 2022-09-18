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

module jtexterm_snd(
    input               rst,
    input               clk,
    input               cen6,
    input               cen1p5,

    input               LVBL,

    // Cabinet inputs
    input      [ 1:0]   start_button,
    input      [ 1:0]   coin_input,
    input      [ 6:0]   joystick1,
    input      [ 6:0]   joystick2,

    // ROM interface
    output reg [15:0]   rom_addr,
    output reg          rom_cs,
    input               rom_ok,
    input      [ 7:0]   rom_data,

    // Sub CPU (sound)
    input               snd_rstn,
    //      access to RAM
    output     [12:0]   ram_addr,
    output     [ 7:0]   ram_din,
    output              ram_we,
    input      [ 7:0]   ram_dout,

    // DIP switches
    input               dip_pause,
    input               service,
    input      [15:0]   dipsw,

    // Sound output
    output signed [15:0] snd,
    output               sample,
    output               peak
);

localparam [7:0] PSG_GAIN = 8'h10,
                 FM_GAIN  = 8'h10;

wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n,
            fmint_n;
reg  [ 7:0] din, cab_dout;
wire [ 7:0] fm_dout, dout;
reg  [ 1:0] bank;
wire [15:0] A;
wire [ 9:0] psg_snd;
reg         ram_cs, bank_cs, fm_cs, cab_cs,
            mcu_rst;
wire signed [15:0] fm_snd;

assign ram_din  = dout;
assign ram_we   = ~wr_n;
assign ram_addr = A[12:0];

assign irq_ack = /*!m1_n &&*/ !iorq_n; // The original PCB just uses iorq_n,
    // the orthodox way to do it is to use m1_n too

always @* begin
    rom_addr = { 1'b0, A[14:0] };
    if( A[15] ) begin
        rom_addr[15:13] = { 1'b1, bank };
    end
end

always @(posedge clk) begin
    rom_cs  <= !mreq_n && A[15:12]  < 4'ha;
    bank_cs <= !mreq_n && A[15:12] == 4'ha;
    fm_cs   <= !mreq_n && A[15:12] == 4'hb;
    ram_cs  <= !mreq_n && A[15:13] == 3'b110; // C,D
    cab_cs  <= !mreq_n && A[15:12] == 4'hf;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank    <= 0;
        mcu_rst <= 0;
    end else begin
        if( bank_cs ) begin
            bank    <= dout[1:0];
            mcu_rst <= dout[2];
        end
    end
end

always @(posedge clk) begin
    case( A[2:0] )
        0: cab_dout <= { start_button[0], joystick1 };
        1: cab_dout <= { start_button[1], joystick2 };
        2: cab_dout <= { 6'h3f, 1'b1 /*tilt*/, service };
        3: cab_dout <= { 7'h7f, ~coin_input[0] };
        4: cab_dout <= { 7'h7f, ~coin_input[1] };
        default: cab_dout <= 8'hff;
    endcase
    din <= rom_cs ? rom_data :
           ram_cs ? ram_dout :
           fm_cs  ? fm_dout  :
           cab_cs ? cab_dout : 8'hff;
end

jtframe_ff u_irq(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( int_n     ),
    .set    ( 1'b0      ),
    .clr    ( irq_ack   ),
    .sigedge( ~LVBL     )
);

jtframe_z80_devwait u_gamecpu(
    .rst_n    ( ~rst           ),
    .clk      ( clk            ),
    .cen      ( cen6           ),
    .cpu_cen  (                ),
    .int_n    ( int_n          ),
    .nmi_n    ( fmint_n        ),
    .busrq_n  ( 1'b1           ),
    .m1_n     ( m1_n           ),
    .mreq_n   ( mreq_n         ),
    .iorq_n   ( iorq_n         ),
    .rd_n     ( rd_n           ),
    .wr_n     ( wr_n           ),
    .rfsh_n   (                ),
    .halt_n   (                ),
    .busak_n  (                ),
    .A        ( A              ),
    .din      ( din            ),
    .dout     ( dout           ),
    .rom_cs   ( rom_cs         ),
    .rom_ok   ( rom_ok         ),
    .dev_busy ( 1'b0           ) // TODO: add bus contention
);

jt03 u_2203(
    .rst        ( ~snd_rstn  ),
    .clk        ( clk        ),
    .cen        ( cen1p5     ),
    .din        ( dout       ),
    .dout       ( fm_dout    ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm_cs     ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg_snd    ),
    .fm_snd     ( fm_snd     ),
    .snd_sample ( sample     ),
    .irq_n      ( fmint_n    ),
    // IO ports
    .IOA_in     ( dipsw[ 7:0]),
    .IOB_in     ( dipsw[15:8]),
    // unused outputs
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            )
);

jtframe_mixer #(.W1(10)) u_mixer(
    .rst    ( rst          ),
    .clk    ( clk          ),
    .cen    ( cen3         ),
    .ch0    ( fm0_snd      ),
    .ch1    ( psg_snd      ),
    .ch2    ( 16'd0        ),
    .ch3    ( 16'd0        ),
    .gain0  ( FM_GAIN      ), // YM2203
    .gain1  ( PSG_GAIN     ), // PSG
    .gain2  ( 8'd0         ),
    .gain3  ( 8'd0         ),
    .mixed  ( snd          ),
    .peak   ( peak         )
);

endmodule