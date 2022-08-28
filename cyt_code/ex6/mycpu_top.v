module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
wire         reset;
assign reset = ~resetn;

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;
reg  [31:0] pc;

wire [11:0] alu_op;
wire        load_op;
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

assign seq_pc       = pc + 3'h4;   //顺序执行的pc   checked
//更新pc，跳转-->br_target  否则 --> seq_pc(pc+4)
assign nextpc       = br_taken ? br_target : seq_pc;    //checked

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1c000000;     //checked
    end
    else begin
        pc <= nextpc;    //checked
    end
end

assign inst_sram_we    = 1'b0;  //暂时不往内存指令区写内容  checked
assign inst_sram_addr  = pc;    //checked
assign inst_sram_wdata = 32'b0;     //checked
assign inst            = inst_sram_rdata;   //checked

assign op_31_26  = inst[31:26];     //checked
assign op_25_22  = inst[25:22];     //checked
assign op_21_20  = inst[21:20];     //checked
assign op_19_15  = inst[19:15];     //checked

assign rd   = inst[ 4: 0];  //checked
assign rj   = inst[ 9: 5];  //checked
assign rk   = inst[14:10];  //checked

assign i12  = inst[21:10];  //checked
assign i20  = inst[24: 5];  //checked
assign i16  = inst[25:10];  //checked
assign i26  = {inst[ 9: 0], inst[25:10]};   //checked  !!!注意B指令的立即数高低位是反的

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

//add_w: rd = rj + rk   asm: add.w rd, rj, rk
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
//sun_w: rd = rj - rk   asm: sub.w rd, rj, rk
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
//slt: rd = (signed(rj) < signed(rk)) ? 1 : 0  (视作有符号整数比较大小)
//asm: slt rd, rj, rk
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
//sltu: rd = (unsigned(rj) < unsigned(rk)) ? 1 : 0  (视作无符号整数比较大小)
//asm: sltu rd, rj, rk
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
//nor: rd = ~(rj | rk)   asm: nor rd, rj, rk
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
//and: rd = rj & rk  asm: and rd, rj, rk
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
//or: rd = rj | rk  asm: or rd, rj, rk
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
//xor: rd = rj ^ rk  asm: xor rd, rj, rk
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
//slli.w: rd = SLL(rj, ui5)  asm: slli.w rd, rj, ui5
//rj中的数逻辑左移写入rd
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
//srli.w: rd = SRL(rj, ui5)  asm: srli.w rd, rj, ui5
//rj中的数逻辑右移写入rd
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
//srai.w: rd = SRA(rj, ui5)  asm: srai.w rd, rj, ui5
//rj中的数算数右移写入rd
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
//addi.w: rd = rj + SignExtend(si12, 32)  asm: addi.w rd, rj, si12
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
//ld_w: ld.w rd, rj, si12
//vaddr = rj + SignExtend(si12, GRLEN)
//paddr = AddressTranslation(vaddr)
//word = MemoryLoad(paddr, WORD)
//rd = word
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
//st_w: st.w rd, rj, si12
//vaddr = rj + SignExtend(si12, GRLEN)
//paddr = AddressTranlation(vaddr)
//rd --> Mem(paddr)(len:WORD)
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
//jirl: rd, rj, offs16
//rd = pc + 4
//pc = rj + SignExtend({offs16, 2'b0}, GRLEN)
assign inst_jirl   = op_31_26_d[6'h13];
//b: b offs26
//pc = pc + SignExtend({offs26, 2'b0}, GRLEN)
assign inst_b      = op_31_26_d[6'h14];
//bl: bl offs26
//GR[1] = pc + 4
//pc = pc + SignExtend({offs26, 2'b0}, GRLEN)
assign inst_bl     = op_31_26_d[6'h15];
//beq: rj, rd, offs16
//if (rj==rd)
//  pc = pc + SignExtend({offs16, 2'b0}, GRLEN)
assign inst_beq    = op_31_26_d[6'h16];
//bne: rj, rd, offs16
//if (rj==rd)
//  pc = pc + SignExtend({offs16, 2'b0}, GRLEN)
assign inst_bne    = op_31_26_d[6'h17];
//lui2i_w: rd, si20
//rd = {si20, 12'b0}
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

//alu_op[0]  -->  add
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
//alu_op[1]  -->  sub
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

//使用立即数种类选择（checked）
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;   //checked
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;   //checked
assign need_si16  =  inst_jirl | inst_beq | inst_bne;       //checked
assign need_si20  =  inst_lu12i_w;          //checked
assign need_si26  =  inst_b | inst_bl;      //checked
//加法器第二个操作数选择——是否为4（checked）
assign src2_is_4  =  inst_jirl | inst_bl;   //checked

//计算类型指令的立即数选择
assign imm = src2_is_4 ? 32'h4                      :   //checked
             need_si20 ? {i20[19:0], 12'b0}         :   //checked
             need_ui5  ? {27'b0,rk[4:0]}            :   //checked
             need_si12 ? {{20{i12[11]}}, i12[11:0]} :   //checked
             32'b0 ;

//branch的跳转地址目前只有两种——si26与si16
assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :   //checked
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;   //checked
//jirl_offs单独列出主要是因为它不是b类型指令，也方便后序拓展
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};    //checked

//src_reg_is_rd代表reg_file第二个读端口是否接rd，否则接rk
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w; //checked

//alu的第一个操作数是否为pc
//b指令虽然也有pc参与运算，但它直接在跳转处用跳转处的运算器实现了，不用cpu
assign src1_is_pc    = inst_jirl | inst_bl; //checked

assign src2_is_imm   = inst_slli_w |    //checked
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;     //checked
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;   //checked
assign mem_we        = inst_st_w;   //checked
assign dest          = dst_is_r1 ? 5'd1 : rd;   //checked

assign rf_raddr1 = rj;  //checked
assign rf_raddr2 = src_reg_is_rd ? rd : rk; //checked
regfile u_regfile(
    .clk    (clk      ),    //checked
    .raddr1 (rf_raddr1),    //checked
    .rdata1 (rf_rdata1),    //checked
    .raddr2 (rf_raddr2),    //checked
    .rdata2 (rf_rdata2),    //checked
    .we     (rf_we    ),    //checked
    .waddr  (rf_waddr ),    //checked
    .wdata  (rf_wdata )     //checked
    );

assign rj_value  = rf_rdata1;   //checked
assign rkd_value = rf_rdata2;   //checked

//是否跳转，其中beq和bne需要条件
assign rj_eq_rd = (rj_value == rkd_value);  //checkde
assign br_taken = ((inst_beq && rj_eq_rd) || (inst_bne && !rj_eq_rd)    //checked 
                   || inst_jirl || inst_bl || inst_b);        //checked

//计算跳转地址
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) :   //checked
                                                   /*inst_jirl*/ (rj_value + jirl_offs);    //checked

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;    //checked
assign alu_src2 = src2_is_imm ? imm : rkd_value;        //checked

alu u_alu(
    .alu_op     (alu_op    ),    //checked
    .alu_src1   (alu_src1  ),    //fixed
    .alu_src2   (alu_src2  ),    //checked
    .alu_result (alu_result)     //checked
    );

//assign data_sram_en    = (res_from_mem || mem_we) && valid;  (暂时不知道是干嘛的)
assign data_sram_we    = mem_we;   //checked
assign data_sram_addr  = alu_result;    //checked
assign data_sram_wdata = rkd_value;     //checked

assign mem_result   = data_sram_rdata;  //checked
assign final_result = res_from_mem ? mem_result : alu_result;   //checked

assign rf_we    = gr_we;    //checked
assign rf_waddr = dest;     //checked
assign rf_wdata = final_result; //checked

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;

endmodule
