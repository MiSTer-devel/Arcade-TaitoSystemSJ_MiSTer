//============================================================================
//  Arcade: Taito System SJ
//
//  Manufaturer: Taito
//  Type: Arcade Game
//  Genre: Multiple
//  Orientation: Both - ROM dependant 
//
//  Hardware Description by Anton Gale
//  https://github.com/antongale/Arcade-TaitoSJ_MiSTer
//
//============================================================================

//Known issues: Sprite positioning slightly off (see gap in rope in Jungle King)

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
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////
assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
wire [15:0] sdram_sz;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;
assign VGA_DISABLE = 0;
assign FB_FORCE_BLANK = 0;

assign AUDIO_S = 1;//signed for audio out
assign AUDIO_MIX = 3;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//copy dip switch setting for DIP menu
reg [7:0] sw[8];

always @(posedge clk_sys) begin
	if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
		sw[ioctl_addr[2:0]] <= ioctl_dout;
	end
end	

////////////////////   HPS   /////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;
wire        video_rotated;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire [15:0] joystick_0;

wire [21:0] gamma_bus;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[30:29];  //[20:19]

assign VIDEO_ARX = (!ar) ? ((mod_orientation)  ? 12'd1024 : 12'd896) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((mod_orientation)  ? 12'd896 : 12'd1024) : 12'd0;

//assign VIDEO_ARX = (!ar) ? ((status[2])  ? 12'd4 : 12'd3) : (ar - 1'd1);
//assign VIDEO_ARY = (!ar) ? ((status[2])  ? 12'd3 : 12'd4) : 12'd0;

reg mod_orientation  = 0;
reg [7:0] mod_other  = 0;
	
always @(posedge clk_sys) begin

	if (ioctl_wr & (ioctl_index==1)) mod_other <= ioctl_dout;
	mod_orientation<=mod_other[0]^status[2];
end

// Status Bit Map:
//                  Upper                          Lower
//     0         1         2         3          4         5         6
//     01234567890123456789012345678901 23456789012345678901234567890123
//     0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
//AR:                               XXX
//OR:    X
//SD:     XXX  
//MRA:         XXXXXXXXXXXXXXXX         XXXXXXXX
//HI :                          XX


//59.94 / 56.89Hz = 1.053612234136052
//37.93 / 36Mhz

`include "build_id.v"
localparam CONF_STR = {
	"A.TAITO SYSTEM SJ;;",
	"OTU,Aspect ratio,Original,Full Screen;",
	"O2,Orientation,Horizontal,Vertical;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
//	"OV,Frequency,60,Original;",	
	"-;",
	"DIP;",
	"-;",
	"H1OS,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Button 1,Button 2,Start 1P,Start 2P,Coin A,Coin B,Service,Pause;",
	//"Jn,A,B,Start,Select;",
	"V,v",`BUILD_DATE
};

wire        sd_buff_wr, img_readonly;
wire  [7:0] sd_buff_addr;	// Address inside 256-word sector
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din[2];
wire [15:0] sd_req_type;
wire [63:0] img_size;
wire [31:0] sd_lba[2];
wire  [1:0] sd_wr;
wire  [1:0] sd_rd;
wire  [1:0] sd_ack;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.status(status),
	.status_menumask({~hs_configured,direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	//SD RAM implementation?
	//.sdram_sz(sdram_sz),
	//.sd_lba(sd_lba),
	//.sd_rd(sd_rd),
	//.sd_wr(sd_wr),
	//.sd_ack(sd_ack),
	//.sd_buff_addr(sd_buff_addr),
	//.sd_buff_dout(sd_buff_dout),
	//.sd_buff_din(sd_buff_din),
	//.sd_buff_wr(sd_buff_wr),

	.joystick_0(joystick_0)
);

////////////////////   CLOCKS   ///////////////////

wire clkm_48MHZ,clkm_32MHZ,clkc_12MHz,clk_24MHZ,clkm_6MHZ;
wire clk_3M;
wire clk_sys=clkm_32MHZ;
wire clk_vid=clkm_48MHZ;
//reg ce_pix;

pll pll(
		.refclk(CLK_50M),  			// refclk.clk FPGA_CLK1_50
		.rst(0),            			// reset.reset
		.outclk_0(clkm_48MHZ),     // outclk0.clk
		.outclk_1(clkm_32MHZ),     // outclk1.clk
		.outclk_2(clkm_6MHZ),		// outclk2.clk
		.outclk_3(),
		.outclk_4()		
);


wire m_pause  		= joystick_0[11];

///////////////////   CLOCK DIVIDER   ////////////////////

always @(posedge clk_vid) begin
	reg [1:0] div;
	div <= div + (forced_scandoubler ? 2'd1 : 2'd2);
	//ce_pix <= !div;
end

///////////////////   VIDEO   ////////////////////
wire hblank, vblank;
wire hs, vs;

wire [2:0] r;
wire [2:0] g;
wire [2:0] b;
wire [8:0] rgb = {rgb_out[8:6],rgb_out[5:3],rgb_out[2:0]};//23:0

wire no_rotate = mod_orientation | direct_video;
wire rotate_ccw = 0;
wire flip = 0;

screen_rotate screen_rotate (.*);

arcade_video #(384,9) arcade_video //  9 : 3R 3G 3B - 288
(
	.*,
	.clk_video(clk_vid),
	.ce_pix(core_pix_clk),
	.RGB_in(rgb),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),
	.fx(status[5:3])
);

// PAUSE SYSTEM
wire pause_cpu;
wire [8:0] rgb_out;
pause #(3,3,3,38) pause
(
	.*,
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

// HISCORE SYSTEM
// --------------

wire [15:0]hs_address;
wire [7:0]hs_data_out;
wire [7:0]hs_data_in;
wire hs_write;
wire hs_access_read;
wire hs_access_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_ADDRESSWIDTH(6),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.reset(reset),
	.autosave(status[28]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write),
	.ram_intent_read(hs_access_read),
	.ram_intent_write(hs_access_write),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

///////////////////   GAME   ////////////////////
wire rom_download = ioctl_download && (ioctl_index == 0);
wire reset = (RESET | status[0] | buttons[1] | ioctl_download);
assign LED_USER = ioctl_download;
wire core_pix_clk;

taitosj_fpga tssj(
	.clkm_48MHZ(clkm_48MHZ),
	.clkm_32MHZ(clkm_32MHZ),	
	//.clkm_6MHZ(clkm_6MHZ),
	.pcb(mod_other),
	.RED(r),
	.GREEN(g),
	.BLUE(b),
	.core_pix_clk(core_pix_clk),		//from fpga core to sv		
	.H_SYNC(hs), //hs
	.V_SYNC(vs), //vs
	.H_BLANK(hblank),
	.V_BLANK(vblank),
	.RESET_n(~reset),
	.pause(pause_cpu),
	.m_right(~joystick_0[0]),
	.m_left(~joystick_0[1]),	
	.m_down(~joystick_0[2]),   
	.m_up(~joystick_0[3]),  	
	.m_shoot(~joystick_0[4]),
	.m_shoot2(~joystick_0[5]), 	
	.m_start1p(~joystick_0[6]),	
	.m_start2p(~joystick_0[7]),	
	.m_coina(~joystick_0[8]),  	
	.m_coinb(~joystick_0[9]),  	
	.m_service(joystick_0[10]),	
	.DIP1(sw[1]), 
	.DIP2(sw[2]),
	.DIP3(sw[4]),	
	.dn_addr(ioctl_addr),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr && rom_download), //& rom_download
	.audio_l(AUDIO_L),
	.audio_r(AUDIO_R),
	.hs_address(hs_address),
	.hs_data_out(hs_data_out),
	.hs_data_in(hs_data_in),
	.hs_write(hs_write)
);

endmodule
