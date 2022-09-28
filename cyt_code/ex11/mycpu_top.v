`define WIDTH_BR_BUS       34
`define WIDTH_FS_TO_DS_BUS 64
`define WIDTH_DS_TO_ES_BUS 164
`define WIDTH_ES_TO_MS_BUS 78
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

    //ws_to_ds_bus ³ÐÔØ ¼Ä´æÆ÷µÄÐ´ÐÅºÅ£¬Ð´µØ????????ÓëÐ´Êý¾Ý
    //´Ówback½×¶Î ËÍÀ´ decode½×¶Î 
    input [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus;
    //br_bus ³ÐÔØ br_taken ???????? br_target 
    //´Ódecode½×¶Î ËÍÍù fetch½×¶Î
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