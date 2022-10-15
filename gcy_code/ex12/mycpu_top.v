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
wire [2:0]  load_op;
wire [2:0]  store_op;
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
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_w;
wire        inst_st_b;
wire        inst_st_h;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_lu12i_w;
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_mod_w;
wire        inst_div_wu;
wire        inst_mod_wu;
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;


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

reg [63:0] IDreg;
reg [241:0] EXEreg;
reg [156:0] MEMreg;
reg [103:0]  WBreg;
wire [31:0] id_inst;
wire [31:0] rdata1;
wire [31:0] rdata2;
wire [32:0] mul1;
wire [32:0] mul2;
wire [1:0]  mulop;
wire [65:0] mul_result;
wire [31:0] EXE_result;
wire [2:0] divop;
wire [1:0] mem_addr;
wire [31:0] mem_b_off;
wire [31:0] mem_h_off;
wire [31:0] st_data;

reg br_go;
wire id_readygo;
wire ex_readygo;
wire mem_readygo;
wire wb_readygo;

//除法模块
wire signed_dividend_tvalid, unsigned_dividend_tvalid;
wire signed_divisor_tvalid, unsigned_divisor_tvalid;
wire signed_dividend_tready, unsigned_dividend_tready;
wire signed_divisor_tready, unsigned_divisor_tready;
wire signed_out_tvalid, unsigned_out_tvalid;

reg dividend_valid_reg;
reg divisor_valid_reg;
reg udividend_valid_reg;
reg udivisor_valid_reg;

wire [31:0] div_result;
wire [31:0] dividend;
wire [31:0] divisor;
wire [63:0] signed_result, unsigned_result;
wire [31:0] signed_div_result, unsigned_div_result;
wire [31:0] signed_mod_result, unsigned_mod_result;
wire div_stop;
//除法结束

//CSR相关代码
reg is_ret;
wire ready_back;
wire has_back;
wire ready_exception;
wire has_exception;
wire src1_is_zero;
wire [13:0] csr_num;
wire [13:0] csr_wnum;
wire csrw_en;
wire csrr_en;
wire csrm_en;
wire ertn_flush;
wire [31:0] csr_rdata;
wire [31:0] csr_wdata;
wire [31:0] csr_mask;
wire csr_inst;

wire isadv;
wire isEXEw;
assign isadv = ((EXEreg[239]||(EXEreg[70]))&&EXEreg[64]&&((EXEreg[69:65] == rf_raddr1)||(EXEreg[69:65] == rf_raddr2))&&EXEreg[69:65]!=5'b0);
assign isEXEw = (~EXEreg[239])&&(~EXEreg[70])&&EXEreg[64]&&((EXEreg[69:65] == rf_raddr1)||(EXEreg[69:65] == rf_raddr2))&&EXEreg[69:65]!=5'b0;

assign id_inst = IDreg[31:0];
assign seq_pc       = pc+3'h4;
assign nextpc       = reset?pc+3'h4 : (has_back||has_exception)? csr_rdata: (isadv||~id_readygo)? pc :  br_taken ? br_target : seq_pc;

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

assign op_31_26  = id_inst[31:26];
assign op_25_22  = id_inst[25:22];
assign op_21_20  = id_inst[21:20];
assign op_19_15  = id_inst[19:15];

assign rd   = id_inst[ 4: 0];
assign rj   = id_inst[ 9: 5];
assign rk   = id_inst[14:10];

assign i12  = id_inst[21:10];
assign i20  = id_inst[24: 5];
assign i16  = id_inst[25:10];
assign i26  = {id_inst[ 9: 0], id_inst[25:10]};

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
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_b  = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h  = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~id_inst[25];

assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_pcaddu12i= op_31_26_d[6'h07] & ~id_inst[25];

assign inst_csrrd  = op_31_26_d[6'h01] & ~id_inst[25] & ~id_inst[24] & (id_inst[9:5] == 5'h0);
assign inst_csrwr  = op_31_26_d[6'h01] & ~id_inst[25] & ~id_inst[24] & (id_inst[9:5] == 5'h1);
assign inst_csrxchg= op_31_26_d[6'h01] & ~id_inst[25] & ~id_inst[24] & ~(id_inst[9:6] == 4'b0000);
assign inst_ertn   = id_inst == 32'h6483800;
assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl | inst_pcaddu12i 
                    | inst_ld_b | inst_ld_h |inst_ld_bu | inst_ld_hu
                    | inst_st_b | inst_st_h | inst_csrrd | inst_csrwr | inst_csrxchg;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll;
assign alu_op[ 9] = inst_srli_w | inst_srl;
assign alu_op[10] = inst_srai_w | inst_sra;
assign alu_op[11] = inst_lu12i_w;

assign mulop = (inst_mul_w)?2'b01:(inst_mulh_w)?2'b11:(inst_mulh_wu)?2'b10:2'b00;
assign divop = {{inst_div_w|inst_div_wu|inst_mod_w|inst_mod_wu},{inst_div_w|inst_div_wu},{inst_div_w|inst_mod_w}};
assign load_op[2] = inst_ld_w;
assign load_op[1] = inst_ld_h | inst_ld_hu;
assign load_op[0] = inst_ld_b | inst_ld_h | inst_ld_w; 
assign store_op[2]= inst_st_b | inst_st_h | inst_st_w;
assign store_op[1]= inst_st_w;
assign store_op[0]= inst_st_h;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h |inst_ld_bu | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h | inst_slti | inst_sltui;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12 ? {20'b0,i12[11:0]}          :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_st_w | inst_st_b | inst_st_h | inst_csrwr |inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_ld_w   |
                       inst_ld_b   | 
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu  |
                       inst_st_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_lu12i_w|
                       inst_pcaddu12i |
                       inst_jirl   |
                       inst_bl     ;
assign src1_is_zero =  inst_csrwr | inst_csrxchg;


assign res_from_mem  = inst_ld_w| inst_ld_b | inst_ld_h |inst_ld_bu | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_b & ~inst_st_h & ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_syscall;
assign mem_we        = inst_st_b | inst_st_h | inst_st_w;
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
assign rdata1 = (isEXEw&&(EXEreg[69:65] == rf_raddr1))?EXE_result:(rf_we&&(rf_waddr == rf_raddr1)&&(rf_raddr1!=5'b0))?rf_wdata:rf_rdata1;
assign rdata2 = (isEXEw&&(EXEreg[69:65] == rf_raddr2))?EXE_result:(rf_we&&(rf_waddr == rf_raddr2)&&(rf_raddr2!=5'b0))?rf_wdata:rf_rdata2;

assign rj_value  = rdata1;
assign rkd_value = rdata2;

assign rj_l_rd = ($signed(rdata1)<$signed(rdata2));
assign rj_lu_rd = (rdata1<rdata2);
assign rj_eq_rd = (rdata1 == rdata2);
assign br_taken =  (~br_go)?
                    1'b0    :
                    inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  && rj_l_rd
                   || inst_bltu && rj_lu_rd
                   || inst_bge  && !rj_l_rd
                   || inst_bgeu && !rj_lu_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b;
assign br_target = (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_bl || inst_b) ? (IDreg[63:32] + br_offs) :
                                                   /*inst_jirl*/ (rdata1 + jirl_offs);

assign alu_src1 = src1_is_pc  ? IDreg[63:32] : src1_is_zero? 32'b0 :rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign mul1 = (EXEreg[181:180]==2'b10)?{1'b0,EXEreg[115:84]}:{EXEreg[115],EXEreg[115:84]};
assign mul2 = (EXEreg[181:180]==2'b10)?{1'b0,EXEreg[147:116]}:{EXEreg[147],EXEreg[147:116]};
assign mul_result = $signed(mul1) * $signed(mul2);

alu u_alu(
    .alu_op     (EXEreg[83:72] ),
    .alu_src1   (EXEreg[115:84]  ),
    .alu_src2   (EXEreg[147:116] ),
    .alu_result (alu_result)
    );

assign EXE_result = (div_stop)?div_result:
                    (EXEreg[181:180]==2'b0)?alu_result:
                    (EXEreg[181]==1'b1)?mul_result[63:32]:mul_result[31:0];

assign st_data = (inst_st_b)?{4{rkd_value[7:0]}}:
                 (inst_st_h)?{2{rkd_value[15:0]}}:
                 rkd_value;

//assign data_sram_en    = mem_we;
assign data_sram_we    = (EXEreg[190])?
                         (EXEreg[189])?4'b1111:
                         (EXEreg[188])?((data_sram_addr[1]==1'b0)?4'b0011:4'b1100):
                         ((data_sram_addr[1:0]==2'b00)?4'b0001:(data_sram_addr[1:0]==2'b01)?4'b0010:(data_sram_addr[1:0]==2'b10)?4'b0100:4'b1000):
                         4'b0000;
assign data_sram_addr  = EXE_result;
assign data_sram_wdata = EXEreg[179:148];

assign mem_addr = MEMreg[72:71];
assign mem_b_off = (mem_addr==2'b01)?{data_sram_rdata>>8}:
                   (mem_addr==2'b10)?(data_sram_rdata>>16):
                   (mem_addr==2'b11)?(data_sram_rdata>>24):data_sram_rdata;
assign mem_h_off = (mem_addr[1]==1'b1)?data_sram_rdata>>16:data_sram_rdata;
assign mem_result   = MEMreg[105]? data_sram_rdata:
                      (MEMreg[104:103]==2'b11)?{{16{mem_h_off[15]}},mem_h_off[15:0]}:
                      (MEMreg[104:103]==2'b10)?{16'b0,mem_h_off[15:0]}:
                      (MEMreg[104:103]==2'b01)?{{24{mem_b_off[7]}},mem_b_off[7:0]}:
                      {24'b0,mem_b_off[7:0]};
assign final_result = MEMreg[154]?csr_rdata:MEMreg[70] ? mem_result : MEMreg[102:71];

//CSR
assign ready_back = EXEreg[240];
assign has_back = MEMreg[155];
assign ready_exception = EXEreg[241];
assign has_exception = WBreg[103];

assign csrw_en = inst_csrwr | inst_csrxchg;
assign csrr_en = 1'b1;
assign csrm_en = inst_csrxchg;
assign csr_inst = inst_csrrd | inst_csrwr | inst_csrxchg;
assign csr_num = id_inst[23:10];
assign csr_mask= rj_value;
assign csr_wdata = MEMreg[156]? MEMreg[63:32]: MEMreg[102:71];
assign ertn_flush= inst_ertn;
assign csr_wnum = has_exception ? 14'hc: (MEMreg[155]||MEMreg[156])?14'h6:MEMreg[119:106];
csrCXK csr_reg(
    .clk(clk),
    .reset(reset),
    .csr_re(csrr_en),
    .csr_num(csr_wnum),
    .csr_rvalue(csr_rdata),
    .csr_we(MEMreg[120]|MEMreg[156]),
    .csr_wmask((MEMreg[121])?MEMreg[153:122]:32'hffffffff),
    .csr_wvalue(csr_wdata),
    .ertn_flush(WBreg[102]),
    .wb_ex(has_exception)
);
always@(posedge clk)
begin
    if(reset)
        is_ret <= 1'b0;
    else if((inst_ertn || inst_syscall) && ~(EXEreg[184] && ~div_stop))
        is_ret <= 1'b1;
    else if(has_back||has_exception)
        is_ret <= 1'b0;
end


assign rf_we    = MEMreg[64];
assign rf_waddr = MEMreg[69:65];
assign rf_wdata = final_result;

// debug info generate
assign debug_wb_pc       = WBreg[63:32];
assign debug_wb_rf_we   = {4{WBreg[64]}};
assign debug_wb_rf_wnum  = WBreg[69:65];
assign debug_wb_rf_wdata = WBreg[101:70];

//mycode
always@(posedge clk)
begin
    if(reset)
        IDreg <= {pc,32'b0};
    else
    begin
        if(ready_back||ready_exception)
            IDreg <= 64'b0;
        else if(~id_readygo)
        begin
            IDreg<=IDreg;
        end
        else if(~br_taken && ~isadv)
        begin
            IDreg <= {pc,inst};
        end
        else
        begin
            IDreg<=IDreg;
        end
    end
end

always@(posedge clk)
begin
    if(reset)
    begin
        EXEreg[63:32]<= IDreg[63:32];
        EXEreg[115:0] <= 116'b0;
        EXEreg[241:148] <= 94'b0;
    end
    else
    begin
        if(ready_back||ready_exception)
            EXEreg <= 242'b0;
        else if(~ex_readygo)
        begin
            EXEreg<=EXEreg;
        end
        else if(~br_taken &&~isadv)
        begin
        EXEreg[63:0] <= IDreg[63:0];
        EXEreg[241:64] <= {inst_syscall,ertn_flush,csr_inst,csr_mask,csrm_en,csrw_en,csr_num,store_op,load_op,divop,mulop,st_data,alu_src2,alu_src1,alu_op,mem_we,res_from_mem,dest,gr_we};
        end
        else
        begin
        EXEreg[241:0] <= 242'b0;
        end
    end
end

always@(posedge clk)
begin
    if(reset)begin
        MEMreg[156:64] <= 93'b0;
        MEMreg[31:0] <= 32'b0;
        MEMreg[63:32] <= EXEreg[63:32];
        end
    else if(~mem_readygo)
    begin
        MEMreg[156:0] <= 157'b0;
    end
    else
    begin
        MEMreg[156:0] <= {EXEreg[241:191],EXEreg[187:185],EXE_result,EXEreg[70:0]};
    end
end
always@(posedge clk)
begin
    if(reset)begin
        WBreg[63:32] <= MEMreg[63:32];
        WBreg[103:64] <= 40'b0;
        WBreg[31:0] <= 32'b0;
        end
    else
    begin
        WBreg[103:0] <= {MEMreg[156:155],final_result,MEMreg[69:0]};
    end
end

assign data_sram_en =1'b1;
assign inst_sram_en =1'b1;

assign id_readygo = (EXEreg[184]&&~div_stop)?1'b0:(is_ret)?1'b0:1'b1;
assign ex_readygo = (EXEreg[184]&&~div_stop)?1'b0:(is_ret)?1'b0:1'b1;
assign mem_readygo= (EXEreg[184]&&~div_stop)?1'b0:1'b1;
assign wb_readygo = 1'b1;
//adv优先级较高
always@(posedge clk)
begin
    if(br_taken&~isadv)
        br_go <= 1'b0;
    else 
        br_go <= 1'b1;
end

//除法模块
assign dividend = EXEreg[115:84];
assign divisor  = EXEreg[147:116];
assign signed_dividend_tvalid = dividend_valid_reg;
assign signed_divisor_tvalid = divisor_valid_reg;
assign unsigned_dividend_tvalid = udividend_valid_reg;
assign unsigned_divisor_tvalid = udivisor_valid_reg;
assign div_stop = signed_out_tvalid||unsigned_out_tvalid;

assign signed_div_result = signed_result[63:32];
assign signed_mod_result = signed_result[31:0];
assign unsigned_div_result = unsigned_result[63:32];
assign unsigned_mod_result = unsigned_result[31:0];


assign div_result = (~EXEreg[184]) ? 32'b0 :
                    (EXEreg[183:182]==2'b11) ? signed_div_result :
                    (EXEreg[183:182]==2'b10) ? unsigned_div_result :
                    (EXEreg[183:182]==2'b01) ? signed_mod_result :
                    unsigned_mod_result;

mydiv signed_div(
    .aclk(clk),
    .s_axis_divisor_tdata(divisor),
    .s_axis_divisor_tready(signed_divisor_tready),
    .s_axis_divisor_tvalid(signed_divisor_tvalid),
    .s_axis_dividend_tdata(dividend),
    .s_axis_dividend_tready(signed_dividend_tready),
    .s_axis_dividend_tvalid(signed_dividend_tvalid),
    .m_axis_dout_tdata(signed_result),
    .m_axis_dout_tvalid(signed_out_tvalid)
);

mydivu unsigned_div(
    .aclk(clk),
    .s_axis_divisor_tdata(divisor),
    .s_axis_divisor_tready(unsigned_divisor_tready),
    .s_axis_divisor_tvalid(unsigned_divisor_tvalid),
    .s_axis_dividend_tdata(dividend),
    .s_axis_dividend_tready(unsigned_dividend_tready),
    .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
    .m_axis_dout_tdata(unsigned_result),
    .m_axis_dout_tvalid(unsigned_out_tvalid)
);

always@(posedge clk)
begin
    if(reset)
        dividend_valid_reg<=1'b0;
    else if(divop[2]&&divop[0])
        dividend_valid_reg<=1'b1;
    else if(signed_dividend_tvalid&&signed_dividend_tready)
        dividend_valid_reg<=1'b0;  
    else dividend_valid_reg<=dividend_valid_reg;
end
always@(posedge clk)
begin
    if(reset)
        divisor_valid_reg<=1'b0;
    else if(divop[2]&&divop[0])
        divisor_valid_reg<=1'b1;
    else if(signed_divisor_tvalid&&signed_divisor_tready)
        divisor_valid_reg<=1'b0;  
    else divisor_valid_reg<=divisor_valid_reg;
end
always@(posedge clk)
begin
    if(reset)
        udividend_valid_reg<=1'b0;
    else if(divop[2]&&~divop[0])
        udividend_valid_reg<=1'b1;
    else if(unsigned_dividend_tvalid&&unsigned_dividend_tready)
        udividend_valid_reg<=1'b0;  
    else udividend_valid_reg<=udividend_valid_reg;
end
always@(posedge clk)
begin
    if(reset)
        udivisor_valid_reg<=1'b0;
    else if(divop[2]&&~divop[0])
        udivisor_valid_reg<=1'b1;
    else if(unsigned_divisor_tvalid&unsigned_divisor_tready)
        udivisor_valid_reg<=1'b0;  
    else udivisor_valid_reg<=udivisor_valid_reg;
end
endmodule
