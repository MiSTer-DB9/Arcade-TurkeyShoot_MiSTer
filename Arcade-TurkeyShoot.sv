//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + per-pin push-pull mask, USER_IO widened to 8 bits
	output        USER_OSD,
	output  [7:0] USER_PP,
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,
	// [MiSTer-DB9 END]

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP driven by wrapper; USER_OUT driven by joydb (USER_OUT_DRIVE) below
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1      = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

//////////////////////////////////////////////////////////////////

assign LED_USER  = 0;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression (e.g. `mt32_use` under `ifndef SECOND_MT32`, `~mt32_disable` for
// TRS-80's inverted polarity). Suppresses the OSD-open autodetect probe so it
// doesn't read the RPi's I2C master traffic as a ghost Saturn signature.
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// Legacy 3-bit alias for fork-specific MT32 / SNAC fallback code. Non-canonical
// RHS variants (ext_iec_en, mt32_disable) need a hand-port — alias is raw.
wire   [2:0] JOY_FLAG        = {joy_db9md_en, joy_db15_en, joy_2p};
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;

// [MiSTer-DB9 BEGIN] - DB9 programmable-remap matrix wires
// joydb_*_mapped = MiSTer-standard joystick words (consumed in Layer B);
// db9_remap_* = 0xFD selector stream driven by the hps_io instance.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;
// [MiSTer-DB9 END]
joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_sys            ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd909 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd763 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.TURKEYSHOOT;;",
	"-;",
	"O[9:8],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[5:3],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O[10],Advance,Off,On;",
	"O[11],Auto Up,Off,On;",
	"O[12],High Score Reset,Off,On;",
	"-;",
	// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation; 1P-only)
	"O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
	// [MiSTer-DB9-Pro END]
	"R[0],Reset;",
	"J1,Fire,Grenade,Gobble,Start 1P,Start 2P,Coin;",
	"jn,A,B,X,Start,Select,R;",
	"V,v",`BUILD_DATE 
};

wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [ 7:0] ioctl_dout;
wire [15:0] ioctl_index;

wire [  1:0] buttons;
wire [127:0] status;
wire [ 10:0] ps2_key;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: rename USB joystick wire
wire [15:0] joystick_0_USB;
// [MiSTer-DB9 END]
// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open
wire [31:0] joy = joydb_1ena ? (OSD_STATUS ? 32'b0 : {joydb_1[11],joydb_1[9],joydb_1[10],joydb_1[6:0]}) : joystick_0_USB;
// [MiSTer-DB9-Pro END]

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.status(status),
	.status_menumask({direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0_USB),
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
	.joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
	// programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
	.db9_remap_cmd(db9_remap_cmd),
	.db9_remap_byte_cnt(db9_remap_byte_cnt),
	.db9_remap_din(db9_remap_din),
	// [MiSTer-DB9 END]
	// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
	.saturn_unlocked(saturn_unlocked)
	// [MiSTer-DB9-Pro END]
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire pll_locked;
wire clk_48,clk_12;
assign clk_sys = clk_12;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_48),
	.outclk_1(clk_12),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

// PLAYER INPUTS
wire m_right   = joy[0];
wire m_left    = joy[1];
wire m_down    = joy[2];
wire m_up      = joy[3];

wire m_trigger = joy[4];
wire m_grenade = joy[5];
wire m_gobble  = joy[6];

wire m_start1  = joy[7];
wire m_start2  = joy[8];
wire m_coin    = joy[9];

wire gun_update_r;
wire cnt_4ms;
wire left_r, right_r, up_r, down_r;
reg [4:0] div_h, div_v;
reg [5:0] gun_h, gun_v;

always @(posedge clk_12) begin : gunHV
	gun_update_r <= cnt_4ms;
	
	if ((gun_update_r == 1'b0) && (cnt_4ms == 1'b1)) begin
		left_r  <= m_left;
		right_r <= m_right;
		up_r    <= m_up;
		down_r  <= m_down;

		if ((((m_left == 1'b1) && (left_r == 1'b1)) || ((m_right == 1'b1) && (right_r == 1'b1))) && (div_h < 5'd3)) begin
			div_h <= div_h + 5'b1;
		end else begin
			div_h <= 5'b0;
		end
		if ((m_left == 1'b1) && (div_h == 5'd1) && (gun_h > 6'd0)) begin
			gun_h <= gun_h - 6'b1;
		end
		if ((m_right == 1'b1) && (div_h == 5'd1) && (gun_h < 6'd63)) begin
			gun_h <= gun_h + 6'b1;
		end

		if ((((m_up == 1'b1) && (up_r == 1'b1)) || ((m_down == 1'b1) && (down_r == 1'b1))) && (div_v < 5'd3)) begin
			div_v <= div_v + 5'b1;
		end else begin
			div_v <= 5'b0;
		end
		if ((m_up == 1'b1) && (div_v == 5'd1) && (gun_v > 6'd0)) begin
			gun_v <= gun_v - 6'b1;
		end
		if ((m_down == 1'b1) && (div_v == 5'd1) && (gun_v < 6'd63)) begin
			gun_v <= gun_v + 6'b1;
		end
	end
end

// AUDIO VIDEO
wire hblank, vblank;
wire hs, vs;

wire [ 3:0] r,g,b,intensity;
wire [ 7:0] ri,gi,bi;

wire [7:0] color_lut[256] = '{
    8'd19, 8'd21, 8'd23,  8'd25,  8'd26,  8'd29,  8'd32,  8'd35,  8'd38,  8'd43,  8'd49,  8'd56,  8'd65,  8'd76,  8'd96,  8'd108,
    8'd21, 8'd22, 8'd24,  8'd26,  8'd28,  8'd30,  8'd34,  8'd37,  8'd40,  8'd45,  8'd52,  8'd59,  8'd68,  8'd80,  8'd101, 8'd114,
    8'd22, 8'd24, 8'd26,  8'd28,  8'd30,  8'd33,  8'd36,  8'd39,  8'd43,  8'd48,  8'd55,  8'd63,  8'd73,  8'd86,  8'd107, 8'd121,
    8'd24, 8'd25, 8'd27,  8'd29,  8'd32,  8'd35,  8'd38,  8'd42,  8'd46,  8'd52,  8'd59,  8'd67,  8'd77,  8'd91,  8'd114, 8'd129,
    8'd25, 8'd27, 8'd29,  8'd31,  8'd34,  8'd37,  8'd40,  8'd45,  8'd48,  8'd54,  8'd62,  8'd71,  8'd81,  8'd96,  8'd121, 8'd137,
    8'd27, 8'd28, 8'd31,  8'd34,  8'd36,  8'd39,  8'd44,  8'd48,  8'd52,  8'd58,  8'd66,  8'd76,  8'd87,  8'd103, 8'd129, 8'd146,
    8'd29, 8'd31, 8'd34,  8'd36,  8'd39,  8'd43,  8'd47,  8'd52,  8'd56,  8'd63,  8'd72,  8'd82,  8'd94,  8'd111, 8'd140, 8'd158,
    8'd32, 8'd34, 8'd37,  8'd39,  8'd43,  8'd46,  8'd51,  8'd56,  8'd61,  8'd68,  8'd78,  8'd89,  8'd102, 8'd120, 8'd151, 8'd171,
    8'd32, 8'd35, 8'd38,  8'd41,  8'd44,  8'd48,  8'd53,  8'd59,  8'd64,  8'd72,  8'd83,  8'd94,  8'd109, 8'd129, 8'd161, 8'd182,
    8'd36, 8'd38, 8'd42,  8'd45,  8'd48,  8'd53,  8'd59,  8'd65,  8'd70,  8'd79,  8'd90,  8'd104, 8'd119, 8'd141, 8'd177, 8'd201,
    8'd40, 8'd43, 8'd46,  8'd50,  8'd54,  8'd59,  8'd65,  8'd72,  8'd79,  8'd88,  8'd101, 8'd115, 8'd133, 8'd157, 8'd198, 8'd224,
    8'd45, 8'd48, 8'd52,  8'd57,  8'd61,  8'd66,  8'd74,  8'd81,  8'd88,  8'd98,  8'd113, 8'd129, 8'd149, 8'd176, 8'd221, 8'd249,
    8'd50, 8'd54, 8'd58,  8'd64,  8'd68,  8'd75,  8'd83,  8'd91,  8'd99,  8'd111, 8'd128, 8'd146, 8'd169, 8'd200, 8'd249, 8'd253,
    8'd58, 8'd63, 8'd68,  8'd74,  8'd79,  8'd87,  8'd96,  8'd106, 8'd116, 8'd129, 8'd148, 8'd169, 8'd195, 8'd231, 8'd253, 8'd254,
    8'd71, 8'd76, 8'd83,  8'd89,  8'd96,  8'd105, 8'd116, 8'd128, 8'd139, 8'd156, 8'd179, 8'd205, 8'd236, 8'd252, 8'd254, 8'd254,
    8'd91, 8'd97, 8'd105, 8'd114, 8'd123, 8'd133, 8'd147, 8'd161, 8'd176, 8'd196, 8'd223, 8'd249, 8'd252, 8'd254, 8'd254, 8'd255
};

always @(posedge clk_48) begin : rgbOutput
	ri = ~| intensity ? 8'd0 : color_lut[{r, intensity}];
	gi = ~| intensity ? 8'd0 : color_lut[{g, intensity}];
	bi = ~| intensity ? 8'd0 : color_lut[{b, intensity}];
end

reg ce_pix;
always @(posedge clk_48) begin
	reg [2:0] div;
	div <= div + 1'd1;
	ce_pix <= !div;
end

	arcade_video #(313,24,1) arcade_video
(
        .*,

        .clk_video(clk_48),

        .RGB_in({ri[7:0],gi[7:0],bi[7:0]}),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(~hs),
        .VSync(~vs),

        .fx(status[5:3])
);

wire [7:0] audio;
assign AUDIO_L = {audio, 6'd0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

williams2 williams2
(
	.clock_12(clk_12),
	.reset(reset),

	.dn_addr(ioctl_addr[17:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr && ioctl_index==0),

	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_i(intensity),
	.video_hblank(hblank), // 48 <-> 1
	.video_vblank(vblank), // 504 <-> 262
	.video_blankn(!hblank | !vblank),
	.video_hs(hs),
	.video_vs(vs),

	.audio_out(audio), // [7:0]

	.btn_auto_up(status[10]),
	.btn_advance(status[11]),
	.btn_high_score_reset(status[12]),

	.btn_gobble(m_gobble),
	.btn_grenade(m_grenade),
	.btn_coin(m_coin),
	.btn_start_1(m_start1),
	.btn_start_2(m_start2),
	.btn_trigger(m_trigger),

	.gun_h(gun_h),
	.gun_v(gun_v),

	.cnt_4ms_o(cnt_4ms),

	.sw_coktail_table(0),
	.seven_seg(),

	.dbg_out()
);

endmodule
