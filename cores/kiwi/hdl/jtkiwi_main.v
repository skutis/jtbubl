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

module jtkiwi_main(
    input               rst,
    input               clk,
    input               cen6,
    input               LVBL,

    // Video devices
    output reg          vram_cs,
    output reg          vctrl_cs,
    output reg          pal_cs,
    input      [ 7:0]   pal_dout,
    input      [ 7:0]   vram_dout,

    output     [12:0]   cpu_addr,
    output     [ 7:0]   cpu_dout,
    output              cpu_rnw,

    // Sub CPU (sound)
    output reg          snd_rstn,
    //      access to RAM
    input      [12:0]   shr_addr,
    input      [ 7:0]   shr_din,
    input               shr_we,
    output     [ 7:0]   shr_dout,

    // DIP switches
    input               dip_pause,

    // ROM interface
    output reg [16:0]   rom_addr,
    output reg          rom_cs,
    input               rom_ok,
    input      [ 7:0]   rom_data
);
`ifndef NOMAIN
wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n,
            int_n, ram_we;
reg  [ 7:0] din;
wire [ 7:0] dout, ram_dout;
reg  [ 2:0] bank;
wire [15:0] A;
reg         ram_cs, bank_cs;
wire        Af;

assign cpu_rnw = wr_n;
assign cpu_addr = A[12:0];
assign cpu_dout = dout;
assign irq_ack = /*!m1_n &&*/ !iorq_n; // The original PCB just uses iorq_n,
    // the orthodox way to do it is to use m1_n too
assign ram_we  = ram_cs & ~wr_n;

always @* begin
    rom_addr = { 2'b0, A[14:0] };
    if( A[15] ) begin
        rom_addr[16:13] = 4'b100 + bank;
    end
end

always @(posedge clk) begin
    rom_cs   <= !mreq_n && A[15:12]  < 4'hc;
    vram_cs  <= !mreq_n && A[15:13] == 3'b110; // C,D
    ram_cs   <= !mreq_n && A[15:12] == 4'he; // A[12:0] used in Insector X (?)
    vctrl_cs <= !mreq_n && A[15:12] == 4'hf && A[11:8]<=3; // internal RAM and config registers
    bank_cs  <= !mreq_n && A[15: 8] == 8'hf6 && !wr_n;
    pal_cs   <= !mreq_n && A[15: 8] == 8'hf8;
end

always @(posedge clk) begin
    din <= rom_cs  ? rom_data  :
           ram_cs  ? ram_dout  :
           (vram_cs | vctrl_cs) ? vram_dout :
           pal_cs  ? pal_dout  : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank     <= 0;
        snd_rstn <= 0;
    end else begin
        if( bank_cs ) begin
            bank <= dout[2:0];
            snd_rstn <= dout[4];
        end
    end
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

// To do: add dev_busy to match the wait signal
// when accessing the VRAM
jtframe_z80_devwait u_gamecpu(
    .rst_n    ( ~rst   ),
    .clk      ( clk    ),
    .cen      ( cen6   ),
    .cpu_cen  (        ),
    .int_n    ( int_n  ),
    .nmi_n    ( 1'b1   ),
    .busrq_n  ( 1'b1   ),
    .m1_n     ( m1_n   ),
    .mreq_n   ( mreq_n ),
    .iorq_n   ( iorq_n ),
    .rd_n     ( rd_n   ),
    .wr_n     ( wr_n   ),
    .rfsh_n   (        ),
    .halt_n   (        ),
    .busak_n  (        ),
    .A        ( A      ),
    .din      ( din    ),
    .dout     ( dout   ),
    .rom_cs   ( rom_cs ),
    .rom_ok   ( rom_ok ),
    .dev_busy ( 1'b0   )
);

// first come, first served
// TODO: add bus contention
jtframe_dual_ram #(.aw(13)) u_comm(
    .clk0   ( clk        ),
    .clk1   ( clk        ),
    // Main CPU
    .addr0  ( A[12:0]    ),
    .data0  ( dout       ),
    .we0    ( ram_we     ),
    .q0     ( ram_dout   ),
    // MCU
    .addr1  ( shr_addr   ),
    .data1  ( shr_din    ),
    .we1    ( shr_we     ),
    .q1     ( shr_dout   )
);
`else
    initial begin
        rom_cs   = 0;
        rom_addr = 0;
        vram_cs  = 0;
        vctrl_cs = 0;
        pal_cs   = 0;
        snd_rstn = 0;
    end
    assign cpu_rnw  = 1;
    assign cpu_addr = 1;
    assign cpu_dout = 0;
    assign shr_dout = 0;
`endif
endmodule