`include "width.vh"

module stage5_WB(
    input clk,
    input reset,

    //no allow in
    output ws_allow_in,

    input ms_to_ws_valid,
    //no to valid

    input [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    output [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus,

    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_we ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,

    //task12
    output [`WIDTH_CSR_NUM-1:0] csr_num,
    output                      csr_re,
    input  [31:0]               csr_rvalue,

    output                      csr_we,
    output [31:0]               csr_wvalue,
    output [31:0]               csr_wmask,
    output                      ertn_flush,
    output                      wb_ex,
    output [31:0]               wb_pc,
    output [5:0]                wb_ecode,
    output [8:0]                wb_esubcode
);

/*-----------------------receive ms_to_ws_bus----------------*/
/*
assign ms_to_ws_bus[31:0]  = ms_pc;
assign ms_to_ws_bus[32:32] = ms_gr_we;
assign ms_to_ws_bus[37:33] = ms_dest;
assign ms_to_ws_bus[69:38] = ms_final_result;

//task12
assign ms_to_ws_bus[83:70] = ms_csr_num;
assign ms_to_ws_bus[115:84] = ms_csr_wmask;
assign ms_to_ws_bus[116:116] = ms_csr_write;
assign ms_to_ws_bus[117:117] = ms_ertn_flush;
assign ms_to_ws_bus[118:118] = ms_csr;
assign ms_to_ws_bus[150:119] = ms_csr_wvalue;
assign ms_to_ws_bus[151:151] = ms_ex_syscall;
assign ms_to_ws_bus[166:152] = ms_code;
*/

wire [31:0] ws_pc;
wire ws_gr_we;
wire [4:0] ws_dest;
wire [31:0] ws_final_result;

//task12
wire [13:0] ws_csr_num;
wire [31:0] ws_csr_wmask;
wire        ws_csr_write;
wire        ws_ertn_flush;
wire        ws_csr;
wire [31:0] ws_csr_wvalue;
wire        ws_ex_syscall;
wire [14:0] ws_code;

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

assign {ws_code, ws_ex_syscall, ws_csr_wvalue, ws_csr, ws_ertn_flush, ws_csr_write, ws_csr_wmask, ws_csr_num,
        ws_final_result, ws_dest,
        ws_gr_we, ws_pc} = ms_to_ws_bus_reg;

/*-------------------------------------------------------*/

/*---------------------------link csr_reg---------------------*/
assign csr_num = ws_csr_num;
assign csr_re = 1'b1;
//input [31:0] csr_rvalue

assign csr_we = ws_csr_write;
assign csr_wvalue = ws_csr_wvalue;
assign csr_wmask = ws_csr_wmask;
assign ertn_flush = ws_ertn_flush;

assign wb_ex = ws_ex_syscall;    // assign wb_ex = ws_ex_syscall || ws_ex_xxx || ......
assign wb_pc = ws_pc;

/*
 *deal with ecode and esubcode according to kind of ex
 *in task12, we just finish syscall
 */
assign wb_ecode = ws_ex_syscall ? 6'hb : 6'h0;          //syscall
assign wb_esubcode = ws_ex_syscall ? 9'h0 : 9'h0;       //syscall

/*-------------------------------------------------------*/

/*----------------------deliver ws_to_ds_bus-----------------*/

reg ws_valid;    

wire ws_we;
assign ws_we = ws_gr_we && ws_valid;
wire [4:0] ws_waddr;
assign ws_waddr = ws_dest;
wire [31:0] ws_wdata;
assign ws_wdata = ws_csr? csr_rvalue : ws_final_result;

assign ws_to_ds_bus[31:0] = ws_wdata;
assign ws_to_ds_bus[36:32] = ws_waddr;
assign ws_to_ds_bus[37:37] = ws_we;
//task12 add
assign ws_to_ds_bus[38:38] = ws_csr_write && ws_valid;
assign ws_to_ds_bus[39:39] = ws_ertn_flush;
assign ws_to_ds_bus[53:40] = ws_csr_num;
assign ws_to_ds_bus[54:54] = ws_csr;

/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
wire ws_ready_go;
assign ws_ready_go = 1'b1;
assign ws_allow_in = (!ws_valid || ws_ready_go);

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
assign debug_wb_rf_wdata = ws_wdata;
/*-------------------------------------------------------*/

endmodule