`define WIDTH_BR_BUS       34
`define WIDTH_FS_TO_DS_BUS 64
`define WIDTH_DS_TO_ES_BUS 150
`define WIDTH_ES_TO_MS_BUS 71
`define WIDTH_MS_TO_WS_BUS 70
`define WIDTH_WS_TO_DS_BUS 38
`define WIDTH_ES_TO_DS_BUS 39
`define WIDTH_MS_TO_DS_BUS 38
/*
`include "stage1_IF.v"
`include "stage2_ID.v"
`include "stage3_EX.v"
`include "stage4_MEM.v"
`include "stage5_WB.v"
*/

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,      
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
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

wire [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus;
wire ds_allow_in;
wire fs_to_ds_valid;
wire [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus;
wire es_allow_in;
wire ds_to_es_valid;
wire [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus;
wire ms_allow_in;
wire es_to_ms_valid;
wire [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus;
wire ws_allow_in;
wire ms_to_ws_valid;
wire [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus;

wire [`WIDTH_BR_BUS -1:0] br_bus;
wire [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus;
wire [`WIDTH_MS_TO_DS_BUS-1:0] ms_to_ds_bus;

/*---------------------------FETCH--------------------------*/
/*
module stage1_IF(
    input clk,
    input reset,
    input ds_allow_in,
    input [`WIDTH_BR_BUS-1:0] br_bus,
    output fs_to_ds_valid,
    output [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,

    output inst_sram_en,
    output [3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,

    input [31:0] inst_sram_rdata
);
*/

stage1_IF fetch(
    .clk                (clk),
    .reset              (reset),
    .ds_allow_in        (ds_allow_in),
    .br_bus             (br_bus),
    .fs_to_ds_valid     (fs_to_ds_valid),
    .fs_to_ds_bus       (fs_to_ds_bus),
    .inst_sram_en       (inst_sram_en),
    .inst_sram_wen      (inst_sram_we),
    .inst_sram_addr     (inst_sram_addr),
    .inst_sram_wdata    (inst_sram_wdata),
    .inst_sram_rdata    (inst_sram_rdata)
);

/*----------------------------------------------------------*/


/*---------------------------DECODE--------------------------*/
/*
module stage2_ID(
    input clk,
    input reset,

    input es_allow_in,
    output ds_allow_in,

    input fs_to_ds_valid,
    output ds_to_es_valid, 

    input [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,
    output [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,

    //ws_to_ds_bus 承载 寄存器的写信号，写地�???????与写数据
    //从wback阶段 送来 decode阶段 
    input [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus;
    //br_bus 承载 br_taken �??????? br_target 
    //从decode阶段 送往 fetch阶段
    output [`WIDTH_BR_BUS-1:0] br_bus,
);
*/

stage2_ID decode(
    .clk                (clk),
    .reset              (reset),

    .es_allow_in        (es_allow_in),
    .ds_allow_in        (ds_allow_in),

    .fs_to_ds_valid     (fs_to_ds_valid),
    .ds_to_es_valid     (ds_to_es_valid),

    .fs_to_ds_bus       (fs_to_ds_bus),
    .ds_to_es_bus       (ds_to_es_bus),

    .ws_to_ds_bus       (ws_to_ds_bus),
    .br_bus             (br_bus),

    .es_to_ds_bus       (es_to_ds_bus),
    .ms_to_ds_bus       (ms_to_ds_bus)
);

/*----------------------------------------------------------*/


/*---------------------------EXCUTE-------------------------*/
/*
module stage3_EX(
    input clk,
    input reset,

    input ms_allow_in,
    output es_allow_in,

    input ds_to_es_valid,
    output es_to_ms_valid,

    input [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,
    output [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,

    output data_sram_en,
    output [3:0]data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata
);
*/

stage3_EX ex(
    .clk                (clk),
    .reset              (reset),

    .ms_allow_in        (ms_allow_in),
    .es_allow_in        (es_allow_in),

    .ds_to_es_valid     (ds_to_es_valid),
    .es_to_ms_valid     (es_to_ms_valid),

    .ds_to_es_bus       (ds_to_es_bus),
    .es_to_ms_bus       (es_to_ms_bus),
    .es_to_ds_bus       (es_to_ds_bus),

    .data_sram_en       (data_sram_en),
    .data_sram_wen      (data_sram_we),
    .data_sram_addr     (data_sram_addr),
    .data_sram_wdata    (data_sram_wdata)
);

/*----------------------------------------------------------*/

/*---------------------------MEM----------------------------*/
/*
module stage4_MEM(
    input clk,
    input reset,

    input ws_allow_in,
    output ms_allow_in,

    input es_to_ms_valid,
    output ms_to_ws_valid,

    input [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    
    input [31:0] data_sram_rdata
);
*/

stage4_MEM mem(
    .clk                (clk),
    .reset              (reset),

    .ws_allow_in        (ws_allow_in),
    .ms_allow_in        (ms_allow_in),

    .es_to_ms_valid     (es_to_ms_valid),
    .ms_to_ws_valid     (ms_to_ws_valid),

    .es_to_ms_bus       (es_to_ms_bus),
    .ms_to_ws_bus       (ms_to_ws_bus),
    .ms_to_ds_bus       (ms_to_ds_bus),

    .data_sram_rdata    (data_sram_rdata)
);

/*----------------------------------------------------------*/

/*---------------------------WBACK--------------------------*/
/*
module stage5_WB(
    input clk,
    input reset,

    //no allow in
    output ws_allow_in,

    input ms_to_ws_valid,
    //no to valid

    input [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    output [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus,

    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_we ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
*/

stage5_WB wb(
    .clk                (clk),
    .reset              (reset),

    .ws_allow_in        (ws_allow_in),

    .ms_to_ws_valid     (ms_to_ws_valid),

    .ms_to_ws_bus       (ms_to_ws_bus),
    .ws_to_ds_bus       (ws_to_ds_bus),

    .debug_wb_pc        (debug_wb_pc),
    .debug_wb_rf_we     (debug_wb_rf_we),
    .debug_wb_rf_wnum   (debug_wb_rf_wnum),
    .debug_wb_rf_wdata  (debug_wb_rf_wdata)
);

/*----------------------------------------------------------*/

endmodule

module stage1_IF(
    input clk,
    input reset,
    input ds_allow_in,
    input [`WIDTH_BR_BUS-1:0] br_bus,
    output fs_to_ds_valid,
    output [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,

    output inst_sram_en,
    output [3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,

    input [31:0] inst_sram_rdata
);

/*--------------------------------valid-----------------------------*/

reg fs_valid;    //valid信号表示这一级流水缓存是否有�???????

//对fs_valid来说，只要取消reset，相当去前一阶段对它发来的valid信号
wire pre_if_to_fs_valid;
assign pre_if_to_fs_valid = !reset;

//fs_valid拉高的另�???????个条件是下一阶段的allow_in信号—�?�ds_allow_in
wire fs_ready_go;

always @(posedge clk)
    begin
        if(reset)
            fs_valid <= 1'b0;
        else if(fs_allow_in)
            fs_valid <= pre_if_to_fs_valid;
        /*
        else if(br_taken_cancel)
            fs_valid <= 1'b0;
        */
    end

//将output-fs_to_ds_valid与reg fs_valid连接
//考虑到后序可能一个clk完成不了FETCH，先增设fs_ready信号并始终拉�???????
assign fs_ready_go = 1'b1;
wire fs_allow_in;
assign fs_allow_in = !fs_valid || fs_ready_go && ds_allow_in;
assign fs_to_ds_valid = fs_valid && fs_ready_go;

/*----------------------------------------------------------------*/

/*--------------------------------pc------------------------------*/

wire [31:0] br_target;  //跳转地址
wire br_taken;          //是否跳转
wire br_taken_cancel;
//br_taken和br_target来自br_bus
assign {br_taken_cancel,br_taken,br_target} = br_bus;

reg [31:0] fetch_pc; 

wire [31:0] seq_pc;     //顺序取址
assign seq_pc = fetch_pc + 4;
wire [31:0] next_pc;    //nextpc来自seq或br,是�?�至ram的pc�???????
assign next_pc = br_taken? br_target : seq_pc;
   
always @(posedge clk)
    begin
        if(reset)
            fetch_pc <= 32'h1BFFFFFC;
        else if(pre_if_to_fs_valid && ds_allow_in)
            fetch_pc <= next_pc;
    end

/*----------------------------------------------------------------*/

/*----------------------------与inst_ram的接�???????---------------------*/

/*
    output inst_sram_en,                //读使�???????
    output [3:0] inst_sram_wen,         //写使�???????
    output [31:0] inst_sram_addr,       //读地�???????
    output [31:0] inst_sram_wdata,      //写数�???????
    input [31:0] inst_sram_rdata        //读到的数�???????-inst
*/

assign inst_sram_en = pre_if_to_fs_valid && ds_allow_in;
assign inst_sram_wen = 4'b0;    //fetch阶段不写
assign inst_sram_addr = next_pc;
assign inst_sram_wdata = 32'b0;

/*----------------------------------------------------------------*/

/*----------------------------发�?�fs_to_ds_bus------------------------*/
//要�?�往decode阶段的数据有PC与INST
//pc与inst�???????32位，因此fs_to_ds_bus�???????64�???????
wire [31:0] fetch_inst;
assign fetch_inst = inst_sram_rdata;
assign fs_to_ds_bus = {fetch_inst,fetch_pc};

/*----------------------------------------------------------------*/

endmodule

module stage2_ID(
    input clk,
    input reset,

    input es_allow_in,
    output ds_allow_in,

    input fs_to_ds_valid,
    output ds_to_es_valid, 

    input [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,
    output [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,

    //ws_to_ds_bus 承载 寄存器的写信号，写地�??????与写数据
    //从wback阶段 送来 decode阶段 
    input [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus,
    //br_bus 承载 br_taken �?????? br_target 
    //从decode阶段 送往 fetch阶段
    output [`WIDTH_BR_BUS-1:0] br_bus,

    input [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus,
    input [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ds_bus
);

/*-------------------------解码及控制信�??????--------------------------*/
wire [31:0] inst;

wire        br_taken;
wire [31:0] br_target;

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
//slt: rd = (signed(rj) < signed(rk)) ? 1 : 0  (视作有符号整数比较大�??????)
//asm: slt rd, rj, rk
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
//sltu: rd = (unsigned(rj) < unsigned(rk)) ? 1 : 0  (视作无符号整数比较大�??????)
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
//rj中的数�?�辑左移写入rd
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
//srli.w: rd = SRL(rj, ui5)  asm: srli.w rd, rj, ui5
//rj中的数�?�辑右移写入rd
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

//使用立即数种类�?�择
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;  
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;   
assign need_si16  =  inst_jirl | inst_beq | inst_bne;       
assign need_si20  =  inst_lu12i_w;          
assign need_si26  =  inst_b | inst_bl;      
//加法器第二个操作数�?�择—�?�是否为4
assign src2_is_4  =  inst_jirl | inst_bl;   

//branch的跳转地�??????目前只有两种—�?�si26与si16
assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :   
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;   
//jirl_offs单独列出主要是因为它不是b类型指令，也方便后序拓展
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};   

//src_reg_is_rd代表reg_file第二个读端口是否接rd，否则接rk
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

//used for judging br_taken
assign rj_eq_rd = (rj_value == rkd_value);

/*----------------------------------------------------------------*/

/*-----------------------接收fs_to_ds_bus----------------*/
//wire [31:0] inst; 定义在前�?????   
wire [31:0] ds_pc;

reg [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            fs_to_ds_bus_reg <= 0;
        else if(fs_to_ds_valid && ds_allow_in)         
            fs_to_ds_bus_reg <= fs_to_ds_bus;
    end
assign {inst,ds_pc} = fs_to_ds_bus_reg;         //_reg;
/*-------------------------------------------------------*/

/*-----------------------接收es,ms,ws_to_ds_bus----------------*/
wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we,rf_waddr,rf_wdata} = ws_to_ds_bus;

wire es_we;
wire [4:0] es_dest;
wire IF_LOAD;
wire [31:0] es_wdata;
wire ms_we;
wire [4:0] ms_dest;
wire [31:0] ms_wdata;

assign {es_we,es_dest,IF_LOAD,es_wdata} = es_to_ds_bus;
assign {ms_we,ms_dest,ms_wdata} = ms_to_ds_bus;
/*-------------------------------------------------------*/

/*-----------------------发�?�br_bus----------------------*/
assign br_taken = ((inst_beq && rj_eq_rd) || (inst_bne && !rj_eq_rd)   
                   || inst_jirl || inst_bl || inst_b) && ds_valid;

wire br_taken_cancel;
//assign br_taken_cancel = (inst_beq || inst_bne || inst_jirl || inst_bl || inst_b) && ds_valid;

assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ds_pc + br_offs) :   
                                                   /*inst_jirl*/ (rj_value + jirl_offs); 
assign br_bus = {br_taken_cancel,br_taken,br_target};           
/*-------------------------------------------------------*/

/*-----------------------发�?�ds_to_es_bus----------------*/
assign rj_value  = forward_rdata1;   
assign rkd_value = forward_rdata2;   
assign imm = src2_is_4 ? 32'h4                      :   
             need_si20 ? {i20[19:0], 12'b0}         :   
             need_ui5  ? {27'b0,rk[4:0]}            :   
             need_si12 ? {{20{i12[11]}}, i12[11:0]} :   
             32'b0 ;
assign dst_is_r1     = inst_bl;     //不需送出，只是辅助dest
assign dest = dst_is_r1 ? 5'd1 : rd;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;   
assign mem_we        = inst_st_w;

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

assign ds_to_es_bus[31:   0] = ds_pc;        //pc����fetch��???��execute
assign ds_to_es_bus[63:  32] = rj_value;  //reg_file������data1
assign ds_to_es_bus[95:  64] = rkd_value; //reg_file������data2
assign ds_to_es_bus[127: 96] = imm;       //ѡ��õ�����??????
assign ds_to_es_bus[132:128] = dest;      //д��Ĵ�����????
assign ds_to_es_bus[133:133] = gr_we;     //�Ƿ�д�Ĵ���
assign ds_to_es_bus[134:134] = mem_we;    //�Ƿ�д��??
assign ds_to_es_bus[146:135] = alu_op;    //alu����??
assign ds_to_es_bus[147:147] = src1_is_pc;   //����??1�Ƿ�Ϊpc
assign ds_to_es_bus[148:148] = src2_is_imm;  //����??2�Ƿ�Ϊ������
assign ds_to_es_bus[149:149] = res_from_mem; //д�Ĵ�������Ƿ������ڴ�????
/*-------------------------------------------------------*/

/*--------------------------------valid---------------------------*/
reg ds_valid;    //valid信号表示这一级流水缓存是否有�??????
//处理写后读冲�???
wire if_read_addr1;   //�Ƿ���Ĵ�����addr1
wire if_read_addr2;   //�Ƿ���Ĵ�����addr2

assign if_read_addr1 = ~inst_b && ~inst_bl;
assign if_read_addr2 = inst_beq || inst_bne || inst_xor || inst_or || inst_and || inst_nor ||
                       inst_sltu || inst_slt || inst_sub_w || inst_add_w || inst_st_w;

wire Need_Block;    //ex_crush & IF_LOAD

assign Need_Block = (ex_crush1 || ex_crush2) && IF_LOAD;

wire ex_crush1;
wire ex_crush2;
assign ex_crush1 = (es_we && es_dest!=0) && (if_read_addr1 && rf_raddr1==es_dest);
assign ex_crush2 = (es_we && es_dest!=0) && (if_read_addr2 && rf_raddr2==es_dest);

wire mem_crush1;
wire mem_crush2;
assign mem_crush1 = (ms_we && ms_dest!=0) && (if_read_addr1 && rf_raddr1==ms_dest);
assign mem_crush2 = (ms_we && ms_dest!=0) && (if_read_addr2 && rf_raddr2==ms_dest);

wire wb_crush1;
wire wb_crush2;
assign wb_crush1 = (rf_we && rf_waddr!=0) && (if_read_addr1 && rf_raddr1==rf_waddr);
assign wb_crush2 = (rf_we && rf_waddr!=0) && (if_read_addr2 && rf_raddr2==rf_waddr);

//forward deliver
wire [31:0] forward_rdata1;
wire [31:0] forward_rdata2;
assign forward_rdata1 = ex_crush1? es_wdata : mem_crush1? ms_wdata : wb_crush1? rf_wdata : rf_rdata1;
assign forward_rdata2 = ex_crush2? es_wdata : mem_crush2? ms_wdata : wb_crush2? rf_wdata : rf_rdata2;

wire ds_ready_go;
assign ds_ready_go = ~Need_Block;         
assign ds_allow_in = !ds_valid || ds_ready_go && es_allow_in;
assign ds_to_es_valid = ds_valid && ds_ready_go;

//当数据冲突，ds_ready_go拉低，ds_allow_in对应拉低，ds_to_es_valid对应拉低

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

/*-------------------------与regfile接口---------------------------*/
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
/*
assign {rf_we,rf_waddr,rf_wdata} = ws_to_ds_bus;
意在强调提醒此时的we，waddr和wdata来自wb阶段发来的信�??????
*/
/*----------------------------------------------------------------*/

endmodule

module stage3_EX(
    input clk,
    input reset,

    input ms_allow_in,
    output es_allow_in,

    input ds_to_es_valid,
    output es_to_ms_valid,

    input [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,
    output [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus,

    output data_sram_en,
    output [3:0]data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata
);

/*-----------------------接收ds_to_es_bus----------------*/
/*
assign ds_to_es_bus[31:   0] = ds_pc;        //pc����fetch��???��execute
assign ds_to_es_bus[63:  32] = rj_value;  //reg_file������data1
assign ds_to_es_bus[95:  64] = rkd_value; //reg_file������data2
assign ds_to_es_bus[127: 96] = imm;       //ѡ��õ�����??????
assign ds_to_es_bus[132:128] = dest;      //д��Ĵ�����????
assign ds_to_es_bus[133:133] = gr_we;     //�Ƿ�д�Ĵ���
assign ds_to_es_bus[134:134] = mem_we;    //�Ƿ�д��??
assign ds_to_es_bus[146:135] = alu_op;    //alu����??
assign ds_to_es_bus[147:147] = src1_is_pc;   //����??1�Ƿ�Ϊpc
assign ds_to_es_bus[148:148] = src2_is_imm;  //����??2�Ƿ�Ϊ������
assign ds_to_es_bus[149:149] = res_from_mem; //д�Ĵ�������Ƿ������ڴ�????
*/
wire [31:0] es_pc;
wire [31:0] es_rj_value;
wire [31:0] es_rkd_value;
wire [31:0] es_imm;
wire [4:0]  es_dest;
wire        es_gr_we;
wire        es_mem_we;
wire [11:0] es_alu_op;
wire        es_src1_is_pc;
wire        es_src2_is_imm;
wire        es_res_from_mem;

reg [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ds_to_es_bus_reg <= 0;
        else if(ds_to_es_valid && es_allow_in)
            ds_to_es_bus_reg <= ds_to_es_bus;
        else
            ds_to_es_bus_reg <= 0; 
    end

assign {es_res_from_mem, es_src2_is_imm, es_src1_is_pc,
        es_alu_op, es_mem_we, es_gr_we, es_dest, es_imm,
        es_rkd_value, es_rj_value, es_pc} = ds_to_es_bus_reg;
/*-------------------------------------------------------*/

/*-----------------------发�?�es_to_ms_bus----------------*/

wire [31:0] es_alu_result;

assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_alu_result;

/*-------------------------------------------------------*/

/*-------------------------与alu接口---------------------*/

//wire [31:0] es_alu_result; 在上面定义是因为上面用了此信�?????
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


/*-------------------------valid-------------------------*/
reg es_valid;    //valid信号表示这一级流水缓存是否有�??????

wire es_ready_go;
assign es_ready_go = 1'b1;
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

/*----------------------与data_sram接口-------------------*/
assign data_sram_en    = 1'b1;   //暂时是始终可读的
assign data_sram_wen   = (es_mem_we && es_valid) ? 4'b1111 : 4'b0000;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rkd_value;        //st_w指令写的是rd的value
/*--------------------------------------------------------*/

/*-----------------------发�?�es_to_ds_bus----------------*/
wire IF_LOAD;   //是否load指令，如果是load指令，前递仍然要阻塞一个周�?
assign IF_LOAD = es_res_from_mem;
assign es_to_ds_bus = {es_gr_we,es_dest,IF_LOAD,es_alu_result};

/*-------------------------------------------------------*/

endmodule

module stage4_MEM(
    input clk,
    input reset,

    input ws_allow_in,
    output ms_allow_in,

    input es_to_ms_valid,
    output ms_to_ws_valid,

    input [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    output [`WIDTH_MS_TO_DS_BUS-1:0] ms_to_ds_bus,
    
    input [31:0] data_sram_rdata
);

/*-----------------------接收es_to_ms_bus----------------*/
/*
assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_alu_result;
*/

wire [31:0] ms_pc;
wire ms_gr_we;
wire ms_res_from_mem;
wire [4:0] ms_dest;
wire [31:0] ms_alu_result;

reg [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            es_to_ms_bus_reg <= 0;
        else if(es_to_ms_valid && ms_allow_in)
            es_to_ms_bus_reg <= es_to_ms_bus;
        else
            es_to_ms_bus_reg <= 0;
    end 

assign {ms_alu_result, ms_dest, ms_res_from_mem,
        ms_gr_we, ms_pc} = es_to_ms_bus_reg;

/*-------------------------------------------------------*/

/*----------------------发�?�ms_to_ws_bus-----------------*/
wire [31:0] mem_result;
assign mem_result   = data_sram_rdata;
wire [31:0] ms_final_result;
assign ms_final_result = ms_res_from_mem? mem_result : ms_alu_result;

assign ms_to_ws_bus[31:0]  = ms_pc;
assign ms_to_ws_bus[32:32] = ms_gr_we;
assign ms_to_ws_bus[37:33] = ms_dest;
assign ms_to_ws_bus[69:38] = ms_final_result;
/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
reg ms_valid;    //valid信号表示这一级流水缓存是否有�?????

wire ms_ready_go;
assign ms_ready_go = 1'b1;
assign ms_allow_in = !ms_valid || ms_ready_go && ws_allow_in;
assign ms_to_ws_valid = ms_valid && ms_ready_go;

always @(posedge clk)
    begin
        if(reset)
            ms_valid <= 1'b0;
        else if(ms_allow_in)
            ms_valid <= es_to_ms_valid;
    end

/*-------------------------------------------------------*/

/*--------------------发�?�ms_to_ds_bus-------------------*/
assign ms_to_ds_bus = {ms_gr_we,ms_dest,ms_final_result};
/*-------------------------------------------------------*/

endmodule

module stage5_WB(
    input clk,
    input reset,

    //no allow in
    output ws_allow_in,

    input ms_to_ws_valid,
    //no to valid

    input [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    output [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus,

    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_we ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

/*-----------------------接收ms_to_ws_bus----------------*/
/*
assign ms_to_ws_bus[31:0]  = ms_pc;
assign ms_to_ws_bus[32:32] = ms_gr_we;
assign ms_to_ws_bus[37:33] = ms_dest;
assign ms_to_ws_bus[69:38] = ms_final_result;
*/

wire [31:0] ws_pc;
wire ws_gr_we;
wire [4:0] ws_dest;
wire [31:0] ws_final_result;

reg [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ms_to_ws_bus_reg <= 0;
        else if(ms_to_ws_valid && ws_allow_in)
            ms_to_ws_bus_reg <= ms_to_ws_bus;
        else
            ms_to_ws_bus_reg <= 0;
    end 

assign {ws_final_result, ws_dest,
        ws_gr_we, ws_pc} = ms_to_ws_bus_reg;

/*-------------------------------------------------------*/

/*----------------------发�?�ws_to_ds_bus-----------------*/

reg ws_valid;    //valid信号表示这一级流水缓存是否有�?????

wire ws_we;
assign ws_we = ws_gr_we && ws_valid;
wire [4:0] ws_waddr;
assign ws_waddr = ws_dest;
wire [31:0] ws_wdata;
assign ws_wdata = ws_final_result;

assign ws_to_ds_bus[31:0] = ws_wdata;
assign ws_to_ds_bus[36:32] = ws_waddr;
assign ws_to_ds_bus[37:37] = ws_we;

/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
//reg ws_valid;    //valid信号表示这一级流水缓存是否有效，在上面定义是因为上面用了此信�?????
wire ws_ready_go;
assign ws_ready_go = 1'b1;
assign ws_allow_in = !ws_valid || ws_ready_go;

always @(posedge clk)
    begin
        if(reset)
            ws_valid <= 1'b0;
        else if(ws_allow_in)
            ws_valid <= ms_to_ws_valid;
    end

/*-------------------------------------------------------*/

/*--------------------------debug reference--------------*/
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_we   = {4{ws_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;
/*-------------------------------------------------------*/

endmodule