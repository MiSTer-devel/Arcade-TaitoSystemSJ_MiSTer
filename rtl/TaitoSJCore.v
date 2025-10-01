//============================================================================
//  Arcade: Taito System SJ
//
//  Manufaturer: Taito
//  Type: Arcade Game
//  Genre: 
//  Orientation: 
//
//  Hardware Description by Anton Gale
//  https://github.com/MiSTer-devel/Arcade-TaitoSJ_MiSTer
//
//============================================================================
`timescale 1ns/1ps

module taitosj_fpga(
	input clkm_48MHZ,
	input clkm_32MHZ,
	input [7:0] pcb,	
	output reg [2:0] RED,    
	output reg [2:0] GREEN,	 
	output reg [2:0] BLUE,	 
	output core_pix_clk,			
	output H_SYNC,				
	output V_SYNC,				
	output H_BLANK,
	output V_BLANK,
	input RESET_n,				
	input pause,
	//joystick controls
	input m_right,
	input m_left,	
	input m_down,   
	input m_up,  	
	input m_shoot,
	input m_shoot2, 	
	input m_start1p,	
	input m_start2p,	
	input m_coina,  	
	input m_coinb,  	
	input m_service,	

	input [7:0] DIP1,
	input [7:0] DIP2,
	input [7:0] DIP3,	
	input [24:0] dn_addr,
	input 		 dn_wr,
	input [7:0]  dn_data,
	output signed [15:0] audio_l, //from jt49_1 & 2
	output signed [15:0] audio_r, //from jt49_1 & 2
	input [15:0] hs_address,
	output [7:0] hs_data_out,
	input [7:0] hs_data_in,
	input hs_write
);

//SYSTEM SJ CLOCKS - VIDEO
reg clkm_24MHZ, clkm_12MHZ, clkm_3MHZ, clkm_1p5MHZ;
reg clkm_6MHZ,clk2_6MHZ,clk3_6MHZ;
reg clkb_6MHZ,clkb_3MHZ,clkc_6MHZ;

//core clock generation logic based on jtframe code
reg [4:0] cencnt =5'd0;

always @(posedge clkm_48MHZ) begin
	cencnt  <= cencnt+5'd1;
end

always @(posedge clkm_48MHZ) begin
	clkm_24MHZ	  	<= cencnt[0]   == 1'd0;
	clkm_12MHZ		<= cencnt[1:0] == 2'd0;
	clkm_6MHZ		<= cencnt[2:0] == 3'd0;
	clkc_6MHZ		<= cencnt[2:0] == 3'd0;
	clk2_6MHZ		<= cencnt[2:0] == 3'd1;	
	clk3_6MHZ		<= cencnt[2:0] == 3'd2;		
	clkb_6MHZ		<= cencnt[2:0] == 3'd4;
   clkm_3MHZ		<= cencnt[3:0] == 4'd0;
	clkb_3MHZ		<= cencnt[3:0] == 4'd8;	
   clkm_1p5MHZ		<= cencnt[4:0] == 5'd0;		
		
end

assign core_pix_clk=clkc_6MHZ;

//SYSTEM SJ CLOCKS - CPU
reg clkm_16MHZ,clkm_8MHZ, clkm_8MHZn, clkm_4MHZ,clkm_4MHZn,clkm_2MHZ;

reg [3:0] mcpucnt =4'd0;

always @(posedge clkm_32MHZ) begin
	mcpucnt  <= mcpucnt+4'd1;
end

always @(posedge clkm_32MHZ) begin
	clkm_16MHZ	  	<= mcpucnt[0]   == 1'd0;
	clkm_8MHZ	  	<= mcpucnt[1:0] == 2'd0;
	clkm_8MHZn	  	<= mcpucnt[1:0] == 2'd2;	
	clkm_4MHZ	  	<= mcpucnt[2:0] == 3'd0;
	clkm_4MHZn	  	<= mcpucnt[2:0] == 3'd4;
	clkm_2MHZ	  	<= mcpucnt[3:0] == 4'd0;
end

//Z80A (Main CPU) address & databus definitions
wire Z80A_MREQ,Z80A_WR,Z80A_RD,Z80A_IOREQ,Z80A_RFSH,Z80A_M1,Z80A_INT;
wire [15:0] Z80A_addrbus;
wire [7:0]  Z80A_databus_in,Z80A_databus_out,Z80A_RAM_out,Z80A_MROM_out,Z80A_BROM_out,MCU_ROM_out;

//chip selects:
wire MROMRQ,BROMRQ,SRAMREQ,HTCLR,EXROM1,EXROM2,EPORT1,EPORT2,TIME_RESET,COIN_SET,EXPORT;
wire MCU,MCU_ROM,MCU_ROM_RD;

//program ROM 
assign MROMRQ   = (Z80A_addrbus[15] == 1'b0) & !BANK_SEL & !Z80A_MREQ; //Main Program ROM
assign BROMRQ	 = (Z80A_addrbus[15] == 1'b0) &  BANK_SEL & !Z80A_MREQ; //Main Program Banked ROM

//work RAM
assign SRAMREQ  = (Z80A_addrbus[15:11] == 5'b10000) 						? 1'b1 : 1'b0; //8000 - 87FF - Main CPU RAM

//MCU
assign MCU 		 = (Z80A_addrbus[15:11] == 5'b10001) 						? 1'b0 : 1'b1; //8800 - 8FFF - MCU Read/Write
assign MCU_ROM  = (Z80A_addrbus[15:13] == 3'b111) 							? 1'b0 : 1'b1; //E000 - EFFF - MCU ROM

//VRAM
assign CDR1RQ	 = (Z80A_addrbus[15:11] == 5'b10010)						? 1'b0 : 1'b1; //9000 - 97FF - Character Generator RAM
assign CDR2RQ	 = (Z80A_addrbus[15:11] == 5'b10011)						? 1'b0 : 1'b1; //9800 - 9FFF - Character Generator RAM
assign CDR3RQ	 = (Z80A_addrbus[15:11] == 5'b10100)						? 1'b0 : 1'b1; //A000 - A7FF - Character Generator RAM
assign CDR4RQ	 = (Z80A_addrbus[15:11] == 5'b10101)						? 1'b0 : 1'b1; //A800 - AFFF - Character Generator RAM
assign CDR5RQ	 = (Z80A_addrbus[15:11] == 5'b10110)						? 1'b0 : 1'b1; //B000 - B7FF - Character Generator RAM
assign CDR6RQ	 = (Z80A_addrbus[15:11] == 5'b10111)						? 1'b0 : 1'b1; //B800 - BFFF - Character Generator RAM
assign CHARQ	 = (Z80A_addrbus[15:12] == 4'b1100) 						? 1'b0 : 1'b1; //C000 - CFFF - Tilemap RAM

assign PROT_SEL =	(Z80A_addrbus==16'hD48B);//Space Cruiser Protection Selection

//D5XX registers (WRITE)
assign SPH1	 			= (Z80A_addrbus == 16'hD500)							? Z80A_WR : 1'b1; //Horizontal Scroll  - Tilemap #1
assign SPV1	 			= (Z80A_addrbus == 16'hD501)							? Z80A_WR : 1'b1; //Vertical Scroll    - Tilemap #1  
assign SPH2	 			= (Z80A_addrbus == 16'hD502)							? Z80A_WR : 1'b1; //Horizontal Scroll  - Tilemap #2
assign SPV2	 			= (Z80A_addrbus == 16'hD503)							? Z80A_WR : 1'b1; //Vertical Scroll    - Tilemap #2  
assign SPH3	 			= (Z80A_addrbus == 16'hD504)							? Z80A_WR : 1'b1; //Horizontal Scroll  - Tilemap #3
assign SPV3	 			= (Z80A_addrbus == 16'hD505)							? Z80A_WR : 1'b1; //Vertical Scroll    - Tilemap #3  
assign SMD12 			= (Z80A_addrbus == 16'hD506)							? Z80A_WR : 1'b1; //Bank & Colour Code - Tilemap #1 & 2
assign SMD3	 			= (Z80A_addrbus == 16'hD507)							? Z80A_WR : 1'b1; //Bank & Colour Code - Tilemap #3
assign HTCLR	 		= (Z80A_addrbus == 16'hD508)							? Z80A_WR : 1'b1; //Hit Detection Clear
assign EXROM1	 		= (Z80A_addrbus == 16'hD509)							? Z80A_WR : 1'b1; //External Graphics ROM Low Address
assign EXROM2	 		= (Z80A_addrbus == 16'hD50A)							? Z80A_WR : 1'b1; //External Graphics ROM High Address
assign EPORT1	 		= (Z80A_addrbus == 16'hD50B)							? Z80A_WR : 1'b1; //Sound CPU <-> Main CPU Interface
assign EPORT2	 		= (Z80A_addrbus == 16'hD50C)							? Z80A_WR : 1'b1; //Main CPU D0 -> Sound CPU DB2
assign TIME_RESET	 	= (Z80A_addrbus == 16'hD50D)							? Z80A_WR : 1'b1; //Reset Watchdog
assign COIN_SET 		= (Z80A_addrbus == 16'hD50E)							? Z80A_WR : 1'b1; //COINLOCK & SOUNDSTOP signals 
assign EXPORT	 		= (Z80A_addrbus == 16'hD50F)  						? Z80A_WR : 1'b1; 

assign SCRRQ 			= (Z80A_addrbus[15:8] == 8'b11010000) 				? 1'b0 	 : 1'b1; //D000 - D0FF - Column scroll
assign OBJRQ 			= (Z80A_addrbus[15:8] == 8'b11010001) 				? 1'b0 	 : 1'b1; //D100 - D1FF - Object data (sprite locations etc.)
assign VCRRQ 			= (Z80A_addrbus[15:8] == 8'b11010010) 				? 1'b0 	 : 1'b1; //D200 - D2FF - Palette
assign PRY				= (Z80A_addrbus[15:8] == 8'b11010011) 				? Z80A_WR : 1'b1; //D300 - D3FF - Priority
assign HTRRQ			= (Z80A_addrbus[15:2] == 14'b11010100000000) 	? Z80A_RD : 1'b1; //D400 - D403 - Collision
assign EXRHR			= (Z80A_addrbus[15:2] == 14'b11010100000001) 	? Z80A_RD : 1'b1; //D404 - D407 - External ROM
assign AY_0_SEL		= (Z80A_addrbus[15:1] == 15'b110101000000111) 	? 1'b1 	 : 1'b0; //D40E - D40F - CPU controlled AY soundchip
assign SOFF				= (Z80A_addrbus[15:8] == 8'b11010110) 				? Z80A_WR : 1'b1; //D600 - D6FF - Screen Inversion, Spritebank Select, Tilemap enables

//CPU read selection logic
// ******* PRIMARY CPU IC SELECTION LOGIC FOR TILE, SPRITE, SOUND & GAME EXECUTION ********
assign Z80A_databus_in =	(MROMRQ  						& !Z80A_RD) 	? Z80A_MROM_out 		:
									(BROMRQ  						& !Z80A_RD) 	? Z80A_BROM_out 		:
									(SRAMREQ  						& !Z80A_RD) 	? Z80A_RAM_out  		:
									(!OBJRQ 							& !Z80A_RD)		? Z80A_OD_out 			:
									(!EXRHR 							& !Z80A_RD)		? EXT_DATA				:
									(!HTRRQ 							& !Z80A_RD)		? HIT_DATA				:
									(!CHARQ							& !Z80A_RD)    ? Z80A_CPU_CD_data 	:
									(!SCRRQ    						& !Z80A_RD)		? Z80A_SCD_data_out 	:
									(PROT_SEL						& !Z80A_RD)    ? PROT_DATA				:
									(Z80A_addrbus == 16'hD40D	& !Z80A_RD) 	? INPUT5X 				:
									(Z80A_addrbus == 16'hD40C	& !Z80A_RD) 	? INPUT4X 				:
									(Z80A_addrbus == 16'hD40B	& !Z80A_RD) 	? INPUT3X 				:
									(Z80A_addrbus == 16'hD40A	& !Z80A_RD) 	? DIPSWA  				:
									(Z80A_addrbus == 16'hD409	& !Z80A_RD) 	? INPUT1X 				:
									(Z80A_addrbus == 16'hD408 	& !Z80A_RD) 	? INPUT0X 				:
									(AY_0_SEL         			& !Z80A_RD)    ? AY_0_databus_out   :
									(!MCU								& !Z80A_RD)		? 8'b11111111   		:
									(!MCU_ROM	& !Z80A_MREQ	& !Z80A_RD)		? MCU_ROM_out			:
									8'b00000000;

wire PUR = 1'b1;
wire CHARQ,SOFF,PRY,VCRRQ,OBJRQ,SCRRQ,SMD3,SMD12,SPV3,SPH3,SPV2,SPH2,SPV1,SPH1;
wire CDR6RQ,CDR5RQ,CDR4RQ,CDR3RQ,CDR2RQ,CDR1RQ; //VRAM CHIP SELECTS
wire OBJ_CINV,INRANG,SN3OFF,SN2OFF,SN1OFF,OMD,VINV,HINV,HITOB,HLP0,HLP1,HLP2;
wire WD_RESET,INT_RST,PROT_SEL,OBJ,SCN1,SCN2,SCN3;
wire HTRRQ,EXRHR;
reg rZ80A_INT;
wire [10:0] CHA;
wire [7:0]  CRD,CGD,CBD,CRDH,CGDH,CBDH;
reg  [11:0]  VRAM_ADDR;		//Video RAM address
reg  CCH3,CCH1,CCH2;			//Tile Map x Character Bank
reg  [2:0] MD1,MD2,MD3; 	//Tile Map x Colour Codes
reg  [1:0] MD0;			  	//Sprite Colour Code
reg  [7:0] SN11_in,SN21_in,SN31_in;
reg  [7:0] SN12_in,SN22_in,SN32_in;
reg  [7:0] SN13_in,SN23_in,SN33_in;
wire [3:0] OB;
wire [2:0] SN1,SN2,SN3,QBUS;
reg  [7:0] reset_counter;
reg  [4:0] PRIORITY;
wire [3:0] EB16_out;
wire [7:0] HIT_DATA;
wire wait_n = !pause;
wire [15:0] RGB;
wire SN1LD,SN2LD,SN3LD,PH01,PH23,PH45,PH67;
wire LNSL1,LNSL2,LNLD1,LNLD2,LNCL1,LNCL2;
wire BLANK;
wire [4:0] syncbus_HM;
wire [8:0] syncbus_HN;
wire [7:0] syncbus_H,syncbus_V,syncbus_PH;
wire [7:0] SCD,Z80A_SCD_data_out,Z80A_OD_out;
wire [12:0] OBJ_CHA;

reg  [10:0] CD_CHA;
reg  CINV;
reg  [7:0] S_DATA; //scroll data

reg  [4:0] DHPH5,DHPH3,DHPH1; //HORIZONTAL SCROLL REGISTERS
wire [4:0] DH,DH2;
wire [5:0] HORZBITS,HORZBITS2;

reg  [7:0] DVPH7,DVPH5,DVPH3; //VERTICAL SCROLL REGISTERS
wire [7:0] DV,VERTBITS;
wire [7:0] CD_out,CD,Z80A_CPU_CD_data;
reg  [5:0] MA;

wire [14:0] EXT_ROM_ADDR;
reg  [14:0] EX_COUNTER;
reg  [7:0] D509,D50A;
wire [7:0] EXT_DATA;
reg  [7:0] PROT_DATA,ALP_PROT;
reg  SSYNC;


//wire CDRRQ;
//assign CDRRQ =!(CDR1RQ&CDR2RQ&CDR3_6); //U54B - CPU is not writing to graphics memory

dpram_dc #(.widthad_a(12)) U105_U104_RAM_2016 //VIDEO RAM
(
	.clock_a(clkm_48MHZ),
	.address_a(VRAM_ADDR), //!SELVRAM_B1
	.data_a(),
	.wren_a(1'b0),
	.q_a(CBD),
	
	.clock_b(clkm_32MHZ),
	.address_b({!CDR6RQ,Z80A_addrbus[10:0]}),
	.data_b(Z80A_databus_out),
	.wren_b(!Z80A_WR & (!CDR3RQ|!CDR6RQ)),
	.q_b()
);

dpram_dc #(.widthad_a(12)) U107_U106_RAM_2016 //VIDEO RAM
(
	.clock_a(clkm_48MHZ),
	.address_a(VRAM_ADDR), //!SELVRAM_B1
	.data_a(),
	.wren_a(1'b0),
	.q_a(CGD),
	
	.clock_b(clkm_32MHZ),
	.address_b({!CDR5RQ,Z80A_addrbus[10:0]}),
	.data_b(Z80A_databus_out),
	.wren_b(!Z80A_WR & (!CDR2RQ|!CDR5RQ)),
	.q_b()
);

dpram_dc #(.widthad_a(12)) U109_U108_RAM_2016 //VIDEO RAM
(
	.clock_a(clkm_48MHZ),
	.address_a(VRAM_ADDR), //!SELVRAM_B1
	.data_a(),
	.wren_a(1'b0),
	.q_a(CRD),
	
	.clock_b(clkm_32MHZ),
	.address_b({!CDR4RQ,Z80A_addrbus[10:0]}),
	.data_b(Z80A_databus_out),
	.wren_b(!Z80A_WR & (!CDR1RQ|!CDR4RQ)),
	.q_b()
);

always @(*) begin //U51
	  case (syncbus_HN[2:1])
			2'b00: {CINV,VRAM_ADDR} <= {HINV,CCH3,CD_CHA}; //5V PULLUP
			2'b01: {CINV,VRAM_ADDR} <= {OBJ_CINV,OBJ_CHA[11:0]};
			2'b10: {CINV,VRAM_ADDR} <= {HINV,CCH1,CD_CHA};  
			2'b11: {CINV,VRAM_ADDR} <= {HINV,CCH2,CD_CHA};  
	  endcase
end

//reverse the order of the pixels if CINV bit is set
assign CRDH = (!CINV )? CRD : {CRD[0],CRD[1],CRD[2],CRD[3],CRD[4],CRD[5],CRD[6],CRD[7]};
assign CGDH = (!CINV )? CGD : {CGD[0],CGD[1],CGD[2],CGD[3],CGD[4],CGD[5],CGD[6],CGD[7]};
assign CBDH = (!CINV )? CBD : {CBD[0],CBD[1],CBD[2],CBD[3],CBD[4],CBD[5],CBD[6],CBD[7]};

always @(posedge PH45) begin //45 //syncbus_PH[4]
	SN11_in <= CRDH;
	SN12_in <= CGDH;
	SN13_in <= CBDH;
end

always @(posedge PH67) begin //67 //syncbus_PH[6]
	SN21_in <= CRDH;
	SN22_in <= CGDH;
	SN23_in <= CBDH;
end

always @(posedge PH01) begin //01 syncbus_PH[0]
	SN31_in <= CRDH;
	SN32_in <= CGDH;
	SN33_in <= CBDH;
end

ls166x3 CRGB1( //layer 1
	.clk(clkm_6MHZ),
	.pinA(SN11_in),
	.pinB(SN12_in),
	.pinC(SN13_in),	
	.PE(SN1LD),
	.clr(SN1OFF&1'b1),
	.QH(SN1)
);

ls166x3 CRGB2( //layer 2
	.clk(clkm_6MHZ),
	.pinA(SN21_in),
	.pinB(SN22_in),
	.pinC(SN23_in),	
	.PE(SN2LD),
	.clr(SN2OFF&1'b1),
	.QH(SN2)
);

ls166x3 CRGB3( //layer 3
	.clk(clkm_6MHZ),
	.pinA(SN31_in),
	.pinB(SN32_in),
	.pinC(SN33_in),	
	.PE(SN3LD),
	.clr(SN3OFF&1'b1),
	.QH(SN3)
);

ls166x3 CRGBO( //sprites / objects
	.clk(clkm_6MHZ),
	.pinA(CRDH),
	.pinB(CGDH),
	.pinC(CBDH),	
	.PE(|syncbus_PH[4:3]|INRANG),//|OBJ_CHA[12]  PHA34 //syncbus_PH[3]|
	.clr(1'b1), //enabled sprites
	.QH(QBUS)
);

reg BANK_SEL,SOUND_STOP,COIN_LOCK;
always @(posedge COIN_SET) begin
	BANK_SEL<=Z80A_databus_out[7];
	SOUND_STOP<=Z80A_databus_out[1];
	COIN_LOCK<=Z80A_databus_out[0];
end

//watchdog reset
always @(posedge V_BLANK or negedge TIME_RESET) reset_counter <= (!TIME_RESET) ? 8'd0 : reset_counter;
assign WD_RESET = !reset_counter[7];

//collision detection logic
assign OBJ =!(|OB[2:0]);
assign SCN1=!(|SN1[2:0]);
assign SCN2=!(|SN2[2:0]);
assign SCN3=!(|SN3[2:0]);

hit_bus HB(
	.clkm_6MHZ(clkm_6MHZ),
	.clkb_6MHZ(clkb_6MHZ),
	.OBJ(OBJ),
	.SCN1(SCN1),
	.SCN2(SCN2),
	.SCN3(SCN3),
	.HTCLR(HTCLR),
	.HLP0(HLP0),
	.HLP1(HLP1),
	.HLP2(HLP2),	
	.HITOB(HITOB),
	.HTRRQ(HTRRQ),
	.syncbus_HM(syncbus_HM),
	.ADDR_ED(Z80A_addrbus[1:0]),
	.HIT_DATA(HIT_DATA)
);

always @(posedge SMD12) {CCH2,MD2,CCH1,MD1}<=Z80A_databus_out; 	//D506
always @(posedge SMD3)  {MD0,CCH3,MD3}<= Z80A_databus_out[5:0];	//D507
always @(posedge PRY)   PRIORITY<=Z80A_databus_out[4:0];				//D300 - Priority Control
//reg m1_pause;
//always @(posedge clkm_4MHZ) m1_pause<=Z80A_M1&!m1_pause;

//First Z80 CPU responsible for main game logic
T80pa Z80A(
	.RESET_n(RESET_n&WD_RESET),
	.WAIT_n(wait_n/*&U91_wait_n*/),
	.INT_n(Z80A_INT), //Z80A_INT
	.BUSRQ_n(PUR),
	.NMI_n(PUR),
	.CLK(clkm_32MHZ), 
	.CEN_p(clkm_4MHZ), 
	.CEN_n(clkm_4MHZn), 
	.MREQ_n(Z80A_MREQ),
	.IORQ_n(Z80A_IOREQ),
	.RFSH_n(Z80A_RFSH),
	.M1_n(Z80A_M1),
	.DI(Z80A_databus_in),
	.DO(Z80A_databus_out),
	.A(Z80A_addrbus),
	.WR_n(Z80A_WR),
	.RD_n(Z80A_RD)
);

wire mcu_bs_wr,mcu_bs_rd;
wire [7:0] mcu_bs_dout,mcu_bs_din;
wire [7:0] mcu_rom_data;
wire [10:0] mcu_rom_addr;
/*
SJ_mcu MCU68705(
	.rst(RESET_n),
	.clk(clkm_32MHZ),
	.cen(clkm_4MHZ),
	.bs_wr(mcu_bs_wr),
	.bs_rd(mcu_bs_rd),
	.bs_dout(mcu_bs_dout),
	.bs_din(mcu_bs_din),
	.rom_addr(mcu_rom_addr),
   .rom_data(mcu_rom_data)
);*/


 
wire [9:0] sound_outAY1;
wire [9:0] sound_outAY2;
wire [9:0] sound_outAY3;
wire AY_1_sample;
wire AY_2_sample;
wire AY_3_sample;
wire [7:0] AY1_IOA_out,AY2_IOA_out;

game_sound EXT_SOUND(
	//clocks
	.clkm_48MHZ(clkm_48MHZ),			//master clock
	.clkm_32MHZ(clkm_32MHZ),
	.clkm_3MHZ(clkm_3MHZ),			//sound CPU clock
	.clkb_3MHZ(clkb_3MHZ),
	.clkm_1p5MHZ(clkm_1p5MHZ),		//AY clock
	
	//control inputs
	.nSND_RST(RESET_n),

	.EPORT1(EPORT1),
	.EPORT2(EPORT2),
	
	//ROM download handling
	.CPU_ADDR(Z80A_addrbus),
	.CPU_DIN(Z80A_databus_out),
	.dn_addr(dn_addr),
	.dn_data(dn_data),
	.snd_prom_cs_i(ep3_cs_i),
	.dn_wr(dn_wr),

	.pause(pause),
	
	.sound_outAY1(sound_outAY1),
	.sound_outAY2(sound_outAY2),
	.sound_outAY3(sound_outAY3),
	.AY_1_sample(AY_1_sample),
	.AY_2_sample(AY_2_sample),
	.AY_3_sample(AY_3_sample),
	.AY1_IOA_out(AY1_IOA_out),
	.AY2_IOA_out(AY2_IOA_out)

);

always @(posedge PROT_SEL) PROT_DATA<=PROT_DATA^8'hFF; //space cruiser protection

//Z80A - Vertical Blank Interrupt
assign INT_RST = Z80A_IOREQ|Z80A_M1;
always @(posedge V_BLANK or negedge INT_RST) begin
	rZ80A_INT <= (!INT_RST) 				? 1'b1 : 1'b0;
end
assign Z80A_INT=rZ80A_INT;

//main CPU (Z80A) work RAM - dual port RAM for hi-score logic
dpram_dc #(.widthad_a(11)) U14_RAM_2016 //SJ
(
	.clock_a(clkm_32MHZ),
	.address_a(Z80A_addrbus[10:0]),
	.data_a(Z80A_databus_out),
	.wren_a(!Z80A_WR & SRAMREQ),
	.q_a(Z80A_RAM_out)
	
//	.clock_b(clkm_48MHZ),
//	.address_b(hs_address[10:0]),
//	.data_b(hs_data_in),
//	.wren_b(hs_write),
//	.q_b(hs_data_out)
);

//Z80A CPU main program program ROM #1 - This is a combination of all of the prgroam ROMs 
eprom_0 Z80A_MAIN_PROGRAMROMS
(
	.ADDR(Z80A_addrbus[14:0]),
	.CLK(clkm_32MHZ),//
	.DATA(Z80A_MROM_out),//
	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_32MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(ep0_cs_i),
	.WR(dn_wr)
);

eprom_1 Z80A_BANK_PROGRAMROMS
(
	.ADDR(Z80A_addrbus[14:0]),
	.CLK(clkm_32MHZ),//
	.DATA(Z80A_BROM_out),//
	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_32MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(ep1_cs_i),
	.WR(dn_wr)
);


sync_bus syncbus(
	//clocks
	.clkm_48MHZ(clkm_48MHZ),
	.clkm_6MHZ(clkm_6MHZ),			//pixel clock
	.clkb_6MHZ(clkb_6MHZ),			//master clock	
	.CLK2(clk2_6MHZ),	
	.CLK3(clk3_6MHZ),
	.clkm_3MHZ(clkm_3MHZ),			//1/2 pixel clock
	.RESET_n(RESET_n),
	.SPH1(SPH1),
	.SPH2(SPH2),
	.SPH3(SPH3),	
	.VINV(VINV),
	.HINV(HINV),	
	.Z80A_DATABUS(Z80A_databus_out),
	
	.SB_HN(syncbus_HN), 				//128HN=[7],64=[6],32=[5],16=[4],8=[3],4=[2],2=[1],1HN=[0]
	.SB_H(syncbus_H), 				//syncbus_H = 128H=[7],64=[6],32=[5],16=[4],8=[3],4=[2],2=[1],1H=[0]
	.SB_HM(syncbus_HM),
	.SB_V(syncbus_V),					//128V=[7],64V=[6],32V=[5],16V=[4],8V=[3],4V=[2],2V=[1],1V=[0]
	.PH(syncbus_PH),
	.VSYNC(V_SYNC),
	.HSYNC(H_SYNC),
	.VBL(V_BLANK),						//V.BL
	.HBL(H_BLANK),						//H.BL
	.BLANK(BLANK),
	.SN1LD(SN1LD),
	.SN2LD(SN2LD),
	.SN3LD(SN3LD),
	.PH01(PH01),	
	.PH23(PH23),
	.PH45(PH45),
	.PH67(PH67),
	.HLP0(HLP0),
	.HLP1(HLP1),	
	.HLP2(HLP2)	
);



//Horizontal Scroll
always @(posedge SPH3) DHPH5 <= Z80A_databus_out[7:3];
always @(posedge SPH2) DHPH3 <= Z80A_databus_out[7:3];
always @(posedge SPH1) DHPH1 <= Z80A_databus_out[7:3];

assign DH=	(!syncbus_PH[7]) ? DHPH5 :				//phases switched to match vertical
				(!syncbus_PH[5]) ? DHPH3 :				//when used in address generation
				(!syncbus_PH[3]) ? DHPH1 : 5'b00000;				

assign DH2=	(!syncbus_PH[5]) ? DHPH5 :				//phases switched to match original setting
				(!syncbus_PH[3]) ? DHPH3 :				//when used in scroll ram address generation
				(!syncbus_PH[1]) ? DHPH1 : 5'b00000;				

assign HORZBITS=syncbus_H[7:3]+DH;			//this is kind of a 'hack' as two parts of the circuitry need these values
assign HORZBITS2=syncbus_H[7:3]+DH2;      //at seperate times

//Vertical Scroll
always @(posedge SPV3) DVPH7 <= Z80A_databus_out[7:0];
always @(posedge SPV2) DVPH5 <= Z80A_databus_out[7:0];
always @(posedge SPV1) DVPH3 <= Z80A_databus_out[7:0];

assign DV=	(!syncbus_PH[7]) ? DVPH7 ://7
				(!syncbus_PH[5]) ? DVPH5 ://5
				(!syncbus_PH[3]) ? DVPH3 : 8'b00000000;//3

assign VERTBITS=syncbus_V[7:0]+S_DATA[7:0]+DV;

dpram_dc #(.widthad_a(12)) U5756 //SJ
(
	.clock_a(clkm_32MHZ),
	.address_a({syncbus_HN[2:1],VERTBITS[7:3],HORZBITS[4:0]}), 
	.data_a(),
	.wren_a(1'b0),
	.q_a(CD_out),
	
	.clock_b(clkm_32MHZ),
	.address_b(Z80A_addrbus[11:0]),
	.data_b(Z80A_databus_out),
	.wren_b(!Z80A_WR & !CHARQ),
	.q_b(Z80A_CPU_CD_data)
);

//------------------------------------------------- MiSTer data write selector -------------------------------------------------//
//Instantiate MiSTer data write selector to generate write enables for loading ROMs into the FPGA's BRAM
wire ep0_cs_i, ep0b_cs_i, ep1_cs_i, ep2_cs_i, ep3_cs_i, ep4_cs_i, ep5_cs_i, ep6_cs_i, ep7_cs_i, ep8_cs_i,ep9_cs_i,ep10_cs_i,ep11_cs_i,ep12_cs_i,ep13_cs_i,cp1_cs_i,cp2_cs_i,cp3_cs_i;

selector DLSEL
(
	.ioctl_addr(dn_addr),
	.ep0_cs(ep0_cs_i),
	.ep1_cs(ep1_cs_i),
	.ep2_cs(ep2_cs_i),
	.ep3_cs(ep3_cs_i),
	.ep4_cs(ep4_cs_i),
	.ep5_cs(ep5_cs_i),
	.ep6_cs(ep6_cs_i),
	.ep7_cs(ep7_cs_i),	
	.ep8_cs(ep8_cs_i),
	.ep9_cs(ep9_cs_i),	
	.ep10_cs(ep10_cs_i),
	.ep11_cs(ep11_cs_i),
	.ep12_cs(ep12_cs_i),
	.ep13_cs(ep13_cs_i),
	.cp1_cs(cp1_cs_i),
	.cp2_cs(cp2_cs_i),
	.cp3_cs(cp3_cs_i)	
);

dpram_dc #(.widthad_a(8)) U7273 //SJ
(
	.clock_a(clkm_48MHZ),
	.address_a({1'b0,syncbus_HN[2:1],HORZBITS2[4:0]}), //4=[2],2=[1]
	.data_a(),
	.wren_a(1'b0),
	.q_a(SCD),
	
	.clock_b(clkm_32MHZ),
	.address_b(Z80A_addrbus[7:0]),
	.data_b(Z80A_databus_out),
	.wren_b(!Z80A_WR & !SCRRQ),
	.q_b(Z80A_SCD_data_out)
);

always @(posedge !syncbus_HN[0]) S_DATA <=	SCD;
always @(posedge !syncbus_HN[0]) CD_CHA[10:0]	<=	{CD_out,VERTBITS[2:0]};	//+S_DATA[2:0]

//object data bus (sprite renderer)
obj_bus TSJ_OBJ_BUS(
	//clocks
	.clkm_48MHZ(clkm_48MHZ),
	.clkm_32MHZ(clkm_32MHZ),	
	.clkm_6MHZ(clkm_6MHZ),			//master clock
	.clkb_6MHZ(clkb_6MHZ),		
	.CLK2(clk2_6MHZ),	
	//inputs
	.syncbus_HN(syncbus_HN),			//128HN=[7],64=[6],32=[5],16=[4],8=[3],4=[2],2=[1],1HN=[0]
	.syncbus_PH(syncbus_PH),	
	.syncbus_V(syncbus_V),			//128V=[7],64V=[6],32V=[5],16V=[4],8V=[3],4V=[2],2V=[1],1V=[0]
	.Z80A_addrbus(Z80A_addrbus),
	.Z80A_databus_out(Z80A_databus_out),
	.Z80A_WR(Z80A_WR),
	.OBJRQ(OBJRQ),
	.SOFF(SOFF),
	.QBUS(QBUS),
	//outputs
	.OBJ_CHA(OBJ_CHA), 		
	.Z80A_OD_out(Z80A_OD_out),
	.OBJ_CINV(OBJ_CINV),
	.INRANG(INRANG),
	//.OBJCH(OBJCH),
	.SN3OFF(SN3OFF),
	.SN2OFF(SN2OFF),
	.SN1OFF(SN1OFF),
	.VINV(VINV),
	.HINV(HINV),
	.HITOB(HITOB),
	.OB(OB)
);

//START: *********** External Graphic ROM board ************ 
always @(posedge EXROM1) D509<=Z80A_databus_out;
always @(posedge EXROM2) D50A<=Z80A_databus_out;
assign EXT_ROM_ADDR={D50A[6:0],D509}+EX_COUNTER;
always @(posedge EXRHR or negedge EXROM2) EX_COUNTER <=(!EXROM2) ? 15'd0:EX_COUNTER+1;

eprom_2 EXT_ROM
(
	.ADDR({EXT_ROM_ADDR}),
	.CLK(clkm_32MHZ),//
	.DATA(EXT_DATA),//
	
	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_32MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(ep2_cs_i),
	.WR(dn_wr)
);
//END: *********** External Graphic ROM board ************ 



always @(posedge EXPORT) begin
	case (Z80A_databus_out) 
		8'h05: 	ALP_PROT<=8'h18;
		8'h07: 	ALP_PROT<=8'h00;
		8'h0C: 	ALP_PROT<=8'h00;
		8'h0F: 	ALP_PROT<=8'h00;		
		8'h16: 	ALP_PROT<=8'h08;		
		8'h1D: 	ALP_PROT<=8'h18;	
		default: ALP_PROT<=Z80A_databus_out;	
	endcase
end
	
//Input BUS & Dip Switches - off=1
wire [7:0] INPUT5X = {AY2_IOA_out[7:4],4'b1111}; 
wire [7:0] INPUT4X = {3'b111,m_service,4'b0000}; //44 & 45 were the RILT & SERV
//wire [7:0] INPUT3X = {m_start2p,m_start1p,m_coina,m_coinb,4'b0000}|ALP_PROT; //34 & 35 are coin B &c? //31 hard grounded WAS '4b1101
wire [7:0] INPUT3X = pcb[1] ? ({m_start2p,m_start1p,m_coina,ALP_PROT[4:1],m_coinb}) : {m_start2p,m_start1p,m_coina,m_coinb,4'b0000}; //34 & 35 are coin B &c? //31 hard grounded WAS '4b1101
wire [7:0] DIPSWA  = ~DIP1;//8'b01111101; 
wire [7:0] INPUT1X = 8'b11111111; 
wire [7:0] INPUT0X = {2'b10,m_shoot2,m_shoot,m_up,m_down,m_right,m_left}; //IN06 hard grounded
wire [7:0] DIPSWB  = ~DIP2; 
wire [7:0] DIPSWC  = ~DIP3;

wire AY_0_BDIR,AY_0_BC1,AY_0_SEL,AY_0_sample;
wire [7:0] AY_0_databus_out;
wire [9:0] sound_outAY0;

assign AY_0_BDIR=AY_0_SEL&!Z80A_WR;
assign AY_0_BC1 =AY_0_SEL&!Z80A_addrbus[0]&!Z80A_WR;
wire 	 nSND_RST=1'b1;
wire signed [15:0] audio_snd;
wire signed [15:0] audio_snd_ext;

jt49_bus AY_0(
    .rst_n(RESET_n),
    .clk(clkm_48MHZ),						// signal on positive edge
    .clk_en(clkm_1p5MHZ),  				/* synthesis direct_enable = 1 */
    
    .bdir(AY_0_BDIR),	 					// bus control pins of original chip
    .bc1(AY_0_BC1),
	 .din(Z80A_databus_out),
    .sel(1'b1), 								// if sel is low, the clock is divided by 2
    .dout(AY_0_databus_out),
    
	 .sound(sound_outAY0),  				// combined channel output
    .A(),      								// linearised channel output
    .B(),
    .C(),
    .sample(AY_0_sample),

    .IOA_in(DIPSWB),							//Dip Switch B
    .IOB_in(DIPSWC)							//Dip Switch C
);

jtframe_jt49_filters u_filters1(
            .rst    ( !nSND_RST    ),
            .clk    ( clkm_48MHZ   ),
            .din0   ( sound_outAY0 ),
            .din1   ( sound_outAY3 ), //sound_outAY3 - {1'b0,AY1_IOA_out,1'b0}
				.din2   ( {2'b0,AY1_IOA_out} ), 
            .sample ( AY_0_sample  ),
            .dout   ( audio_snd    )
);

jtframe_jt49_filters u_filters2(
            .rst    ( !nSND_RST    ),
            .clk    ( clkm_48MHZ   ),
            .din0   ( sound_outAY1 ),
            .din1   ( sound_outAY2 ),
            .din2   ( ),				
            .sample ( AY_1_sample  ),
            .dout   ( audio_snd_ext)
);

assign audio_l = (pause) ? 16'd0 : audio_snd;
assign audio_r = (pause) ? 16'd0 : audio_snd_ext;

eprom_4 EB16(
	.ADDR({PRIORITY[3:0],SCN3,SCN2,SCN1,OBJ}),
	.CLK(clkm_48MHZ),//
	.DATA(EB16_out),//

	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_32MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(ep4_cs_i),
	.WR(dn_wr)
);

always @(posedge clkm_6MHZ) begin //clkm_6MHZ
	  case ((PRIORITY[4]) ? EB16_out[3:2] : EB16_out[1:0])
			2'b00: MA <= {MD0, OB[3:0]}; //Sprites
			2'b01: MA <= {MD1,SN1[2:0]}; //Tile Map 1
			2'b10: MA <= {MD2,SN2[2:0]}; //Tile Map 2
			2'b11: MA <= {MD3,SN3[2:0]}; //Tile Map 3
	  endcase
end

reg U46A_Q;
always @(posedge (Z80A_addrbus[0]|VCRRQ|Z80A_WR)) U46A_Q<=Z80A_databus_out[0];
//wire U67_DI8 = Z80A_addrbus[0]|VCRRQ|Z80A_WR;

dpram_dc #(.widthad_a(6),.width_a(16)) U67_RAM //SJ - using 16-bit memory for 9-bit
(
	.clock_a(clkm_48MHZ),
	.address_a(MA),
	.data_a(),
	.wren_a(1'b0),
	.q_a(RGB),
	
	.clock_b(clkm_32MHZ),
	.address_b(Z80A_addrbus[6:1]),
	.data_b({7'b0000000,U46A_Q,Z80A_databus_out}),
	.wren_b(!Z80A_WR & !VCRRQ),
	.q_b()
);

//no blanking logic
wire U68B=!BLANK & VCRRQ;

always @(posedge clkm_6MHZ or negedge U68B) begin
	RED	<=	(!U68B) ? 3'b000 : ~RGB[8:6];
	GREEN	<=	(!U68B) ? 3'b000 : ~RGB[5:3];
	BLUE	<=	(!U68B) ? 3'b000 : ~RGB[2:0];
end	

endmodule
