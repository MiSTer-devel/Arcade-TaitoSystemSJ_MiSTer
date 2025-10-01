reg jsr_en;
reg [11:0] jsr_ua, jsr_ret, uaddr;

// wire [4:0] cc_sel;
// wire [3:0] alu_sel;
// wire [1:0] carry_sel;
// wire [1:0] ea_sel;
// wire [4:0] jsr_sel;
// wire [3:0] ld_sel;
// wire [1:0] opnd_sel;
// wire [3:0] rmux_sel;

// wire       op0inv;
// wire       fetch;
// wire       ni;
// wire       swi;
// wire       wr;
// wire       alt;
// wire       branch;
// wire       brlatch;
// wire       alu16;
// wire       halt;
// wire       inc_pc;
// wire       md_shift;

reg  [39:0] ucode_rom[0:2**12-1];
wire [39:0] ucode_data;

initial begin
    $readmemb("6801.uc",ucode_rom);
end

assign ucode_data = ucode_rom[uaddr];

assign op0inv     = ucode_data[ 0+:1];
assign fetch      = ucode_data[10+:1];
assign ni         = ucode_data[13+:1];
assign swi        = ucode_data[14+:1];
assign wr         = ucode_data[15+:1];
assign alt        = ucode_data[16+:1];
assign branch     = ucode_data[17+:1];
assign brlatch    = ucode_data[18+:1];
assign alu16      = ucode_data[19+:1];
assign halt       = ucode_data[20+:1];
assign inc_pc     = ucode_data[34+:1];
assign md_shift   = ucode_data[39+:1];
assign cc_sel     = ucode_data[ 1+:5];
assign alu_sel    = ucode_data[ 6+:4];
assign carry_sel  = ucode_data[11+:2];
assign ea_sel     = ucode_data[21+:2];
assign jsr_sel    = ucode_data[23+:5];
assign ld_sel     = ucode_data[28+:4];
assign opnd_sel   = ucode_data[32+:2];
assign rmux_sel   = ucode_data[35+:4];


always @* begin
    case( jsr_sel )
        IVRD_JSR:    begin jsr_en=1; jsr_ua = 12'h00*12'd16; end 
        IDLE4_JSR:   begin jsr_en=1; jsr_ua = 12'h87*12'd16; end 
        IMM_JSR:     begin jsr_en=1; jsr_ua = 12'h8F*12'd16; end 
        IMM16_JSR:   begin jsr_en=1; jsr_ua = 12'hCF*12'd16; end 
        DIRA_JSR:    begin jsr_en=1; jsr_ua = 12'h45*12'd16; end 
        DIR_JSR:     begin jsr_en=1; jsr_ua = 12'h14*12'd16; end 
        DIR16_JSR:   begin jsr_en=1; jsr_ua = 12'h15*12'd16; end 
        EXTA_JSR:    begin jsr_en=1; jsr_ua = 12'h55*12'd16; end 
        EXT_JSR:     begin jsr_en=1; jsr_ua = 12'h1C*12'd16; end 
        EXT16_JSR:   begin jsr_en=1; jsr_ua = 12'h1D*12'd16; end 
        IDXA_JSR:    begin jsr_en=1; jsr_ua = 12'h4B*12'd16; end 
        IDX_JSR:     begin jsr_en=1; jsr_ua = 12'h1E*12'd16; end 
        IDX16_JSR:   begin jsr_en=1; jsr_ua = 12'h1F*12'd16; end 
        PSH8_JSR:    begin jsr_en=1; jsr_ua = 12'h4E*12'd16; end 
        PSH16_JSR:   begin jsr_en=1; jsr_ua = 12'h02*12'd16; end 
        PUL8_JSR:    begin jsr_en=1; jsr_ua = 12'h03*12'd16; end 
        PUL16_JSR:   begin jsr_en=1; jsr_ua = 12'h41*12'd16; end 
        IDLE6_JSR:   begin jsr_en=1; jsr_ua = 12'h42*12'd16; end 
        RTI8_JSR:    begin jsr_en=1; jsr_ua = 12'h51*12'd16; end 
        RET_JSR:     begin jsr_en=1; jsr_ua = jsr_ret; end
        default:     begin jsr_en=0; jsr_ua = 'h00; end
    endcase
end
