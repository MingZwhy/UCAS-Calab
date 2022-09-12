`define WIDTH_BR_BUS       34
`define WIDTH_FS_TO_DS_BUS 64
`define WIDTH_DS_TO_ES_BUS 150
`define WIDTH_ES_TO_MS_BUS 71
`define WIDTH_MS_TO_WS_BUS 70
`define WIDTH_WS_TO_DS_BUS 38
`define WIDTH_ES_TO_DS_BUS 6
`define WIDTH_MS_TO_DS_BUS 6
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

