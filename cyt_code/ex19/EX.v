`include "width.vh"

module stage3_EX(
    input clk,
    input reset,
    input ertn_flush,
    input wb_ex,

    input ms_allow_in,
    output es_allow_in,

    input ds_to_es_valid,
    output es_to_ms_valid,

    input [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,
    output [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus,
    input                           if_ms_ex,

    output              data_sram_req,
    output              data_sram_wr,
    output [1:0]        data_sram_size,
    output [3:0]        data_sram_wstrb,
    output [31:0]       data_sram_addr,
    output [31:0]       data_sram_wdata,

    input               data_sram_addr_ok,
    input               data_sram_data_ok,

    input [63:0] global_time_cnt,

    //port with tlb.v
    output [18:0] s1_vppn,
    output        s1_va_bit12,
    output [9:0]  s1_asid,

    input         s1_found,
    input [3:0]   s1_index,

    //tlb add
    input [18:0] tlbehi_vppn,
    input [9:0]  tlbasid_asid,

    //tlb crush
    input        if_ms_crush_with_tlbsrch,
    input        if_ws_crush_with_tlbsrch,
    input        tlb_reflush,

    //for translate
    input crmd_da,      //当前翻译模式
    input crmd_pg,

    input [1:0] plv,    //当前特权等级, 0-3, 0为最高
    input [1:0] datm,   //直接地址翻译模式下，load/store操作的存储访问类型

    input DMW0_PLV0,        //为1表示在PLV0下可以使用该窗口进行直接映射地址翻译
    input DMW0_PLV3,        //为1表示在PLV3下可以使用该窗口进行直接映射地址翻译
    input [1:0] DMW0_MAT,   //虚地址落在该映射窗口下访存操作的存储类型访问
    input [2:0] DMW0_PSEG,  //直接映射窗口物理地址高3位
    input [2:0] DMW0_VSEG,  //直接映射窗口虚地址高3位

    input DMW1_PLV0,        
    input DMW1_PLV3,       
    input [1:0] DMW1_MAT,  
    input [2:0] DMW1_PSEG,  
    input [2:0] DMW1_VSEG,

    //input s1_found,
    input [19:0] s1_ppn,
    input [1:0] s1_plv,
    input s1_d,
    input s1_v,

    output invtlb_valid,
    output [4:0] invtlb_op
);

/*------------------------------------------------------------*/
assign s1_vppn = (es_inst_tlbsrch) ? tlbehi_vppn:
                (es_inst_invtlb)?
                 es_rkd_value[31:13] : es_alu_result[31:13];

assign s1_va_bit12 = es_alu_result[12];

assign s1_asid = (es_inst_tlbsrch) ? tlbasid_asid : 
                 (es_inst_invtlb)?
                 es_rj_value[9:0] : tlbasid_asid;
assign invtlb_valid = es_inst_invtlb;
assign invtlb_op    = es_inst_invtlb_op;

/*------------------------------------------------------------*/

/*-----------------------recerive ds_to_es_bus----------------*/

wire [31:0] es_pc;
wire [31:0] es_rj_value;
wire [31:0] es_rkd_value;
wire [31:0] es_imm;
wire [4:0]  es_dest;
wire        es_gr_we;
wire        es_mem_we;
wire [14:0] es_alu_op;
wire        es_src1_is_pc;
wire        es_src2_is_imm;
wire        es_res_from_mem;
wire        es_need_wait_div;
wire [1:0]  es_div_op;
wire [4:0]  es_ld_op;
wire [2:0]  es_st_op;

//task12
wire [13:0] es_csr_num;
wire [31:0] es_csr_wmask;
wire        es_csr_write;
wire        es_ertn_flush;
wire        es_csr;
wire        es_ex_syscall;
wire [14:0] es_code;
wire        es_if_rdcnt;
wire        es_rdcnt_high_or_low;   //1'b1 --> high ; 1'b0 --> low
wire        es_ex_INE;
wire        es_ex_ADEF;
wire        es_ex_break;
wire        es_has_int;

//task tlb add
wire        es_inst_tlbsrch;
wire        es_inst_tlbrd;
wire        es_inst_tlbwr;
wire        es_inst_tlbfill;
wire        es_inst_invtlb;
wire [4:0]  es_inst_invtlb_op;  
wire        es_tlb_zombie;

//tlb exception
wire        es_ex_fetch_tlb_refill;
wire        es_ex_inst_invalid;
wire        es_ex_fetch_plv_invalid;

reg [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ds_to_es_bus_reg <= 0;
        else if(ertn_flush || wb_ex || tlb_reflush)
            ds_to_es_bus_reg <= 0;
        else if(ds_to_es_valid && es_allow_in)
            ds_to_es_bus_reg <= ds_to_es_bus;
        else if(es_need_wait_div)        
            ds_to_es_bus_reg <= ds_to_es_bus_reg;
    end


/*init
* when ds_to_es_bus_reg <= ds_to_es_bus ; init <= 1
* when es_need_wait_div and ds_to_es_bus_reg keep still, init <= 0

* init = 1 and es_need_wait_div --> raise (un)signed_dividend(divisor)_tvalid
* so that we can make sure tvalid = 1 and EX at the same time

* other time (un)signed_dividend(divisor)_tvalid = (un)signed_dividend(divisor)_tvalid_reg

* in (un)signed_dividend(divisor)_tvalid_reg
* when es_need_wait_div && es_div_op && init, (un)signed_dividend(divisor)_tvalid_reg <= 1
* "init" make sure we will not raise valid after shaking hand
* when ready (shake hand successfully), (un)signed_dividend(divisor)_tvalid_reg <= 0
*/
reg init;
always @(posedge clk)
    begin
        if(reset)
            init <= 0;
        else if(ds_to_es_valid && es_allow_in)
            init <= 1;
        else
            init <= 0;
    end

assign {es_ex_fetch_plv_invalid, es_ex_inst_invalid, es_ex_fetch_tlb_refill, es_tlb_zombie,
        es_inst_invtlb_op, es_inst_invtlb, es_inst_tlbfill, es_inst_tlbwr, es_inst_tlbrd, es_inst_tlbsrch,
        es_has_int, es_ex_break, es_ex_ADEF, es_ex_INE, es_rdcnt_high_or_low, es_if_rdcnt,
        es_code, es_ex_syscall, es_csr, es_ertn_flush, es_csr_write, es_csr_wmask, es_csr_num,
        es_st_op, es_ld_op, es_div_op, es_need_wait_div, es_res_from_mem, es_src2_is_imm,
        es_src1_is_pc, es_alu_op, es_mem_we, es_gr_we, es_dest, es_imm,
        es_rkd_value, es_rj_value, es_pc} = ds_to_es_bus_reg;
/*-------------------------------------------------------*/

/*-----------------------deliver es_to_ms_bus----------------*/

wire [31:0] es_time_cnt_result;
assign es_time_cnt_result = es_rdcnt_high_or_low ? global_time_cnt[63:32] : global_time_cnt[31:0];

wire [31:0] es_alu_result;    //alu result(including mul_result)
//wire [31:0] div_result;
wire [31:0] es_calcu_result;  // alu_result or div_result or global_time_cnt
assign es_calcu_result = es_if_rdcnt ? es_time_cnt_result : es_need_wait_div ? div_result : es_alu_result;
//task 11 add Unaligned memory access, we should deliver unaligned info
wire [1:0] es_unaligned_addr;
//assign es_unaligned_addr = es_alu_result[1:0];
//after tlb , we should use p address
assign es_unaligned_addr = address_p[1:0];

assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we & ~es_ex_ALE &
                             ~es_ex_load_invalid & ~es_ex_loadstore_plv_invalid & ~es_ex_loadstore_tlb_fill &
                             ~es_ex_store_invalid & ~es_ex_store_dirty & ~es_ex_ADEM;     //when ld_w ALE happen, we stop write reg_file, when st_w ALE happen, gr_we is down originally 
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_calcu_result;
assign es_to_ms_bus[72:71] = es_unaligned_addr;
assign es_to_ms_bus[77:73] = es_ld_op;

//task12
assign es_to_ms_bus[91:78] = es_csr_num;
assign es_to_ms_bus[123:92] = es_csr_wmask;
assign es_to_ms_bus[124:124] = es_csr_write;
assign es_to_ms_bus[125:125] = es_ertn_flush;
assign es_to_ms_bus[126:126] = es_csr;

wire [31:0] es_csr_wvalue;
//tlbsrch: got --> write ne=0 and index ; miss --> write ne=1 only
assign es_csr_wvalue = es_rkd_value; //es_inst_tlbsrch ? (s1_found ? {1'b0, 27'b0, s1_index} : {1'b1, 31'b0}) :
                       

wire [31:0] es_vaddr;
assign es_vaddr = es_alu_result;

assign es_to_ms_bus[158:127] = es_csr_wvalue;
assign es_to_ms_bus[159:159] = es_ex_syscall;
assign es_to_ms_bus[174:160] = es_code;
assign es_to_ms_bus[175:175] = es_ex_INE;
assign es_to_ms_bus[176:176] = es_ex_ADEF;
assign es_to_ms_bus[177:177] = es_ex_ALE;
assign es_to_ms_bus[178:178] = es_ex_break;
assign es_to_ms_bus[179:179] = es_has_int;
assign es_to_ms_bus[211:180] = es_vaddr;

//task14
//when st, we need raise ms_ready_go when data_ok
//so we need to tell ms that it's a st inst
assign es_to_ms_bus[212:212] = es_mem_we;

//tlb add
assign es_to_ms_bus[213:213] = es_inst_tlbsrch;
assign es_to_ms_bus[214:214] = es_inst_tlbrd;
assign es_to_ms_bus[215:215] = es_inst_tlbwr;
assign es_to_ms_bus[216:216] = es_inst_tlbfill;
assign es_to_ms_bus[217:217] = es_inst_invtlb;

assign es_to_ms_bus[218:218] = s1_found;    //tlbsrch got
assign es_to_ms_bus[222:219] = s1_index;    //tlbsrch index

assign es_to_ms_bus[227:223] = es_inst_invtlb_op;
assign es_to_ms_bus[228:228] = es_tlb_zombie;

assign es_to_ms_bus[238:229] = es_rj_value[9:0];

//tlb exception
assign es_to_ms_bus[239:239] = es_ex_fetch_tlb_refill;
assign es_to_ms_bus[240:240] = es_ex_inst_invalid;
assign es_to_ms_bus[241:241] = es_ex_fetch_plv_invalid;
assign es_to_ms_bus[242:242] = es_ex_loadstore_tlb_fill;
assign es_to_ms_bus[243:243] = es_ex_load_invalid;
assign es_to_ms_bus[244:244] = es_ex_store_invalid;
assign es_to_ms_bus[245:245] = es_ex_loadstore_plv_invalid;
assign es_to_ms_bus[246:246] = es_ex_store_dirty;

//ADEM exception
assign es_to_ms_bus[247:247] = es_ex_ADEM;

/*-------------------------------------------------------*/

/*-------------------------link alu---------------------*/

wire [31:0] alu_src1;
wire [31:0] alu_src2;

assign alu_src1 = es_src1_is_pc  ? es_pc[31:0] : es_rj_value;   
assign alu_src2 = es_src2_is_imm ? es_imm : es_rkd_value;        

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (es_alu_result)
    );

/*-------------------------------------------------------*/

/*-----------------------deal with div-------------------*/
wire signed_dividend_tvalid, unsigned_dividend_tvalid;
wire signed_divisor_tvalid, unsigned_divisor_tvalid;
wire signed_dividend_tready, unsigned_dividend_tready;
wire signed_divisor_tready, unsigned_divisor_tready;
wire signed_out_tvalid, unsigned_out_tvalid;

wire [31:0] signed_dividend, unsigned_dividend;
wire [31:0] signed_divisor, unsigned_divisor;
wire [63:0] signed_result, unsigned_result;
wire [31:0] signed_div_result, unsigned_div_result;
wire [31:0] signed_mod_result, unsigned_mod_result;

assign signed_dividend = es_rj_value;
assign unsigned_dividend = es_rj_value;
assign signed_divisor = es_rkd_value;
assign unsigned_divisor = es_rkd_value;

assign signed_div_result = signed_result[63:32];
assign signed_mod_result = signed_result[31:0];
assign unsigned_div_result = unsigned_result[63:32];
assign unsigned_mod_result = unsigned_result[31:0];

wire [31:0] div_result;
assign div_result = (~es_div_op[1] & ~es_div_op[0]) ? signed_div_result :
                    (~es_div_op[1] &  es_div_op[0]) ? unsigned_div_result :
                    ( es_div_op[1] & ~es_div_op[0]) ? signed_mod_result :
                    ( es_div_op[1] &  es_div_op[0]) ? unsigned_mod_result :
                    32'b0;

div_signed signed_div(
    .aclk(clk),
    .s_axis_divisor_tdata(signed_divisor),
    .s_axis_divisor_tready(signed_divisor_tready),
    .s_axis_divisor_tvalid(signed_divisor_tvalid),
    .s_axis_dividend_tdata(signed_dividend),
    .s_axis_dividend_tready(signed_dividend_tready),
    .s_axis_dividend_tvalid(signed_dividend_tvalid),
    .m_axis_dout_tdata(signed_result),
    .m_axis_dout_tvalid(signed_out_tvalid)
);

div_unsigned unsigned_div(
    .aclk(clk),
    .s_axis_divisor_tdata(unsigned_divisor),
    .s_axis_divisor_tready(unsigned_divisor_tready),
    .s_axis_divisor_tvalid(unsigned_divisor_tvalid),
    .s_axis_dividend_tdata(unsigned_dividend),
    .s_axis_dividend_tready(unsigned_dividend_tready),
    .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
    .m_axis_dout_tdata(unsigned_result),
    .m_axis_dout_tvalid(unsigned_out_tvalid)
);

reg signed_dividend_tvalid_reg, unsigned_dividend_tvalid_reg;
reg signed_divisor_tvalid_reg, unsigned_divisor_tvalid_reg;

//div_signed dividend shake hand
//assign signed_dividend_tvalid = if_ms_ex ? 1'b0 : init ? (es_need_wait_div && ~es_div_op[0]) : signed_dividend_tvalid_reg;
assign signed_dividend_tvalid = init ? (es_need_wait_div && ~es_div_op[0]) : signed_dividend_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            signed_dividend_tvalid_reg <= 0;
        else if(signed_dividend_tready)               //shake hand
            signed_dividend_tvalid_reg <= 0;
        else if(es_need_wait_div && ~es_div_op[0] && init)    //div_w or mod_w
            signed_dividend_tvalid_reg <= 1;
    end

//div_signed divisor shake hand
//assign signed_divisor_tvalid = if_ms_ex ? 1'b0 : init ? (es_need_wait_div && ~es_div_op[0]) : signed_divisor_tvalid_reg;
assign signed_divisor_tvalid = init ? (es_need_wait_div && ~es_div_op[0]) : signed_divisor_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            signed_divisor_tvalid_reg <= 0;
        else if(signed_divisor_tready)                //shake hand
            signed_divisor_tvalid_reg <= 0;
        else if(es_need_wait_div && ~es_div_op[0] && init)    //div_w or mod_w
            signed_divisor_tvalid_reg <= 1;
    end

//div_unsigned dividend shake hand
//assign unsigned_dividend_tvalid = if_ms_ex ? 1'b0 : init ? (es_need_wait_div && es_div_op[0]) : unsigned_dividend_tvalid_reg;
assign unsigned_dividend_tvalid = init ? (es_need_wait_div && es_div_op[0]) : unsigned_dividend_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            unsigned_dividend_tvalid_reg <= 0;
        else if(unsigned_dividend_tready)               //shake hand
            unsigned_dividend_tvalid_reg <= 0;
        else if(es_need_wait_div && es_div_op[0] && init)    //div_wu or mod_ww
            unsigned_dividend_tvalid_reg <= 1;
    end

//div_unsigned divisor shake hand
//assign unsigned_divisor_tvalid = if_ms_ex ? 1'b0 : init ? (es_need_wait_div && es_div_op[0]) : unsigned_divisor_tvalid_reg;
assign unsigned_divisor_tvalid = init ? (es_need_wait_div && es_div_op[0]) : unsigned_divisor_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            unsigned_divisor_tvalid_reg <= 0;
        else if(unsigned_divisor_tready)                //shake hand
            unsigned_divisor_tvalid_reg <= 0;
        else if(es_need_wait_div && es_div_op[0] && init)    //div_wu or mod_wu
            unsigned_divisor_tvalid_reg <= 1;
    end

/*-------------------------------------------------------*/

/*-------------------------valid-------------------------*/
wire no_exception;
assign no_exception = ~if_es_ex && ~if_ms_ex && ~wb_ex && ~es_has_int;


assign data_sram_req = (ms_allow_in && no_exception) && (es_res_from_mem || es_mem_we) && es_valid;
reg es_valid;   

wire es_ready_go;

assign es_ready_go = if_es_ex ? 1'b1 : 
                      es_inst_tlbsrch ? ((if_ms_crush_with_tlbsrch | if_ws_crush_with_tlbsrch) ? 1'b0 : 1'b1) :   //tlb add
                     (es_mem_we || es_res_from_mem) ? (data_sram_req && data_sram_addr_ok) : 
                     (!es_need_wait_div || (signed_out_tvalid || unsigned_out_tvalid));

assign es_allow_in = !es_valid || es_ready_go && ms_allow_in;
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk)
    begin
        if(reset)
            es_valid <= 1'b0;
        else if(es_allow_in)
            es_valid <= ds_to_es_valid;
    end

/*-------------------------------------------------------*/

/*----------------------link data_sram------------------*/
//task 11 add Unaligned memory access, so addr[1:0] should be 2'b00
wire [3:0] w_strb;  //depend on st_op
/* st_op = (one hot)
* 3'b001 st_w
* 3'b010 st_b
* 3'b100 st_h
*/
assign w_strb =  es_st_op[0] ? 4'b1111 :
                 es_st_op[1] ? (es_unaligned_addr==2'b00 ? 4'b0001 : es_unaligned_addr==2'b01 ? 4'b0010 : 
                                es_unaligned_addr==2'b10 ? 4'b0100 : 4'b1000) : 
                 es_st_op[2] ? (es_unaligned_addr[1] ? 4'b1100 : 4'b0011) : 4'b0000;

//consider st_b, st_h
wire [31:0] real_wdata;
assign real_wdata = es_st_op[0] ? es_rkd_value :
                    es_st_op[1] ? {4{es_rkd_value[7:0]}} :
                    es_st_op[2] ? {2{es_rkd_value[15:0]}} : 32'b0;


//task13 add ALE error load or store address

wire es_ex_ALE;
//es_ex_ALE is for lw,h,hu and sw,h, it is normal that  ld_b ld_bu and st_b inst's last 2 bits not zero
//ld_op[0] --> lw ; st_op[0] --> sw ; ld_op[3] --> lh ; ld_op[4] --> lhu ; st_op[2] --> sh
wire if_lw_and_sw;
assign if_lw_and_sw = (es_res_from_mem && es_ld_op[0]) || (es_mem_we && es_st_op[0]);
wire if_lh_and_sh;
assign if_lh_and_sh = (es_res_from_mem && (es_ld_op[3] || es_ld_op[4])) || (es_mem_we && es_st_op[2]);

assign es_ex_ALE = ((if_lw_and_sw && (es_unaligned_addr[1] | es_unaligned_addr[0]))
                    || (if_lh_and_sh && es_unaligned_addr[0])) && es_valid ;
//maybe have problem
wire es_ex_ADEM;
assign es_ex_ADEM = if_ppt && (plv ==3) &&(es_res_from_mem||es_mem_we)?es_alu_result[31]:1'b0;

wire if_es_ex;
assign if_es_ex = es_ex_syscall || es_ertn_flush || es_ex_ADEF || es_ex_ALE || es_ex_INE || es_ex_break || es_has_int 
                || es_ex_fetch_tlb_refill || es_ex_inst_invalid || es_ex_fetch_plv_invalid
                || es_ex_loadstore_tlb_fill || es_ex_load_invalid || es_ex_store_invalid
                || es_ex_loadstore_plv_invalid || es_ex_store_dirty || es_ex_ADEM;


/*
    output              data_sram_req,
    output              data_sram_wr,
    output [1:0]        data_sram_size,
    output [3:0]        data_sram_wstrb,
    output [31:0]       data_sram_addr,
    output [31:0]       data_sram_wdata,
*/

assign data_sram_wr = es_mem_we;   
assign data_sram_size = es_mem_we ? 
                        (es_st_op[0] ? 2'b10 :  //st_w  
                         es_st_op[1] ? 2'b00 :  //st_b
                         es_st_op[2] ? 2'b01 : 2'b00)
                        :
                        es_res_from_mem ?
                        (es_ld_op[0] ? 2'b10 :  //ld_w
                         (es_ld_op[1] | es_ld_op[2]) ? 2'b00 :  //ld_b. ld_bu
                         (es_ld_op[3] | es_ld_op[4]) ? 2'b01 : 2'b00)
                        :
                        2'b00;

assign data_sram_wstrb = es_st_op[0] ? 4'b1111 :
                         es_st_op[1] ? (es_unaligned_addr==2'b00 ? 4'b0001 : es_unaligned_addr==2'b01 ? 4'b0010 : 
                                es_unaligned_addr==2'b10 ? 4'b0100 : 4'b1000) : 
                         es_st_op[2] ? (es_unaligned_addr[1] ? 4'b1100 : 4'b0011) : 4'b0000;

/*----------------------------------------------------------------------*/

wire [31:0] address_dt;     //dt --> directly translate
assign address_dt = es_alu_result;

wire [31:0] address_dmw0;
assign address_dmw0 = {DMW0_PSEG, es_alu_result[28:0]};

wire [31:0] address_dmw1;
assign address_dmw1 = {DMW1_PSEG, es_alu_result[28:0]};

wire [31:0] address_ptt;
assign address_ptt = {s1_ppn, es_alu_result[11:0]};

wire if_dt;
assign if_dt = crmd_da & ~crmd_pg;   //da=1, pg=0 --> 直接地址翻译模式

wire if_indt;
assign if_indt = ~crmd_da & crmd_pg;   //da=0, pg=1 --> 映射地址翻译模式

wire if_dmw0;
assign if_dmw0 = ((plv == 0 && DMW0_PLV0) || (plv == 3 && DMW0_PLV3)) &&
                    (datm == DMW0_MAT) && (es_alu_result[31:29] == DMW0_VSEG);
                    
wire if_dmw1;
assign if_dmw1 = ((plv == 0 && DMW1_PLV0) || (plv == 3 && DMW1_PLV3)) &&
                    (datm == DMW1_MAT) && (es_alu_result[31:29] == DMW1_VSEG);

wire [31:0] address_p;
assign address_p = if_dt ? address_dt : if_indt ?
                (if_dmw0 ? address_dmw0 : if_dmw1 ? address_dmw1 : address_ptt) : 0;

/*
1: es_ex_loadstore_tlb_refill   TLB重填例外
2: es_ex_load_invalid           load操作页无效例外
3: es_ex_store_invalid          store操作页无效例外
4: es_ex_loadstore_plv_invalid  页特权等级不合规例外
5：es_ex_store_dirty               页修改例外  
*/

wire es_ex_loadstore_tlb_fill;
wire es_ex_load_invalid;
wire es_ex_store_invalid;
wire es_ex_loadstore_plv_invalid;
wire es_ex_store_dirty;

wire if_ppt;
assign if_ppt = if_indt & ~(if_dmw0 | if_dmw1);

assign es_ex_loadstore_tlb_fill = if_ppt & (es_res_from_mem | es_mem_we) & ~s1_found;
assign es_ex_load_invalid = if_ppt & es_res_from_mem & s1_found & ~s1_v;
assign es_ex_store_invalid = if_ppt & es_mem_we & s1_found & ~s1_v;
assign es_ex_loadstore_plv_invalid = if_ppt & (es_res_from_mem | es_mem_we) & s1_found
                                    & s1_v & (plv > s1_plv);
assign es_ex_store_dirty = if_ppt & es_mem_we & s1_found & s1_v *& (plv <= s1_plv) & ~s1_d;

/*----------------------------------------------------------------------*/

assign data_sram_addr  = address_p;
assign data_sram_wdata = real_wdata;        
/*--------------------------------------------------------*/

/*-----------------------deliver es_to_ds_bus----------------*/
wire if_es_load;   //if inst is load --> which means forward needs block for one clk
assign if_es_load = es_res_from_mem;
//task12 add es_csr_write, es_csr_num
assign es_to_ds_bus = {es_valid,es_gr_we,es_dest,if_es_load,es_calcu_result,
                       es_csr_write, es_csr_num, es_csr};

/*-------------------------------------------------------*/

endmodule