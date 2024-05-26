module obj_bus (
	//clocks
	input clkm_48MHZ,
	input clkm_32MHZ,
	input clkm_6MHZ,					//pixel clock
	input clkb_6MHZ,			
	input CLK2,
	input [8:0] syncbus_HN,			//H.BL=![8],HBL=[8],128HN=[7],64=[6],32=[5],16=[4],8=[3],4=[2],2=[1],1HN=[0]
	input [7:0] syncbus_PH,	
	input [7:0] syncbus_V,			//128V=[7],64V=[6],32V=[5],16V=[4],8V=[3],4V=[2],2V=[1],1V=[0]
	input [15:0] Z80A_addrbus,
	input [7:0] Z80A_databus_out,
	input Z80A_WR,
	input OBJRQ,
	input SOFF,
	input [2:0] QBUS,
	
	output [12:0] OBJ_CHA, 			//extra 2 bits bit 12 for syncing, bit 11 for OBJCH
	output [7:0] Z80A_OD_out,
	output OBJ_CINV,
	output INRANG,

	output reg SN3OFF,
	output reg SN2OFF,
	output reg SN1OFF,
	output reg VINV,
	output reg HINV,
	output HITOB,
	output reg [3:0] OB	

);
//*OBJECT CHA/DATABUS - Creates object RAM addresses loaded into CHA at specific times (PH3)
//internal registers
wire [7:0] ODout,nOD_L1,nOD_L2,U69_ADDR,U41_ADDR;
reg  [7:0] QX_bus,OD_L1,OD_L2;
wire [7:0] OD_L1_ADDR,OD_L2_ADDR;

reg OBJOFF,OBJEX,U32_Q6,U32_Q7,OMD,VINVx,HINVx,SDUMMY,LNSL1,LNSL2,line_clock,U7B_Q,PHA348;
wire LNLD1,LNLD2,LNCL1,LNCL2,U7A_Q,U39C,U19B,OBJH;
wire [3:0] U69_DATA_out,U69_DATA_in,U41_DATA_out,U41_DATA_in;

wire [7:0] U83_Qin,U83_Q;
wire [5:0] U99_out;
wire OMD1,OD1_PH7,OBJCH;


always @(posedge SOFF) {OBJOFF,SN3OFF,SN2OFF,SN1OFF,SDUMMY,OBJEX,VINVx,HINVx} = Z80A_databus_out; //U32 internal to object bus

//reg [8:0] syncbus_HN,syncbus_HN_1,syncbus_HN_2;
//always @(posedge clkm_48MHZ) syncbus_HN<=syncbus_HN;


//This ram stores the sprite location, sprite index and additional attributes.
//The ram is written to once per line by the Z80 and read and sent to the sprite
//hardware based on the scan-line horizontal position
dpram_dc #(.widthad_a(8)) U1817_RAM //SJ - object data ram
(
	.clock_a(clkm_48MHZ),
	.address_a({OBJEX,!syncbus_HN[8],syncbus_HN[7:4],!syncbus_HN[2],syncbus_HN[1]}),
	.data_a(),
	.wren_a(1'b0),
	.q_a(ODx),
	
	.clock_b(clkm_32MHZ),
	.address_b({Z80A_addrbus[7:2],(Z80A_addrbus[1]^!Z80A_addrbus[0]),!Z80A_addrbus[0]}),
	.data_b(Z80A_databus_out),
	.wren_b(!Z80A_WR & !OBJRQ),
	.q_b(Z80A_OD_out)
);

wire [7:0] ODx;
reg [7:0] OD,OD_1,OD_2,OD_PH1,OD_PH5,OD_PH7;

//maybe OD needs metastability
always @(posedge clkm_48MHZ) begin
	OD_2<=ODx;
	OD_1<=OD_2;
	OD<=OD_1;
end

//capture OD in 'Phase 1' once per horizontal slice of sprite (everything else is captured every 8 pixels)
wire syncph1=(syncbus_HN[3:0]==4'b1010); //b1010 - b1001
always @(posedge syncph1) OD_PH1<=OD; //syncbus_PH[1]|!syncbus_HN[3] //|!syncbus_HN[3]
always @(posedge syncbus_PH[5]) OD_PH5<=OD+syncbus_V+1; //-1 made issues worse +1 didn't do anything and +2 went to far
always @(posedge syncbus_PH[7]) OD_PH7<=OD;

assign U83_Q     = (!OBJRQ) ? 8'b00000000 : {OD_PH5[7:4],OD_PH5[3:0]^{4{OD1_PH7}}};
assign INRANG    = !(&U83_Q[7:4]);
assign {OMD1,OD1_PH7,OBJ_CINV}      = OD_PH7[2:0];

assign	OBJ_CHA={1'b0,OD_PH1[6:0],U83_Q[3],!syncbus_HN[3]^OBJ_CINV,U83_Q[2:0]}; //,U83_Q[1]^OD1_PH7,U83_Q[0]^OD1_PH7

always @(posedge syncbus_PH[3]) begin
	OMD<=OMD1;  
	VINV<=VINVx;
	HINV<=HINVx;
end	

wire U39D,nline_clock;

always @(posedge syncbus_HN[3] or posedge syncbus_HN[8]) line_clock<=(!(&syncbus_HN[6:4]))|syncbus_HN[8];  //U7A
assign nline_clock=!line_clock;
always @(posedge nline_clock) U7B_Q<=syncbus_V[0]; //changed line (inverted V1)

assign 	U39D	=	!syncbus_HN[3]|(|syncbus_PH[4:3]);
assign	U39C 	=	U39D|line_clock;
assign   U19B	=	U39C|clkm_6MHZ;
	
always @(posedge U19B)begin
	LNSL1<= U7B_Q;
	LNSL2<=!U7B_Q;
end

assign LNCL1=!U7B_Q | U39C;
assign LNCL2= U7B_Q | U39C;

assign LNLD2=!U7B_Q | U39D;
assign LNLD1= U7B_Q | U39D;

assign nOD_L1=OD_L1+8'd1;
assign nOD_L2=OD_L2+8'd1;

always @(posedge clkm_6MHZ or negedge LNCL1 or negedge LNLD1) OD_L1<=(!LNCL1) ? 8'b00000000 : (!LNLD1) ? OD : nOD_L1;
always @(posedge clkm_6MHZ or negedge LNCL2 or negedge LNLD2) OD_L2<=(!LNCL2) ? 8'b00000000 : (!LNLD2) ? OD : nOD_L2;

//assign OD_L1_ADDR=(LNSL1&HINV) ? ~OD_L1:OD_L1;
//assign OD_L2_ADDR=(LNSL2&HINV) ? ~OD_L2:OD_L2;

assign OBJH				=	(LNSL1) ? !(|QX_bus[6:4]) : !(|QX_bus[2:0]);
assign U69_DATA_in 	= 	(LNSL1) ? 4'b0000 : (OBJH) ? {OMD,QBUS[2:0]}:QX_bus[3:0];
assign U41_DATA_in 	= 	(LNSL2) ? 4'b0000 : (OBJH) ? {OMD,QBUS[2:0]}:QX_bus[7:4];
assign HITOB			=	!(|QBUS[2:0])|OBJH;

//line #1 buffer
m5501_ram U69_RAM(
	.data(U69_DATA_in),
	.clk(clkm_48MHZ),
	.addr((LNSL1&HINV) ? ~OD_L1:OD_L1),
	.nWE(clkm_6MHZ),
	.q(U69_DATA_out)
);

//line #2 buffers
m5501_ram U41_RAM(
	.data(U41_DATA_in),
	.clk(clkm_48MHZ),
	.addr((LNSL2&HINV) ? ~OD_L2:OD_L2),
	.nWE(clkm_6MHZ),
	.q(U41_DATA_out)
);

always @(posedge clkb_6MHZ) QX_bus	<=	(!OBJOFF) 	? 8'b00000000 : {U41_DATA_out,U69_DATA_out};
always @(posedge clkm_6MHZ) OB	 	<= (LNSL2) 		? QX_bus[7:4] : QX_bus[3:0]; 
	
endmodule
