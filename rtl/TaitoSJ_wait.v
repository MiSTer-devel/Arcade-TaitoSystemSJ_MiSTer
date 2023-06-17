//WAIT STATES
reg U85A_Q,U85B_Q,U90A_Q,U90B_Q,U89A_Q,U92B_Q;
wire nREAD=!READ;
wire nCHARQ=!CHARQ;
wire U91_wait_n;

always @(posedge clkm_4MHZ or negedge U85B_Q) begin 
	U85A_Q <= (!U85B_Q) ? 1'b1 : Z80A_M1;

end

always @(posedge clkm_4MHZ) U85B_Q <= U85A_Q;
always @(posedge clkm_4MHZ or negedge nREAD) begin
	U90A_Q <= (!nREAD) ? 1'b1 : 1'b0;
	U90B_Q <= (!nREAD) ? 1'b1 : U90A_Q;
	U89A_Q <= (!nREAD) ? 1'b1 : U90B_Q;
end

 
reg U92A_Q;
wire U61A,U96C;

always @(posedge syncbus_PH[6] or negedge nCHARQ) U92A_Q<=(!nCHARQ) ? 1'b1 : 1'b0;
assign U61A=!(U92A_Q|syncbus_PH[3]);
always @(posedge clkm_4MHZ or negedge nCHARQ) U92B_Q <= (!nCHARQ) ? 1'b1 : U61A;

wire U84B = (!Z80A_addrbus[12]|CDR1_2);
wire U62A = !(WCD3_6&U84B);
reg U93B_Q,U93A_Q;

always @(posedge syncbus_PH[0] or negedge U62A) U93B_Q <= (!U62A) ? 1'b1 : 1'b0;
wire U84A=!(U93B_Q|syncbus_PH[5]);
always @(posedge clkm_4MHZ or negedge U62A) U93A_Q <= (!U62A) ? 1'b1 : U84A;

assign U91_wait_n=!(!U85A_Q|(nREAD&U89A_Q)|(nCHARQ&U92B_Q)|(U93A_Q&U62A));
