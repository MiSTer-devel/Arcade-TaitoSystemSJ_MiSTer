module game_sound (
	//clocks
	input clkm_48MHZ,			//master clock
	input clkm_32MHZ,			//sys_clk
	input clkm_3MHZ,			//sound CPU clock
	input clkb_3MHZ, 
	input clkm_1p5MHZ,		//AY clock
	
	//control inputs
	input nSND_RST,
	input EPORT1,
	input EPORT2,
	
	//ROM download handling
	input [15:0] CPU_ADDR,
	input  [7:0] CPU_DIN,
	input [24:0] dn_addr,
	input [7:0] dn_data,
	input snd_prom_cs_i,
	input dn_wr,

	input pause,

	output [9:0] sound_outAY1,
	output [9:0] sound_outAY2,
	output [9:0] sound_outAY3,
	output AY_1_sample,
	output AY_2_sample,
	output AY_3_sample,

	output [7:0] AY1_IOA_out,
	output [7:0] AY2_IOA_out	

);


wire [7:0] AY1_IOB_out,AY3_IOA_out,AY3_IOB_out;
wire Z80B_MREQ,Z80B_WR,Z80B_RD,Z80B_IOREQ,Z80B_RFSH,Z80B_BUSACK,Z80B_BUSRQ,Z80B_M1;
wire Z80B_INT;
wire Z80B_NMI;
wire [15:0] Z80B_addrbus;
wire [7:0] Z80B_databus_in,Z80B_databus_out,Z80B_RAM_out;

// *************** Sound CPU Chip Selects	***************									
wire SND_ROM,SND_RAM;
reg CS5000,CS5001;
reg RD5000,RD5001,WR5000,WR5001;
reg AY_1_SEL,AY_2_SEL,AY_3_SEL,DIAGROM;
wire AY_1_BC1,AY_2_BC1,AY_3_BC1,AY_1_BDIR,AY_2_BDIR,AY_3_BDIR;

assign SND_ROM 	= (Z80B_addrbus[15:14] == 2'b00); 					//Select Sound ROMS 00000-16383 	0x0000 - 0x3FFF
assign SND_RAM 	= (Z80B_addrbus[15:10] == 6'b010000); 				//Select Sound RAM  16383-17407	0x4000 - 0x43FF

// ***************** Sound CPU Databus ******************
assign Z80B_databus_in =		(SND_ROM		&	!Z80B_RD 	&	!Z80B_MREQ)		? SND_PROG_ROM_data :
										(SND_RAM		&	!Z80B_RD 	             )  	? SND_RAM_out :
										(AY_1_SEL	&	!Z80B_RD 					 )  	? AY_1_databus_out :
										(AY_2_SEL	&	!Z80B_RD 					 )  	? AY_2_databus_out :										
										(AY_3_SEL	&	!Z80B_RD 					 )  	? AY_3_databus_out :
										(!RD5000											 )   	? DATA5000 :
										(!RD5001											 )   	? DATA5001 :	
										(DIAGROM											 )   	? SND_PROG_ROM_data :	
										8'b00000000;

always @(posedge clkm_48MHZ) begin
	AY_1_SEL   <= (Z80B_addrbus[15:1] == 15'b010010000000000);  //0x4800 & 0x4801
	AY_2_SEL   <= (Z80B_addrbus[15:1] == 15'b010010000000001);	//0x4802 & 0x4804
	AY_3_SEL   <= (Z80B_addrbus[15:2] == 14'b01001000000001);	//0x4804 & 0x4805
	DIAGROM    <= (Z80B_addrbus[15:14] == 3'b111);					//0x4804 & 0x4805
	RD5000	  <= (Z80B_addrbus == 16'h5000) ? Z80B_RD : 1'b1;
	RD5001	  <= (Z80B_addrbus == 16'h5001) ? Z80B_RD : 1'b1;	
	WR5000	  <= (Z80B_addrbus == 16'h5000) ? Z80B_WR : 1'b1;
	WR5001	  <= (Z80B_addrbus == 16'h5001) ? Z80B_WR : 1'b1;		
end

//Second Z80 CPU responsible for audio
//Z80B (Audio CPU)
reg [15:0] int_counter;
reg int_freq;

always @(posedge clkm_1p5MHZ)       int_counter <= (int_counter==16'b1010000000000000) ? 16'd0 : int_counter+1;
always @(posedge clkm_1p5MHZ)		 	int_freq 	<= int_counter[15:0] == 16'd0;		
  
//always @(posedge int_counter[11]) int_course  <= int_course+1;
wire Z80B_INT_SET=Z80B_M1|Z80B_IOREQ;

reg rZ80B_INT=1'b1;
always @(posedge int_freq or negedge Z80B_INT_SET) begin
	rZ80B_INT<=(!Z80B_INT_SET) ? 1'b1 : 1'b0;
end

assign Z80B_INT=rZ80B_INT;

T80pa Z80B(
	.RESET_n(nSND_RST),
	.WAIT_n(!pause),
	.INT_n(Z80B_INT),
	.BUSRQ_n(1'b1),
	.NMI_n(Z80B_NMI), 
	.CLK(clkm_48MHZ), 
	.CEN_p(clkm_3MHZ), 
	.CEN_n(clkb_3MHZ), 
	.MREQ_n(Z80B_MREQ),
	.M1_n(Z80B_M1),
	.IORQ_n(Z80B_IOREQ),
	.DI(Z80B_databus_in),
	.DO(Z80B_databus_out),
	.A(Z80B_addrbus),
	.WR_n(Z80B_WR),
	.RD_n(Z80B_RD)
);



wire [7:0] SND_PROG_ROM_data;
eprom_3 SND_PROG_ROM  //Sound EPROM
(
	.ADDR(Z80B_addrbus[13:0]),
	.CLK(clkm_48MHZ),
	.DATA(SND_PROG_ROM_data),

	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_32MHZ),
	.DATA_IN(dn_data),
	.CS_DL(snd_prom_cs_i),		//load data into ROM
	.WR(dn_wr)
);

//Sound CPU (Z80B) work RAM - dual port RAM to main CPU (alternative configuration)

wire [7:0] SND_RAM_out;

dpram_dc #(.widthad_a(10)) S2_U11B //sf
(
	.clock_a(clkm_48MHZ),
	.address_a(Z80B_addrbus[9:0]),
	.data_a(Z80B_databus_out),
	.wren_a(!Z80B_WR & SND_RAM),
	.q_a(SND_RAM_out)
	
//	.clock_b(clkm_48MHZ),
//	.address_b(Z80A_addrbus[10:0]),
//	.data_b(Z80A_databus_out),
//	.wren_b(!AUDIOM_OK & !Z80_WR),
//	.q_b(AUDIO_RAMM_out)
);

reg  [7:0] DATA5000;
wire [7:0] DATA5001;
reg  DB3,DB2;

always @(posedge EPORT1 or negedge WR5000)  begin
	     if(!WR5000) DATA5000[7] <= 1'b0;
        else DATA5000[7] <= CPU_DIN[7];
end

always @(posedge EPORT1) DATA5000[6:0]<=CPU_DIN[6:0];
wire SB2RST = (WR5001&nSND_RST);

always @(posedge EPORT2 or negedge SB2RST) begin
	     if(!SB2RST) DB2 <= 1'b0;
        else DB2 <= CPU_DIN[0];
end

always @(posedge EPORT1 or negedge RD5000) begin
	     if(!RD5000) DB3 <= 1'b0;
        else DB3 <= 1'b1;
end

assign DATA5001 = {4'b1111,DB3,DB2,2'b11};

assign Z80B_NMI=!((!(AY3_IOB_out[0]|!DB3))|DB2);

assign AY_1_BC1 	= AY_1_SEL	&	!Z80B_addrbus[0]&!Z80B_WR; //|(Z80B_addrbus[0]&!Z80B_RD));
assign AY_2_BC1 	= AY_2_SEL	&	!Z80B_addrbus[0]&!Z80B_WR; //|(Z80B_addrbus[0]&!Z80B_RD));
assign AY_3_BC1 	= AY_3_SEL	&	!Z80B_addrbus[0]&!Z80B_WR; //|(Z80B_addrbus[0]&!Z80B_RD));

assign AY_1_BDIR	= AY_1_SEL	&	!Z80B_WR;
assign AY_2_BDIR	= AY_2_SEL	&	!Z80B_WR;
assign AY_3_BDIR	= AY_3_SEL	&	!Z80B_WR;


//*************** Sound chips (JT49) ***************
wire [7:0] AY_1_databus_out;
wire [7:0] AY_2_databus_out;
wire [7:0] AY_3_databus_out;

jt49_bus AY_1(
    .rst_n(nSND_RST),
    .clk(clkm_48MHZ),						// signal on positive edge 
    .clk_en(clkm_1p5MHZ),  				/* synthesis direct_enable = 1 */
    
    .bdir(AY_1_BDIR),						// bus control pins of original chip
    .bc1(AY_1_BC1),
	 .din(Z80B_databus_out),
    .sel(1'b1), 								// if sel is low, the clock is divided by 2
    .dout(AY_1_databus_out),
    
	 .sound(sound_outAY1),  					// combined channel output
    .A(),    									// linearised channel output
    .B(),
    .C(),
    .sample(AY_1_sample),

    .IOA_out(AY1_IOA_out),					//OUT2 - DA OUT
    .IOB_out(AY1_IOB_out)					//OUT2 - PSG2
);

jt49_bus AY_2(
    .rst_n(nSND_RST),
    .clk(clkm_48MHZ),						// signal on positive edge
    .clk_en(clkm_1p5MHZ),  				/* synthesis direct_enable = 1 */
    
    .bdir(AY_2_BDIR),	 					// bus control pins of original chip
    .bc1(AY_2_BC1),
	 .din(Z80B_databus_out),
    .sel(1'b1), 								// if sel is low, the clock is divided by 2
    .dout(AY_2_databus_out),
    
	 .sound(sound_outAY2),  					// combined channel output
    .A(),      								// linearised channel output
    .B(),
    .C(),
    .sample(AY_2_sample),

    .IOA_out(AY2_IOA_out),					//Control Inputs #54,55,56 & 57
    .IOB_out()									//

);

jt49_bus AY_3(
    .rst_n(nSND_RST),
    .clk(clkm_48MHZ),						// signal on positive edge
    .clk_en(clkm_1p5MHZ),  				/* synthesis direct_enable = 1 */
    
    .bdir(AY_3_BDIR),	 					// bus control pins of original chip
    .bc1(AY_3_BC1),
	 .din(Z80B_databus_out),
    .sel(1'b1), 								// if sel is low, the clock is divided by 2
    .dout(AY_3_databus_out),
    
	 .sound(sound_outAY3),  					// combined channel output
    .A(),      								// linearised channel output
    .B(),
    .C(),
    .sample(AY_3_sample),

    .IOA_out(AY3_IOA_out),					//
    .IOB_out(AY3_IOB_out)					//

);

endmodule
