`include "width.vh"
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

    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [1:0]  inst_sram_size,
    output wire [3:0]  inst_sram_wstrb,   
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface

    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [1:0]  data_sram_size,
    output wire [3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
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

//task12 -- from ms to es --> help judge store
wire if_ms_ex;

//task12,13 add
wire [`WIDTH_CSR_NUM-1:0] csr_num;
wire                      csr_re;
wire [31:0]               csr_rvalue;
wire [31:0]               ertn_pc;
wire [31:0]               ex_entry;

wire                      csr_we;
wire [31:0]               csr_wvalue;
wire [31:0]               csr_wmask;

wire                      wb_ex;
wire [31:0]               wb_pc; 
wire                      ertn_flush;
wire [5:0]                wb_ecode;
wire [8:0]                wb_esubcode;
wire [31:0]               wb_vaddr;
wire [31:0]               coreid_in;

wire                      has_int;
wire [7:0]                hw_int_in = 8'b0;
wire                      ipi_int_in = 1'b0;

//global timer counter (64bit)
reg [63:0] global_time_cnt;

always @(posedge clk)
    begin
        if(reset)
            global_time_cnt <= 0;
        else if(global_time_cnt == 64'hffffffffffffffff)
            global_time_cnt <= 0;
        else
            global_time_cnt <= global_time_cnt + 1'b1;
    end

//task13
/*
为CPU增加取指地址错(ADEF)、地址非对齐(ALE)、断点(BRK)和指令不存在(INE)异常的支持
*/

/*---------------------------FETCH--------------------------*/

stage1_IF fetch(
    .clk                (clk),
    .reset              (reset),
    .ertn_flush         (ertn_flush),
    .ertn_pc            (ertn_pc),
    .ex_entry           (ex_entry),
    .wb_ex              (wb_ex),

    .ds_allow_in        (ds_allow_in),
    .br_bus             (br_bus),
    .fs_to_ds_valid     (fs_to_ds_valid),
    .fs_to_ds_bus       (fs_to_ds_bus),

    .inst_sram_req      (inst_sram_req),
    .inst_sram_wr       (inst_sram_wr),
    .inst_sram_size     (inst_sram_size),
    .inst_sram_wstrb    (inst_sram_wstrb),
    .inst_sram_addr     (inst_sram_addr),
    .inst_sram_wdata    (inst_sram_wdata),
    .inst_sram_addr_ok  (inst_sram_addr_ok),
    .inst_sram_data_ok  (inst_sram_data_ok),
    .inst_sram_rdata    (inst_sram_rdata)
);

/*----------------------------------------------------------*/


/*---------------------------DECODE--------------------------*/

stage2_ID decode(
    .clk                (clk),
    .reset              (reset),
    .ertn_flush         (ertn_flush), 
    .has_int            (has_int),
    .wb_ex              (wb_ex),

    .es_allow_in        (es_allow_in),
    .ds_allow_in        (ds_allow_in),

    .fs_to_ds_valid     (fs_to_ds_valid),
    .ds_to_es_valid     (ds_to_es_valid),

    .fs_to_ds_bus       (fs_to_ds_bus),
    .ds_to_es_bus       (ds_to_es_bus),

    .ws_to_ds_bus       (ws_to_ds_bus),
    .br_bus             (br_bus),

    .es_to_ds_bus       (es_to_ds_bus),
    .ms_to_ds_bus       (ms_to_ds_bus),

    .data_sram_data_ok  (data_sram_data_ok)
);

/*----------------------------------------------------------*/


/*---------------------------EXCUTE-------------------------*/

stage3_EX ex(
    .clk                (clk),
    .reset              (reset),
    .ertn_flush         (ertn_flush),
    .wb_ex              (wb_ex),

    .ms_allow_in        (ms_allow_in),
    .es_allow_in        (es_allow_in),

    .ds_to_es_valid     (ds_to_es_valid),
    .es_to_ms_valid     (es_to_ms_valid),

    .ds_to_es_bus       (ds_to_es_bus),
    .es_to_ms_bus       (es_to_ms_bus),
    .es_to_ds_bus       (es_to_ds_bus),
    .if_ms_ex      (if_ms_ex),

    .data_sram_req      (data_sram_req),
    .data_sram_wr       (data_sram_wr),
    .data_sram_size     (data_sram_size),
    .data_sram_wstrb    (data_sram_wstrb),
    .data_sram_addr     (data_sram_addr),
    .data_sram_wdata    (data_sram_wdata),

    .data_sram_addr_ok  (data_sram_addr_ok),
    .data_sram_data_ok  (data_sram_data_ok),

    .global_time_cnt    (global_time_cnt)
);

/*----------------------------------------------------------*/

/*---------------------------MEM----------------------------*/

stage4_MEM mem(
    .clk                (clk),
    .reset              (reset),
    .ertn_flush         (ertn_flush),
    .wb_ex              (wb_ex),

    .ws_allow_in        (ws_allow_in),
    .ms_allow_in        (ms_allow_in),

    .es_to_ms_valid     (es_to_ms_valid),
    .ms_to_ws_valid     (ms_to_ws_valid),

    .es_to_ms_bus       (es_to_ms_bus),
    .ms_to_ws_bus       (ms_to_ws_bus),
    .ms_to_ds_bus       (ms_to_ds_bus),
    .if_ms_ex           (if_ms_ex),

    .data_sram_data_ok  (data_sram_data_ok),
    .data_sram_rdata    (data_sram_rdata)
);

/*----------------------------------------------------------*/

/*---------------------------WBACK--------------------------*/

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
    .debug_wb_rf_wdata  (debug_wb_rf_wdata),

    //task12 add
    .csr_num            (csr_num),
    .csr_re             (csr_re),
    .csr_rvalue         (csr_rvalue),
    .csr_we             (csr_we),
    .csr_wvalue         (csr_wvalue),
    .csr_wmask          (csr_wmask),
    .ertn_flush         (ertn_flush),
    .wb_ex              (wb_ex),
    .wb_pc              (wb_pc),
    .wb_ecode           (wb_ecode),
    .wb_esubcode        (wb_esubcode),
    .wb_vaddr           (wb_vaddr)
);

/*----------------------------------------------------------*/

/*
module csr_reg(
    input                         clk,
    input                         reset,

    input [`WIDTH_CSR_NUM-1:0]     csr_num,           //寄存器号

    input                         csr_re,            //读使能
    output             [31:0]     csr_rvalue,        //读数据
    output             [31:0]     ertn_pc,
    output             [31:0]     ex_entry,

    input                         csr_we,            //写使能
    input              [31:0]     csr_wmask,         //写掩码
    input              [31:0]     csr_wvalue,        //写数据

    input                         wb_ex,             //写回级异常
    input              [31:0]     wb_pc,             //异常pc
    input                         ertn_flush,        //ertn指令执行有效信号
    input              [5:0]      wb_ecode,          //异常类型1级码
    input              [8:0]      wb_esubcode,       //异常类型2级码
    input              [31:0]     wb_vaddr, 
    input              [31:0]     coreid_in,

    output                        has_int,
    input              [7:0]      hw_int_in,
    input                         ipi_int_in
);
*/

/*---------------------------csr_reg--------------------------*/
csr_reg cr(
    .clk                (clk),
    .reset              (reset),

    .csr_num            (csr_num),
    
    .csr_re             (csr_re),
    .csr_rvalue         (csr_rvalue),
    .ertn_pc            (ertn_pc),
    .ex_entry           (ex_entry),

    .csr_we             (csr_we),
    .csr_wmask          (csr_wmask),
    .csr_wvalue         (csr_wvalue),

    .wb_ex              (wb_ex),
    .wb_pc              (wb_pc),
    .ertn_flush         (ertn_flush),
    .wb_ecode           (wb_ecode),
    .wb_esubcode        (wb_esubcode), 
    .wb_vaddr           (wb_vaddr),
    .coreid_in          (coreid_in),

    .has_int            (has_int),
    .hw_int_in          (hw_int_in),
    .ipi_int_in         (ipi_int_in)
);

/*------------------------------------------------------------*/

endmodule