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

    output data_sram_en,
    output [3:0]data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,

    input [63:0] global_time_cnt
);

/*-----------------------閹恒儲鏁筪s_to_es_bus----------------*/
/*
assign ds_to_es_bus[31:   0] = ds_pc;        
assign ds_to_es_bus[63:  32] = rj_value;  
assign ds_to_es_bus[95:  64] = rkd_value; 
assign ds_to_es_bus[127: 96] = imm;       
assign ds_to_es_bus[132:128] = dest;      
assign ds_to_es_bus[133:133] = gr_we;     
assign ds_to_es_bus[134:134] = mem_we;    
assign ds_to_es_bus[149:135] = alu_op;    
assign ds_to_es_bus[150:150] = src1_is_pc;   
assign ds_to_es_bus[151:151] = src2_is_imm;  
assign ds_to_es_bus[152:152] = res_from_mem; 
assign ds_to_es_bus[153:153] = need_wait_div;
assign ds_to_es_bus[155:154] = div_op;
assign ds_to_es_bus[160:156] = ld_op;
assign ds_to_es_bus[163:161] = st_op;

//task12
assign ds_to_es_bus[177:164] = ds_csr_num;
assign ds_to_es_bus[209:178] = ds_csr_wmask;
assign ds_to_es_bus[210:210] = ds_csr_write;
assign ds_to_es_bus[211:211] = ds_ertn_flush;
assign ds_to_es_bus[212:212] = ds_csr;
assign ds_to_es_bus[213:213] = ds_ex_syscall;
assign ds_to_es_bus[228:214] = ds_code;

//task13
assign ds_to_es_bus[229:229] = inst_rdcntvl_w || inst_rdcntvh_w; 
assign ds_to_es_bus[230:230] = inst_rdcntvh_w;
assign ds_to_es_bus[231:231] = ds_ex_INE;
assign ds_to_es_bus[232:232] = ds_ex_ADEF;
assign ds_to_es_bus[233:233] = ds_ex_break;
assign ds_to_es_bus[234:234] = ds_has_int;
*/
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

reg [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ds_to_es_bus_reg <= 0;
        else if(ertn_flush || wb_ex)
            ds_to_es_bus_reg <= 0;
        else if(ds_to_es_valid && es_allow_in)
            ds_to_es_bus_reg <= ds_to_es_bus;
        else if(es_need_wait_div)        
            ds_to_es_bus_reg <= ds_to_es_bus_reg;
        else
            ds_to_es_bus_reg <= 0;
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

assign {es_has_int, es_ex_break, es_ex_ADEF, es_ex_INE, es_rdcnt_high_or_low, es_if_rdcnt,
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
assign es_unaligned_addr = es_alu_result[1:0];

assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we & ~es_ex_ALE;     //when ld_w ALE happen, we stop write reg_file, when st_w ALE happen, gr_we is down originally 
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
assign es_csr_wvalue = es_rkd_value;
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
reg es_valid;   

wire es_ready_go;
assign es_ready_go = es_need_wait_div ? (signed_out_tvalid || unsigned_out_tvalid) : 1'b1;
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

//task12 add 
/*
庆幸的是，就目前
支持的指令和异常类型来说，指令在访存级和写回级不会再判断出新的异常了。也就是说，位于
执行级的 store 指令只需要检查当前访存级和写回级上有没有已标记为异常的指令就可以了，当
然，它也在执行级检查自己有没有被标记上异常。
*/

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

wire if_es_ex;
assign if_es_ex = es_ex_syscall || es_ertn_flush || es_ex_ADEF || es_ex_ALE || es_ex_INE || es_ex_break || es_has_int;

/*
assign if_ms_ex = ms_ex_syscall || ms_ertn_flush || ms_ex_ADEF || ms_ex_INE || ms_ex_ALE || ms_ex_break || ms_has_int;
*/

assign data_sram_en = ~es_ex_ALE;   //when ALE, stop read

// when es_ex or ex before es_inst or es_has_int, stop write 
assign data_sram_wen = ((es_mem_we && es_valid) && ~if_es_ex && ~if_ms_ex && ~wb_ex && ~es_has_int) ? w_strb : 4'b0000;

assign data_sram_addr  = {es_alu_result[31:2],2'b00};
assign data_sram_wdata = real_wdata;        
/*--------------------------------------------------------*/

/*-----------------------deliver es_to_ds_bus----------------*/
wire IF_LOAD;   //if inst is load --> which means forward needs block for one clk
assign IF_LOAD = es_res_from_mem;
//task12 add es_csr_write, es_csr_num
assign es_to_ds_bus = {es_gr_we,es_dest,IF_LOAD,es_calcu_result,
                       es_csr_write, es_csr_num, es_csr};

/*-------------------------------------------------------*/

endmodule