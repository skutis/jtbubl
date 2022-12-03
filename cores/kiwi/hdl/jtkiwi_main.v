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
    output     [16:0]   rom_addr,
    output reg          rom_cs,
    input               rom_ok,
    input      [ 7:0]   rom_data,
    // Debug
    output     [ 7:0]   st_dout
);
`ifndef NOMAIN
wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n,
            rfsh_n, int_n, ram_we;
reg  [ 7:0] din;
wire [ 7:0] dout, ram_dout;
reg  [ 2:0] bank;
wire [15:0] A;
reg         ram_cs, bank_cs;
wire        mem_acc;

assign cpu_rnw  = wr_n;
assign cpu_addr = A[12:0];
assign cpu_dout = dout;
assign irq_ack  = /*!m1_n &&*/ !iorq_n; // The original PCB just uses iorq_n,
    // the orthodox way to do it is to use m1_n too
assign ram_we   = ram_cs & ~wr_n;
assign rom_addr = { {2{A[15]}} & bank[2:1], A[15] ? bank[0] : A[14], A[13:0] };
assign st_dout  = { 3'd0, ~snd_rstn, 1'd0, bank };
assign mem_acc  = ~mreq_n &rfsh_n;

`ifdef SIMULATION
wire rombank_cs = rom_cs && A[15:12]>=8;
`endif

always @(posedge clk) begin
    rom_cs   <= mem_acc && A[15:12]  < 4'hc;
    vram_cs  <= mem_acc && A[15:13] == 3'b110; // C,D
    ram_cs   <= mem_acc && A[15:12] == 4'he; // A[12:0] used in Insector X (?)
    vctrl_cs <= mem_acc && A[15:12] == 4'hf && A[11:8]<=4; // internal RAM and config registers
    bank_cs  <= mem_acc && A[15: 8] == 8'hf6 && !wr_n;
    pal_cs   <= mem_acc && A[15:12] == 4'hf && A[11:10]==2'b10;
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
`ifdef NOINT
    .int_n    ( 1'b1   ),
`else
    .int_n    ( int_n  ),
`endif
    .nmi_n    ( 1'b1   ),
    .busrq_n  ( 1'b1   ),
    .m1_n     ( m1_n   ),
    .mreq_n   ( mreq_n ),
    .iorq_n   ( iorq_n ),
    .rd_n     ( rd_n   ),
    .wr_n     ( wr_n   ),
    .rfsh_n   ( rfsh_n ),
    .halt_n   (        ),
    .busak_n  (        ),
    .A        ( A      ),
    .din      ( din    ),
    .dout     ( dout   ),
    .rom_cs   ( rom_cs ),
    .rom_ok   ( rom_ok ),
    .dev_busy ( 1'b0   )
);

always @(posedge clk) if(!mreq_n && cen6) begin
    // if( ram_we && A[12:0]==13'hcff ) $display("Written %x to %X",dout,A);
    if( A=='hec0a && cpu_rnw ) $display("Main reads %02X from %04X", din, A);
    if( ram_cs && !cpu_rnw && A=='hec0a ) $display("Main writing %02X to %04X", dout, A);
`ifdef NOINT
    if ( A==16'h206 && !m1_n ) begin
        $display("Reached main loop");
        $finish;
    end
`endif
end

// first come, first served
// TODO: add bus contention
jtframe_dual_ram #(.aw(13),.dumpfile("mainmem")) u_comm(
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
`ifdef JTFRAME_DUAL_RAM_DUMP
    ,.dump   ( LVBL       )
`endif
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