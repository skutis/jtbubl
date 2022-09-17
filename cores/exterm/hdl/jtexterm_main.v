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
    Date: 17-9-2022 */

module jtexterm_main(
    input               rst,
    input               clk24,
    input               cen6,
    input               LVBL,

    // Cabinet inputs
    input      [ 1:0]   start_button,
    input      [ 1:0]   coin_input,
    input      [ 5:0]   joystick1,
    input      [ 5:0]   joystick2,

    // Sound interface
    output reg          snd_rstn,

    // Video devices
    output reg          seta_cs,
    output reg          pal_cs,
    output     [ 7:0]   cpu_dout,
    output              cpu_wrn,

    // Main CPU ROM interface
    output     [17:0]   rom_addr,
    output reg          rom_cs,
    input               rom_ok,
    input      [ 7:0]   rom_data,

    // DIP switches
    input               dip_pause,
    input               service,
    input      [15:0]   dipsw
);

wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n;
reg  [ 7:0] cpu_din;
reg  [ 2:0] bank;
wire [15:0] A;
reg         ram_cs, bank_cs;

assign cpu_wrn = wr_n;
assign irq_ack = /*!m1_n &&*/ !iorq_n; // The original PCB just uses iorq_n,
    // the orthodox way to do it is to use m1_n too

always @(posedge clk) begin
    rom_cs  <= !mreq_n && A[15:12]<4'hc;
    ram_cs  <= !mreq_n && A[15:12]==4'he;
    bank_cs <= !mreq_n && A[15: 8]==8'hf6;
    pal_cs  <= !mreq_n && A[15: 8]==8'hf8;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank     <= 0;
        snd_rstn <= 0;
    end else begin
        if( bank_cs ) bank <= cpu_dout[2:0];
        snd_rstn <= cpu_dout[4];
    end
end

jtframe_ff u_irq(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( int_n     ),
    .set    ( 1'b0      ),    // active high
    .clr    ( irq_ack   ),    // active high
    .sigedge( ~LVBL     ) // signal whose edge will trigger the FF
);


jtframe_z80_devwait u_gamecpu(
    .rst_n    ( ~rst           ),
    .clk      ( clk24          ),
    .cen      ( cen6           ),
    .cpu_cen  (                ),
    .int_n    ( int_n          ),
    .nmi_n    ( 1'b1           ),
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
    .dev_busy ( 1'b0           )
);

// Time shared
jtframe_dual_ram #(.aw(10)) u_comm(
    .clk0   ( clk24              ),
    .clk1   ( clk24              ),
    // Main CPU
    .addr0  ( main_addr[9:0]     ),
    .data0  ( main_dout          ),
    .we0    ( mcram_we           ),
    .q0     ( comm2main          ),
    // MCU
    .addr1  ( mcu_bus[9:0]       ),
    .data1  ( rammcu_din         ),
    .we1    ( rammcu_we          ),
    .q1     ( comm2mcu           )
);


endmodule