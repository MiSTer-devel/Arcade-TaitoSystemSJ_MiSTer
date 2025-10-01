module sync_bus (
	//clocks
	input clkm_48MHZ,
	input clkm_6MHZ,			//master clock
	input clkb_6MHZ,			//master clock	
	input CLK2,
	input CLK3,
	input clkm_3MHZ,			//pixel_clk?
	input RESET_n,
	input SPH1,
	input SPH2,
	input SPH3,	
	input VINV,
	input HINV,
	input [7:0] Z80A_DATABUS,
	
	output [8:0] SB_HN, 		//128HN=[7],64=[6],32=[5],16=[4],8=[3],4=[2],2=[1],1HN=[0]
	output [7:0] SB_H, 		//128H=[7],64=[6],32=[5],16=[4],8=[3],4=[2],2=[1],1H=[0]
	output reg [4:0] SB_HM, //HBL=[4],128HM=[3],64HM=[2],32HM=[1],16HM=[0]
	output [7:0] SB_V,		//128V=[7],64V=[6],32V=[5],16V=[4],8V=[3],4V=[2],2V=[1],1V=[0]
	output reg [7:0] PH,
	output VSYNC,
	output HSYNC,
	output reg VBL,					//V.BL
	output HBL,					//H.BL
	output BLANK,
	output SN1LD,
	output SN2LD,
	output SN3LD,
	output reg PH01,
	output reg PH23,
	output reg PH45,	
	output reg PH67,
	output HLP0,
	output HLP1,	
	output HLP2
);

reg rHSYNC;
//reg VBL;
//reg rVCLK;
reg [8:0] HPIX;
reg [8:0] VPIX;
//(!RESET_n) ? 9'd0 :
				 
always @(posedge clkm_6MHZ) HPIX <= (HPIX==9'd511) ? {9'd128} : HPIX+9'd1; //was d128
always @(posedge clkm_6MHZ) PH <= ({PH[6:0],!(&HPIX[2:1])});

reg nVINC,VTOG;

always @(posedge HPIX[0] or negedge HBL) begin
	if(!HBL) nVINC <= 1;
	else nVINC<=!(&HPIX[6:4]);
end

wire VINC=!nVINC;

always @(posedge VINC) VPIX<=(VPIX==9'd511) ? 9'd248 : VPIX+9'd1;


//assign PHA34 = (|PH[4:3]);	
assign HSYNC = ((HPIX>=160)&(HPIX<=192)); //192	

always @(posedge VPIX[4]) VBL<=(&VPIX[7:5]); //VN128&VN64&VN32

assign VSYNC = VPIX[8];//VNSYNC;

assign SB_HN = HPIX[8:0];
assign HBL   = !HPIX[8];
assign SB_H  = HINV ? ~HPIX[7:0] : HPIX[7:0];
assign SB_V  = VINV ? ~VPIX[7:0] : VPIX[7:0];
assign BLANK = VBL|HBL;

//724 BUS
reg [2:0] DH1,DH2,DH3;
always @(posedge SPH1) DH1 <= Z80A_DATABUS[2:0];
always @(posedge SPH2) DH2 <= Z80A_DATABUS[2:0];
always @(posedge SPH3) DH3 <= Z80A_DATABUS[2:0];

assign SN1LD =(DH1!=HPIX[2:0]);
assign SN2LD =(DH2!=HPIX[2:0]);
assign SN3LD =(DH3!=HPIX[2:0]);

always @(posedge CLK3) begin //clkb_6MHZ
	PH23  <= (|PH[3:2]);
	PH01  <= (PH[0]);
	PH45  <= (PH[4]);
	PH67  <= (PH[6]);
end

wire syncHM=(|PH[4:3])|!HPIX[3];
wire [3:0] U26_Q;

always @(posedge syncHM) SB_HM<=HPIX[8:4];

ls139x U26A(
	.A({!SB_HM[4],SB_HM[3]}),
  	.nE(syncHM|VBL),
  	.Y(U26_Q)
);

assign HLP0 = !(clkm_6MHZ|U26_Q[0]);
assign HLP1 = !(clkm_6MHZ|U26_Q[1]);
assign HLP2 = !(clkm_6MHZ|U26_Q[3]);

endmodule
