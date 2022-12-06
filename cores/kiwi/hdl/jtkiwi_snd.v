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

module jtkiwi_snd(
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
    output              cpu_rnw,
    output reg          ram_cs,
    input      [ 7:0]   ram_dout,
    input               mshramen,

    // DIP switches
    input               dip_pause,
    input               service,
    input      [15:0]   dipsw,

    // Sound output
    output signed [15:0] snd,
    output               sample,
    output               peak
);
`ifndef NOSOUND
localparam [7:0] PSG_GAIN = 8'h10,
                 FM_GAIN  = 8'h10;

wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n,
            fmint_n, int_n, rfsh_n;
reg  [ 7:0] din, cab_dout;
wire [ 7:0] fm_dout, dout;
reg  [ 1:0] bank;
wire [15:0] A;
wire [ 9:0] psg_snd;
reg         bank_cs, fm_cs, cab_cs,
            dev_busy, fm_busy, fmcs_l,
            mcu_rst, comb_rstn=0;
wire signed [15:0] fm_snd;
wire        mem_acc;

`ifdef SIMULATION
wire shared_rd = ram_cs && !A[0] && !rd_n;
wire shared_wr = ram_cs && !A[0] && !wr_n;
`endif

assign mem_acc  = ~mreq_n & rfsh_n;
assign ram_din  = dout;
assign ram_addr = A[12:0];
assign cpu_rnw  = wr_n;

assign irq_ack = /*!m1_n &&*/ !iorq_n; // The original PCB just uses iorq_n,
    // the orthodox way to do it is to use m1_n too

always @* begin
    rom_addr = A;
    if( A[15] ) begin // Bank access
        rom_addr[14:13] = bank;
    end
end

always @* begin
    dev_busy = mshramen & ram_cs | fm_busy;
end

always @(posedge clk) begin
    comb_rstn <= snd_rstn & ~rst;
    if( cen6 ) begin
        fmcs_l <= fm_cs;
        fm_busy <= fm_cs & ~fmcs_l;
    end
end

always @(posedge clk) begin
    rom_cs  <= mem_acc &&  A[15:12]  < 4'ha;
    bank_cs <= mem_acc &&  A[15:12] == 4'ha; // this cleans the watchdog counter - not implemented
    fm_cs   <= mem_acc &&  A[15:12] == 4'hb;
    cab_cs  <= mem_acc &&  A[15:12] == 4'hc;
    ram_cs  <= mem_acc && (A[15:12] == 4'hd || A[15:12] == 4'he);
end

always @(posedge clk, negedge comb_rstn) begin
    if( !comb_rstn ) begin
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
        2: cab_dout <= { 4'hf, coin_input, 1'b1 /*tilt*/, service };
        // 3: cab_dout <= { 7'h7f, ~coin_input[0] };
        // 4: cab_dout <= { 7'h7f, ~coin_input[1] };
        default: cab_dout <= 8'h00;
    endcase
    din <= rom_cs ? rom_data :
           ram_cs ? ram_dout :
           fm_cs  ? fm_dout  :
           cab_cs ? cab_dout : 8'h00;
end

`ifdef SIMULATION
    integer line_cnt=1;

    always @(negedge ram_cs, posedge rst) begin
        if( rst )
            line_cnt <= 1;
        else
            line_cnt <= line_cnt+1;
    end
`endif

jtframe_ff u_irq(
    .clk    ( clk       ),
    .rst    ( ~comb_rstn),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( int_n     ),
    .set    ( 1'b0      ),
    .clr    ( irq_ack   ),
    .sigedge( ~LVBL     )
);

jtframe_z80_devwait u_gamecpu(
    .rst_n    ( comb_rstn      ),
    .clk      ( clk            ),
    .cen      ( cen6           ),
    .cpu_cen  (                ),
`ifdef NOINT
    .int_n    ( 1'b1           ),
    .nmi_n    ( 1'b1           ),
`else
    .int_n    ( int_n          ),
    .nmi_n    ( fmint_n        ),
`endif
    .busrq_n  ( 1'b1           ),
    .m1_n     ( m1_n           ),
    .mreq_n   ( mreq_n         ),
    .iorq_n   ( iorq_n         ),
    .rd_n     ( rd_n           ),
    .wr_n     ( wr_n           ),
    .rfsh_n   ( rfsh_n         ),
    .halt_n   (                ),
    .busak_n  (                ),
    .A        ( A              ),
    .din      ( din            ),
    .dout     ( dout           ),
    .rom_cs   ( rom_cs         ),
    .rom_ok   ( rom_ok         ),
    .dev_busy ( dev_busy       )
);

`ifndef VERILATOR_KEEP_JT03
/* verilator tracing_off */
`endif
jt03 u_2203(
    .rst        ( ~comb_rstn ),
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
    .snd        (            ),
    .debug_view (            )
);

jtframe_mixer #(.W1(10)) u_mixer(
    .rst    ( rst          ),
    .clk    ( clk          ),
    .cen    ( cen1p5       ),
    .ch0    ( fm_snd       ),
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
/* verilator tracing_on */

`else
    initial begin
        rom_addr = 0;
        rom_cs   = 0;
        $display("WARNING: without the sound CPU, the main CPU won't work correctly");
    end
    assign ram_addr = 0;
    assign ram_din  = 0;
    initial ram_cs  = 0;
    assign cpu_rnw  = 1;
    assign snd      = 0;
    assign sample   = 0;
    assign peak     = 0;
`endif
endmodule