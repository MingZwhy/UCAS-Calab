`define WIDTH_BR_BUS       33
`define WIDTH_FS_TO_DS_BUS 64
`define WIDTH_DS_TO_ES_BUS 150
`define WIDTH_ES_TO_MS_BUS 71
`define WIDTH_MS_TO_WS_BUS 70
`define WIDTH_WS_TO_DS_BUS 38
`define WIDTH_ES_TO_DS_BUS 6
`define WIDTH_MS_TO_DS_BUS 6

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
    end 

assign {ws_final_result, ws_dest,
        ws_gr_we, ws_pc} = ms_to_ws_bus_reg;

/*-------------------------------------------------------*/

/*----------------------发�?�ws_to_ds_bus-----------------*/

reg ws_valid;    //valid信号表示这一级流水缓存是否有�???

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
//reg ws_valid;    //valid信号表示这一级流水缓存是否有效，在上面定义是因为上面用了此信�???
wire ws_ready_go;
assign ws_ready_go = 1'b1;
assign ws_allow_in = ws_ready_go;

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