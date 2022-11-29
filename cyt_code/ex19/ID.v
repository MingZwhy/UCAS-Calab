`include "width.vh"

module stage2_ID(
    input clk,
    input reset,
    input ertn_flush,
    input has_int,
    input wb_ex,

    input es_allow_in,
    output ds_allow_in,

    input fs_to_ds_valid,
    output ds_to_es_valid, 

    input [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,
    output [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,

    //ws_to_ds_bus  for write reg_file
    input [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus,
    //br_bus including br_taken and br_target
    //deliver back to FETCH module
    output [`WIDTH_BR_BUS-1:0] br_bus,

    input [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus,
    input [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ds_bus,

    input data_sram_data_ok,

    //tlb new add
    output tlb_zombie,
    input tlb_reflush
);

/*-------------------------for decode--------------------------*/
wire [31:0] inst;

wire        br_taken;
wire [31:0] br_target;

wire [14:0] alu_op;
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

//task10 add inst
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_div_wu;
wire        inst_mod_w;
wire        inst_mod_wu;

//task11 add inst
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;

//task12 add inst
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;

//task13 add inst
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;
wire        inst_break;

//tlb inst
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
wire [4:0]  inst_invtlb_op;

//task13 add INE(???????)
wire ds_ex_INE;
//hint ds_pc == 0 means the ds cache is cleared, so at this time inst is empty, is not an INE exception actually
assign ds_ex_INE   =     (~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and |
                         inst_or | inst_xor | inst_slli_w | inst_srli_w | inst_srai_w |
                         inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_b |
                         inst_bl | inst_beq | inst_bne | inst_lu12i_w | inst_slti |
                         inst_sltui | inst_andi | inst_ori | inst_xori | inst_sll_w |
                         inst_srl_w | inst_sra_w | inst_pcaddu12i | inst_mul_w | inst_mulh_w |
                         inst_mulh_wu | inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu |
                         inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b |
                         inst_st_h | inst_blt | inst_bge | inst_bltu | inst_bgeu |
                         inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | inst_syscall |
                         inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid | inst_break |
                         inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb) || (inst_invtlb && 
                         ~(inst_invtlb_op == 5'h6 || inst_invtlb_op == 5'h5 || inst_invtlb_op == 5'h4 || inst_invtlb_op[4:2] == 3'h0))) 
                         && (ds_pc != 32'b0) && (~ds_ex_ADEF);

wire        need_ui5;
wire        need_SignExtend_si12;
wire        need_ZeroExtend_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

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
assign i26  = {inst[ 9: 0], inst[25:10]};   //checked 

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

//add_w: rd = rj + rk   asm: add.w rd, rj, rk
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
//sun_w: rd = rj - rk   asm: sub.w rd, rj, rk
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
//slt: rd = (signed(rj) < signed(rk)) ? 1 : 0  
//asm: slt rd, rj, rk
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
//sltu: rd = (unsigned(rj) < unsigned(rk)) ? 1 : 0  
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
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
//srli.w: rd = SRL(rj, ui5)  asm: srli.w rd, rj, ui5
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
//srai.w: rd = SRA(rj, ui5)  asm: srai.w rd, rj, ui5
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
//if (rj!=rd)
//  pc = pc + SignExtend({offs16, 2'b0}, GRLEN)
assign inst_bne    = op_31_26_d[6'h17];
//lui2i_w: rd, si20
//rd = {si20, 12'b0}
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

//task10 add inst

/*slti: rd, rj, si12
* tmp = SignExtend(si12, GRLEN)
* rd = (signed(rj) < signed(tmp)) ? 1 : 0  
*/
assign inst_slti = op_31_26_d[6'h0] & op_25_22_d[4'h8];

/*sltui: rd, rj, si12
* tmp = SignExtend(si12, GRLEN)
* rd = (unsigned(rj) < unsigned(tmp)) ? 1 : 0  
*/
assign inst_sltui = op_31_26_d[6'h0] & op_25_22_d[4'h9];

/*andi: andi rd, rj, ui12
* rd = rj & ZeroExtend(ui12)
*/
assign inst_andi = op_31_26_d[6'h0] & op_25_22_d[4'hd];

/*ori: ori rd, rj, ui12
* rd = rj | ZeroExtend(ui12)
*/
assign inst_ori = op_31_26_d[6'h0] & op_25_22_d[4'he];

/*xori: xori rd, rj, ui12
* rd = rj ^ ZeroExtend(ui12)
*/
assign inst_xori = op_31_26_d[6'h0] & op_25_22_d[4'hf];

/*sll.w: sll.w rd, rj, rk
* tmp = SLL(rj, rk[4:0])
* rd = tmp
*/
assign inst_sll_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];

/*srl.w: srl.w rd, rj, rk
* tmp = SRL(rj, rk[4:0])
* rd = tmp
*/
assign inst_srl_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];

/*sra.w: sra.w rd, rj, rk
* tmp = SRA(rj, rk[4:0])
* rd = tmp
*/
assign inst_sra_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

/*pcaddu12i rd, si20
* rd = pc + SignExtend({si20, 12'b0})
*/
assign inst_pcaddu12i = op_31_26_d[6'h7] & ~inst[25];

/*mul.w mul.w rd, rj, rk
* product = signed(rj) * signed(rk)
* rd = product[31:0]
*/
assign inst_mul_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];

/*mulh.w mulh.w rd, rj, rk
* product = signed(rj) * signed(rk)
* rd = product[63:32]
*/
assign inst_mulh_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];

/*mulh.wu mulh.wu rd, rj, rk
* product = unsigned(rj) * unsigned(rk)
* rd = product[63:32]
*/
assign inst_mulh_wu = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];

/*div.w div.w: rd, rj, rk
* quotient = signed(rj) / signed(rk)
* rd = quotient[31:0]
*/
assign inst_div_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h0];

/*mod.w mod.w: rd, rj, rk
* remainder = signed(rj) / signed(rk)
* rd = remainder[31:0]
*/
assign inst_mod_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h1];

/*div.wu div.wu: rd, rj, rk
* quotient = unsigned(rj) / unsigned(rk)
* rd = quotient[31:0]
*/
assign inst_div_wu = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h2];

/*mod.wu mod.wu: rd, rj, rk
* remainder = unsigned(rj) / unsigned(rk)
* rd = remainder[31:0]
*/
assign inst_mod_wu = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h3];

//task11 add inst

/*ld_b ld_b: rd, rj, si12
* paddr = vaddr = rj + SignExtend(si12)
* byte = MemoryLoad(paddr, BYTE)
* rd = SignExtend(byte)
*/
assign inst_ld_b = op_31_26_d[6'h0a] & op_25_22_d[4'h0];

/*ld_h ld_h: rd, rj, si12
* paddr = vaddr = rj + SignExtend(si12)
* haldword = MemoryLoad(paddr, halfword)
* rd = SignExtend(halfword)
*/
assign inst_ld_h = op_31_26_d[6'h0a] & op_25_22_d[4'h1];

/*ld_bu ld_bu: rd, rj, si12
* paddr = vaddr = rj + SignExtend(si12)
* byte = MemoryLoad(paddr, byte)
* rd = ZeroExtend(halfword)
*/
assign inst_ld_bu = op_31_26_d[6'h0a] & op_25_22_d[4'h8];

/*ld_hu ld_hu: rd, rj, si12
* paddr = vaddr = rj + SignExtend(si12)
* haldword = MemoryLoad(paddr, halfword)
* rd = ZeroExtend(halfword)
*/
assign inst_ld_hu = op_31_26_d[6'h0a] & op_25_22_d[4'h9];

/*st_b st_b: rd, rj, si12
* paddr = vaddr = rj + SignExtend(si12)
* MemoryStore(rd[7:0], paddr, byte)
*/
assign inst_st_b = op_31_26_d[6'h0a] & op_25_22_d[4'h4];

/*st_h st_h: rd, rj, si12
* paddr = vaddr = rj + SignExtend(si12)
* MemoryStore(rd[15:0], paddr, halfword)
*/
assign inst_st_h = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

/*blt blt: rj, rd, offs16
* if(signed(rj) < signed(rd))
*       pc = pc + SignExtend(offs16,2'b0)
*/
assign inst_blt = op_31_26_d[6'h18];

/*bge bge: rj, rd, offs16
* if(signed(rj) >= signed(rd))
*       pc = pc + SignExtend(offs16,2'b0)
*/
assign inst_bge = op_31_26_d[6'h19];

/*bltu bltu: rj, rd, offs16
* if(unsigned(rj) < unsigned(rd))
*       pc = pc + SignExtend(offs16,2'b0)
*/
assign inst_bltu = op_31_26_d[6'h1a];

/*bgeu bgeu: rj, rd, offs16
* if(unsigned(rj) < unsigned(rd))
*       pc = pc + SignExtend(offs16,2'b0)
*/
assign inst_bgeu = op_31_26_d[6'h1b];

//task12 add

/*csrrd csrrd: rd, csr_num
* rd <-- CSR[csr_num]
*/
assign inst_csrrd = op_31_26_d[6'h1] & ~inst[25] & ~inst[24] & (rj==0);

/*csrwr csrwr: rd, csr_num
* rd(old) --> CSR[csr_num]
* rd(new) <-- CSR[csr_num](old)
*/
assign inst_csrwr = op_31_26_d[6'h1] & ~inst[25] & ~inst[24] & (rj==1);

/*csrxchg csrxchg: rd, rj, csr_num
* rd(old) --> CSR[csr_num] according to wmask in rj
* rd(new) <-- CSR[csr_num](old)
*/
assign inst_csrxchg = op_31_26_d[6'h1] & ~inst[25] & ~inst[24] & (rj!=0 & rj!=1);

/*ertn ertn: 
* CSR_PRMD[PPLV,PIE] --> CSR_CRMD[PLV,IE]
* pc <-- CSR_ERA
*/
assign inst_ertn = op_31_26_d[6'h1] & op_25_22_d[4'h9] 
                 & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'b01110);

/*syscall syscall: code
* run syscall immediately according to code
*/
assign inst_syscall = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];

//task13 add

/*rdcntvl.w:  rdcnttvl.w rd
* rd <-- global_time_cnt[31:0]
*/
assign inst_rdcntvl_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] &
                        (rk == 5'b11000) & (rj == 5'b00000);

/*rdcntvh.w: rdcnttvh.w rd
* rd <-- global_time_cnt[63:32]
*/
assign inst_rdcntvh_w = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] &
                        (rk == 5'b11001) & (rj == 5'b00000);

/*rdcntid rdcntid rj
* rj <-- CSR_TID
*/
assign inst_rdcntid = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] &
                    (rk == 5'b11000) & (rd == 5'b00000);

/*break: break code
* break exception
*/
assign inst_break = op_31_26_d[6'h0] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];

//tlb add inst

assign inst_tlbsrch = op_31_26_d[6'h1] & op_25_22_d[4'h9] &
                      op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'b01010);

assign inst_tlbrd =   op_31_26_d[6'h1] & op_25_22_d[4'h9] &
                      op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'b01011);

assign inst_tlbwr =   op_31_26_d[6'h1] & op_25_22_d[4'h9] &
                      op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'b01100);

assign inst_tlbfill = op_31_26_d[6'h1] & op_25_22_d[4'h9] &
                      op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk==5'b01101);

assign inst_invtlb =  op_31_26_d[6'h1] & op_25_22_d[4'h9] &
                      op_21_20_d[2'h0] & op_19_15_d[5'h13];

assign inst_invtlb_op = inst[4:0];
//task13 add ds_ex_break
wire ds_ex_break;
assign ds_ex_break = inst_break;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;  
assign need_SignExtend_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui
                                            | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h;
assign need_ZeroExtend_si12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;  
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;          
assign need_si26  =  inst_b | inst_bl;      

assign src2_is_4  =  inst_jirl | inst_bl;   

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :   
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;   

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};   

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_st_w | inst_st_b | inst_st_h
                                | inst_csrrd | inst_csrwr | inst_csrxchg;

//used for judging br_taken
assign rj_eq_rd = (rj_value == rkd_value);

//imitation calcu slt and sltu in alu
wire signed_rj_less_rkd;
wire unsigned_rj_less_rkd;

wire cin;
assign cin = 1'b1;
wire [31:0] adver_rkd_value;
assign adver_rkd_value = ~rkd_value;
wire [31:0] rj_rkd_adder_result;
wire cout;
assign {cout, rj_rkd_adder_result} = rj_value + adver_rkd_value + cin;

assign signed_rj_less_rkd = (rj_value[31] & ~rkd_value[31])
                               | ((rj_value[31] ~^ rkd_value[31]) & rj_rkd_adder_result[31]);
assign unsigned_rj_less_rkd = ~cout;                      


/*----------------------------------------------------------------*/

/*-----------------------receive fs_to_ds_bus----------------*/
wire [31:0] ds_pc;
wire ds_ex_ADEF;
wire ds_tlb_zombie;
wire ds_ex_fetch_tlb_refill;
wire ds_ex_inst_invalid;
wire ds_ex_fetch_plv_invalid;

reg [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            fs_to_ds_bus_reg <= 0;
        else if(ertn_flush || wb_ex || tlb_reflush)
            fs_to_ds_bus_reg <= 0;
        else if(fs_to_ds_valid && ds_allow_in)         
            fs_to_ds_bus_reg <= fs_to_ds_bus;
    end
assign {ds_ex_fetch_plv_invalid, ds_ex_inst_invalid, ds_ex_fetch_tlb_refill,
        ds_tlb_zombie, ds_ex_ADEF, inst, ds_pc} = fs_to_ds_bus_reg;         //_reg;
/*-------------------------------------------------------*/

/*-----------------------receive es,ms,ws_to_ds_bus----------------*/
/*
assign ws_to_ds_bus[31:0] = ws_wdata;
assign ws_to_ds_bus[36:32] = ws_waddr;
assign ws_to_ds_bus[37:37] = ws_we;
assign ws_to_ds_bus[38:38] = ws_csr_write;
assign ws_to_ds_bus[39:39] = ws_ertn_flush;
assign ws_to_ds_bus[53:40] = ws_csr_num;
*/

wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;

//task12 add
wire ws_csr_write;
wire ws_ertn_flush;
wire [13:0] ws_csr_num;
wire ws_csr;
assign {ws_csr, ws_csr_num, ws_ertn_flush, ws_csr_write, rf_we, rf_waddr,rf_wdata} = ws_to_ds_bus;

wire es_valid;
wire es_we;
wire [4:0] es_dest;
wire if_es_load;
wire [31:0] es_wdata;
wire es_csr_write;
wire [13:0] es_csr_num;
wire es_csr;

wire ms_to_ws_valid;
wire ms_valid;
wire ms_we;
wire [4:0] ms_dest;
wire if_ms_load;
wire [31:0] ms_wdata;
wire ms_csr_write;
wire [13:0] ms_csr_num;
wire ms_csr;

assign {es_valid, es_we, es_dest, if_es_load, es_wdata, es_csr_write, es_csr_num, es_csr} = es_to_ds_bus;
assign {ms_to_ws_valid, ms_valid, ms_we, ms_dest, if_ms_load, ms_wdata, ms_csr_write, ms_csr_num, ms_csr} = ms_to_ds_bus;
/*-------------------------------------------------------*/

/*-----------------------deliver br_bus----------------------*/
assign br_taken = ((inst_beq && rj_eq_rd) || (inst_bne && !rj_eq_rd) 
                   || (inst_blt && signed_rj_less_rkd) || (inst_bltu && unsigned_rj_less_rkd)
                   || (inst_bge && ~signed_rj_less_rkd) || (inst_bgeu && ~unsigned_rj_less_rkd)
                   || inst_jirl || inst_bl || inst_b) && ds_valid;

wire br_taken_cancel;
wire br_stall;
//??????????????????????load?????????????????????br_stall???????????
assign br_stall = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt
                || inst_bge || inst_bgeu || inst_bltu) && 
                ((es_valid && if_es_load && (ex_crush1 || ex_crush2)) || (~ms_to_ws_valid && ms_valid && if_ms_load && (mem_crush1 || mem_crush2)) || csr_crush);

assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt 
                             || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :   
                                                   /*inst_jirl*/ (rj_value + jirl_offs); 
assign br_bus = {br_taken_cancel, br_stall, br_taken, br_target};           
/*-------------------------------------------------------*/

/*-----------------------deliver ds_to_es_bus----------------*/
assign rj_value  = forward_rdata1;   
assign rkd_value = forward_rdata2;

wire [31:0] SignExtend_imm12;
assign SignExtend_imm12 = {{20{i12[11]}}, i12[11:0]};
wire [31:0] ZeroExtend_imm12;
assign ZeroExtend_imm12 = {20'b0, i12[11:0]};

assign imm = src2_is_4 ? 32'h4                       :   
             need_si20 ? {i20[19:0], 12'b0}          :   
             need_ui5  ? {27'b0,rk[4:0]}             :   
             need_SignExtend_si12 ? SignExtend_imm12 :
             need_ZeroExtend_si12 ? ZeroExtend_imm12 :   
             32'b0 ;
assign dst_is_r1     = inst_bl;
//task13 --> inst_rdcntid is specail --> write into reg rj
assign dest = inst_rdcntid ? rj : dst_is_r1 ? 5'd1 : rd;

assign gr_we         = ~inst_st_w & ~inst_st_b & ~inst_st_h &~inst_beq & ~inst_bne & ~inst_b & 
                       ~inst_blt & ~inst_bltu & ~inst_bge & ~inst_bgeu & ~inst_ertn & ~inst_break & ~ds_ex_INE & ~ds_ex_ADEF &
                       ~ds_ex_syscall & ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb &
                       ~ds_ex_fetch_plv_invalid & ~ds_ex_fetch_tlb_refill & ~ds_ex_inst_invalid;    //task12 add csr will write reg_file 
//debug record: when ds_ex_INE happen, means no inst, can't write reg_file, when ds_ex_ADEF, means error intn, can't write reg_file

assign mem_we        = inst_st_w | inst_st_b | inst_st_h;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl | inst_pcaddu12i 
                    | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu
                    | inst_st_b | inst_st_h;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |    //checked
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i |
                       inst_ld_b   |
                       inst_ld_bu  |
                       inst_ld_h   |
                       inst_ld_hu  |
                       inst_st_b   |
                       inst_st_h   ;

assign res_from_mem  = inst_ld_w || inst_ld_b || inst_ld_bu || inst_ld_h || inst_ld_hu;

wire need_wait_div;        //if ex need waiting result of div
assign need_wait_div = inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;
wire [1:0] div_op;
/* div_op = 
* 2'b00: div_w
* 2'b01: div_wu
* 2'b10: mod_w
* 2'b11: mod_wu
*/ 
assign div_op = inst_div_w ? 2'b00 : inst_div_wu ? 2'b01 : inst_mod_w ? 2'b10 : 2'b11; 

wire [4:0] ld_op;
/* ld_op = (one hot)
* 5'b00001 ld_w
* 5'b00010 ld_b
* 5'b00100 ld_bu
* 5'b01000 ld_h
* 5'b10000 ld_hu
*/
assign ld_op[0] = inst_ld_w;
assign ld_op[1] = inst_ld_b;
assign ld_op[2] = inst_ld_bu;
assign ld_op[3] = inst_ld_h;
assign ld_op[4] = inst_ld_hu;

wire [2:0] st_op;
/* st_op = (one hot)
* 3'b001 st_w
* 3'b010 st_b
* 5'b100 st_h
*/
assign st_op[0] = inst_st_w;
assign st_op[1] = inst_st_b;
assign st_op[2] = inst_st_h;

assign ds_to_es_bus[31:   0] = ds_pc;        
assign ds_to_es_bus[63:  32] = rj_value;  
assign ds_to_es_bus[95:  64] = rkd_value; 
assign ds_to_es_bus[127: 96] = imm;       
assign ds_to_es_bus[132:128] = dest;      
assign ds_to_es_bus[133:133] = gr_we && ~ds_tlb_zombie;     
assign ds_to_es_bus[134:134] = mem_we && ~ds_tlb_zombie;    
assign ds_to_es_bus[149:135] = alu_op;    
assign ds_to_es_bus[150:150] = src1_is_pc;   
assign ds_to_es_bus[151:151] = src2_is_imm;  
assign ds_to_es_bus[152:152] = res_from_mem && ~ds_tlb_zombie; 
assign ds_to_es_bus[153:153] = need_wait_div;
assign ds_to_es_bus[155:154] = div_op;
assign ds_to_es_bus[160:156] = ld_op;
assign ds_to_es_bus[163:161] = st_op;

//task12
assign ds_to_es_bus[177:164] = ds_csr_num;
assign ds_to_es_bus[209:178] = ds_csr_wmask;
assign ds_to_es_bus[210:210] = ds_csr_write && ~ds_tlb_zombie;
assign ds_to_es_bus[211:211] = ds_ertn_flush;
assign ds_to_es_bus[212:212] = ds_csr;
assign ds_to_es_bus[213:213] = ds_ex_syscall;
assign ds_to_es_bus[228:214] = ds_code;

//task13
wire ds_has_int;
assign ds_has_int = has_int;

assign ds_to_es_bus[229:229] = inst_rdcntvl_w || inst_rdcntvh_w; 
assign ds_to_es_bus[230:230] = inst_rdcntvh_w;
assign ds_to_es_bus[231:231] = ds_ex_INE;
assign ds_to_es_bus[232:232] = ds_ex_ADEF;
assign ds_to_es_bus[233:233] = ds_ex_break;
assign ds_to_es_bus[234:234] = ds_has_int;

//task tlb add
assign ds_to_es_bus[235:235] = inst_tlbsrch;
assign ds_to_es_bus[236:236] = inst_tlbrd;
assign ds_to_es_bus[237:237] = inst_tlbwr;
assign ds_to_es_bus[238:238] = inst_tlbfill;
assign ds_to_es_bus[239:239] = inst_invtlb;
assign ds_to_es_bus[244:240] = inst_invtlb_op;
assign ds_to_es_bus[245:245] = ds_tlb_zombie;

//tlb exception
assign ds_to_es_bus[246:246] = ds_ex_fetch_tlb_refill;
assign ds_to_es_bus[247:247] = ds_ex_inst_invalid;
assign ds_to_es_bus[248:248] = ds_ex_fetch_plv_invalid;
/*-------------------------------------------------------*/

/*--------------------------------valid---------------------------*/
reg ds_valid;    
wire if_read_addr1;   
wire if_read_addr2;   

assign if_read_addr1 = ~inst_b && ~inst_bl && ~inst_csrrd && ~inst_csrwr && ~inst_syscall && ~inst_ertn &&
                        ~inst_rdcntid && ~inst_rdcntvl_w && ~inst_rdcntvh_w && ~inst_break;
assign if_read_addr2 = inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || 
                       inst_xor || inst_or || inst_and || inst_nor ||
                       inst_sltu || inst_slt || inst_sub_w || inst_add_w || inst_st_w || inst_st_b || inst_st_h ||
                       inst_sll_w || inst_srl_w || inst_sra_w || inst_mul_w || inst_mulh_w || inst_mulh_wu ||
                       inst_div_w || inst_div_wu || inst_mod_w || inst_mod_wu ||
                       inst_csrrd || inst_csrwr || inst_csrxchg;     //task12 add 

wire Need_Block;    

//when ertn_flush or wb_ex or has_int , we can't block ,becaue it will make ds_allow_in down, so that fs_allow_in down, finally fetch error
/*
condition && ~ertn_flush && ~wb_ex && ~has_int in this place is to solve a very rare and coincide situation:
when an ertn_flush or wb_ex and has_int happens (signal raised)
and at the same time, inst in decode_stage trigger a read_write conflict in csr_inst and neel_block
actually this decode_stage inst and csr_inst should not be executed (we will solve this by clearing the cache in line)
but if we allow this decode_stage inst to trigger a block, ds_ready_go will be down because of it
as a result, ds_allow_in will be down therefore, and this will cause fs_allow_in also be down which is dangerous
when fs_allow_in down, we block (fetch_pc <= next_pc), and this next_pc is essential to getting into exception
or return from exception, this out_of_exception block will make next_pc (key) lost
so we must avoid this situation happen!
*/
//assign Need_Block = (((ex_crush1 || ex_crush2) && IF_LOAD) || csr_crush) && ~ertn_flush && ~wb_ex && ~has_int;
//assign Need_Block = csr_crush && ~ertn_flush && ~wb_ex && ~has_int;
assign Need_Block = ( (if_es_load && (ex_crush1 || ex_crush2)) || (~ms_to_ws_valid && if_ms_load && (mem_crush1 || mem_crush2)) || csr_crush )
                    && ~ertn_flush && ~wb_ex && ~has_int;

wire ex_crush1;
wire ex_crush2;
assign ex_crush1 = es_valid && (es_we && es_dest!=0) && (if_read_addr1 && rf_raddr1==es_dest);
assign ex_crush2 = es_valid && (es_we && es_dest!=0) && (if_read_addr2 && rf_raddr2==es_dest);

wire mem_crush1;
wire mem_crush2;
assign mem_crush1 = ms_valid && (ms_we && ms_dest!=0) && (if_read_addr1 && rf_raddr1==ms_dest);
assign mem_crush2 = ms_valid && (ms_we && ms_dest!=0) && (if_read_addr2 && rf_raddr2==ms_dest);

wire wb_crush1;
wire wb_crush2;
assign wb_crush1 = (rf_we && rf_waddr!=0) && (if_read_addr1 && rf_raddr1==rf_waddr);
assign wb_crush2 = (rf_we && rf_waddr!=0) && (if_read_addr2 && rf_raddr2==rf_waddr);

//task12 add csr_crush
/*
csr_crush happen when an instruction read reg
which csr_inst will write in next clks
this condition is specail because csr_int read csr_reg and 
write into reg_file in wb_stage, so if we want to use forward deliver
to solve read_write inflict, we must use more resources,
but csr_inst is rare which means read_write conflict in csr_inst is rarer
so forward deliver is a waste (not worthy)
so in this place , we just block when read_write_conflict in csr_inst happen
*/

/*
if ws_csr && (wb_crush1 || wb_crush2), we needn't block
because we can use existed data_path used for solving past read_write conflict directly
to achieve forward deliver
*/

wire csr_crush;

assign csr_crush = ds_valid && ( (es_valid && es_csr && (ex_crush1 || ex_crush2)) || (ms_valid && ms_csr && (mem_crush1 || mem_crush2)) );  //|| (ws_csr && (wb_crush1 || wb_crush2));

//forward deliver
wire [31:0] forward_rdata1;
wire [31:0] forward_rdata2;
assign forward_rdata1 = ex_crush1? es_wdata : mem_crush1? ms_wdata : wb_crush1? rf_wdata : rf_rdata1;
assign forward_rdata2 = ex_crush2? es_wdata : mem_crush2? ms_wdata : wb_crush2? rf_wdata : rf_rdata2;

wire ds_ready_go;
assign ds_ready_go = ~Need_Block;         
assign ds_allow_in = !ds_valid || ds_ready_go && es_allow_in;
assign ds_to_es_valid = ds_valid && ds_ready_go;


assign br_taken_cancel =  Need_Block ? 1'b0 : br_taken;

always @(posedge clk)
    begin
        if(reset)
            ds_valid <= 1'b0;
        else if(br_taken_cancel)
            ds_valid <= 1'b0;
        else if(ds_allow_in)
            ds_valid <= fs_to_ds_valid;
    end
/*----------------------------------------------------------------*/

/*------------------------------CSR inst--------------------------*/

//inst[23:10] -- csr_num
wire [13:0] ds_csr_num;
//when inst_rdcntid --> read CSR_TID
assign ds_csr_num = inst_rdcntid ? `CSR_TID : inst[23:10];

wire ds_ex_syscall;
assign ds_ex_syscall = inst_syscall;

wire [14:0] ds_code;
assign ds_code = inst[14:0];

wire ds_csr;
assign ds_csr = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;

wire ds_csr_write;
assign ds_csr_write = inst_csrwr | inst_csrxchg;

wire [31:0] ds_csr_wmask;
assign ds_csr_wmask = inst_csrxchg ? rj_value : 32'hffffffff;       //mask <-- rj

wire ds_ertn_flush;
assign ds_ertn_flush = inst_ertn;


/*----------------------------------------------------------------*/


/*-------------------------link reg_file---------------------------*/
assign rf_raddr1 = rj;  
assign rf_raddr2 = src_reg_is_rd ? rd : rk; 
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
/*----------------------------------------------------------------*/

/*--------------------------tlb_zombie-----------------------------*/

wire tlb_self_zombie;   //�����Ǳ���Ⱦ�ߣ����������Ⱦ��һ��ָ��?
assign tlb_self_zombie = ds_tlb_zombie;

wire tlb_inst_zombie;   //tlbָ��µĸ�ȾԴ
assign tlb_inst_zombie = inst_tlbwr | inst_tlbfill | inst_invtlb | inst_tlbrd;

wire csr_inst_zombie;   //csrָ��µĸ�ȾԴ
assign csr_inst_zombie = (inst_csrwr | inst_csrxchg) && (ds_csr_num == `CSR_CRMD || 
                        ds_csr_num == `CSR_DMW0 || ds_csr_num == `CSR_DMW1 || ds_csr_num == `CSR_ASID);

assign tlb_zombie = tlb_self_zombie | tlb_inst_zombie | csr_inst_zombie;

/*----------------------------------------------------------------*/

endmodule