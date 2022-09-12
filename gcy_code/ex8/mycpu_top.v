module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire  [3:0]   inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    output  wire    inst_sram_en,
    // data sram interface
    output wire  [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    output  wire   data_sram_en,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
//assign reset = ~resetn;
always @(posedge clk) 
    begin
        reset <= ~resetn;
        end

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;
reg  [31:0] pc;

wire [11:0] alu_op;
//wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] mem_result;
wire [31:0] final_result;

reg [63:0] DE;
reg [179:0] EX;
reg [135:0] MEM;
reg [101:0]  WB;
wire [31:0] de_inst;
wire [31:0] rdata1;
wire [31:0] rdata2;

reg de_readygo;
reg ex_readygo;
reg mem_readygo;
reg wb_readygo;

wire isadv;

assign isadv = (EX[32]&&((EX[37:33] == rf_raddr1)||(EX[37:33] == rf_raddr2))&&EX[37:33]!=5'b0)?1'b1:1'b0;
assign de_inst = DE[31:0];


assign seq_pc       = pc+3'h4;
assign nextpc       = reset?pc+3'h4 : isadv? pc : br_taken ? br_target : seq_pc;

always @(posedge clk) begin
    if (~resetn) begin
        pc <= 32'h1bfffffc; 
    end
    else 
        pc <= nextpc;
end

assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst            = inst_sram_rdata;

assign op_31_26  = de_inst[31:26];
assign op_25_22  = de_inst[25:22];
assign op_21_20  = de_inst[21:20];
assign op_19_15  = de_inst[19:15];

assign rd   = de_inst[ 4: 0];
assign rj   = de_inst[ 9: 5];
assign rk   = de_inst[14:10];

assign i12  = de_inst[21:10];
assign i20  = de_inst[24: 5];
assign i16  = de_inst[25:10];
assign i26  = {de_inst[ 9: 0], de_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~de_inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk ;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );
assign rdata1 = (rf_we&&(rf_waddr == rf_raddr1)&&(rf_raddr1!=5'b0))?rf_wdata:rf_rdata1;
assign rdata2 = (rf_we&&(rf_waddr == rf_raddr2)&&(rf_raddr2!=5'b0))?rf_wdata:rf_rdata2;

assign rj_value  = rdata1;
assign rkd_value = rdata2;

assign rj_eq_rd = (rdata1 == rdata2);
assign br_taken =  (~de_readygo)?
                    1'b0    :
                    inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (DE[63:32] + br_offs) :
                                                   /*inst_jirl*/ (rdata1 + jirl_offs);

assign alu_src1 = src1_is_pc  ? DE[63:32] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (EX[51:40] ),
    .alu_src1   (EX[83:52]  ),
    .alu_src2   (EX[115:84] ),
    .alu_result (alu_result)
    );

//assign data_sram_en    = mem_we;
assign data_sram_we    = {4{EX[39]}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = EX[179:148];

assign mem_result   = data_sram_rdata;
assign final_result = MEM[38] ? mem_result : MEM[71:40];

assign rf_we    = MEM[32];
assign rf_waddr = MEM[37:33];
assign rf_wdata = final_result;

// debug info generate
assign debug_wb_pc       = WB[101:70];
assign debug_wb_rf_we   = {4{WB[32]}};
assign debug_wb_rf_wnum  = WB[37:33];
assign debug_wb_rf_wdata = WB[69:38];

//mycode
always@(posedge clk)
begin
    if(reset)
        DE <= {pc,32'b0};
    else
    begin
        if(~br_taken && ~isadv)
        begin
            DE <= {pc,inst};
        end
        else
        begin
            DE<=DE;
        end
    end
end

always@(posedge clk)
begin
    if(reset)
    begin
        EX[147:116]<= DE[63:32];
        EX[115:0] <= 116'b0;
        EX[179:148] <= 32'b0;
    end
    else
    begin
        if(~br_taken&&~isadv)
        begin
        EX[31:0] <= DE[31:0];
        EX[115:32] <= {alu_src2,alu_src1,alu_op,mem_we,res_from_mem,dest,gr_we};
        EX[147:116] <= DE[63:32];
        EX[179:148] <= rkd_value;
        end
        else
        begin
        EX[179:0] <= 180'b0;
        end
    end
end

always@(posedge clk)
begin
    if(reset)begin
        MEM[135:104] <= EX[147:116];
        MEM[103:0] <= 104'b0;
        end
    else
    begin
             MEM[31:0]  <= EX[31:0];
             MEM[103:32] <= {rkd_value,alu_result,EX[39:32]};
             MEM[135:104] <= EX[147:116];
    end
end
always@(posedge clk)
begin
    if(reset)begin
        WB[101:70] <= MEM[135:104];
        WB[69:0] <= 70'b0;
        end
    else
    begin

        WB[31:0]  <= MEM[31:0];
        WB[69:32] <= {final_result,MEM[37:32]};
        WB[101:70] <= MEM[135:104];
    end
end

assign data_sram_en =1'b1;
assign inst_sram_en =1'b1;

always@(posedge clk)
begin
    ex_readygo <=1'b1;
    mem_readygo <=1'b1;
    wb_readygo <=1'b1;
end
//adv优先级较高
always@(posedge clk)
begin
    if(br_taken&~isadv)
        de_readygo <= 1'b0;
    else 
        de_readygo <= 1'b1;
end

endmodule
