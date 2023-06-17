module hit_bus(
	input clkm_6MHZ,	
	input clkb_6MHZ,
	input OBJ,
	input SCN1,
	input SCN2,
	input SCN3,
	input HTCLR,
	input HLP0,
	input HLP1,
	input HLP2,	
	input HITOB,
	input HTRRQ,
	input [4:0] syncbus_HM,  //HBL=[4],128HM=[3],64HM=[2],32HM=[1],16HM=[0]
	input [1:0] ADDR_ED,
	output reg [7:0] HIT_DATA
);

//	PH <= ({PH[6:0],!(&HPIX[2:1])});

//for clock low all the time:
//reset going low sets all outputs low
//preset going high transfers all active high inputs to outputs , lows are not, so this is basically an OR
wire HITON,HITCLEAR;
wire [7:0] HD;
reg  [7:0] H0X, H1X, H2X, HOBJ;
reg  [15:0] HITREG;

always @(posedge clkm_6MHZ) HITREG<={HITREG[14:0],HITOB};
assign HITON=!(&HITREG[14:0]);

mux1_8 U34(
	.nEN(1'b0),
	.nRST(1'b0),
	.D(HITON),
	.A(syncbus_HM[2:0]),
	.Q(HD)
);

assign HITCLEAR=!HTCLR;

always @(posedge clkb_6MHZ or posedge HITCLEAR) HOBJ<=(HITCLEAR) ? 8'b00000000:HOBJ|({2'b00,!(SCN2|SCN3),!(SCN3|SCN1),!(SCN2|SCN1),!(OBJ|SCN3),!(OBJ|SCN2),!(OBJ|SCN1)});

always @(posedge HLP0 or posedge HITCLEAR)      H0X <=(HITCLEAR) ? 8'b00000000:H0X|HD;
always @(posedge HLP1 or posedge HITCLEAR)      H1X <=(HITCLEAR) ? 8'b00000000:H1X|HD;
always @(posedge HLP2 or posedge HITCLEAR)      H2X <=(HITCLEAR) ? 8'b00000000:H2X|HD;

always @(*) begin //clkm_6MHZ
	  case (ADDR_ED[1:0])
			2'b00: HIT_DATA <= H0X; 
			2'b01: HIT_DATA <= H1X; 
			2'b10: HIT_DATA <= H2X; 
			2'b11: HIT_DATA <= HOBJ; 
	  endcase
end

endmodule

