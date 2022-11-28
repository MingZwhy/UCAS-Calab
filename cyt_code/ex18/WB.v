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
    output [8:0]                wb_esubcode,
    output [31:0]               wb_vaddr,

    //tlbsrch
    output                      inst_tlbsrch,
    output                      tlbsrch_got,
    output [3:0]                tlbsrch_index,

    //tlbrd
    input [3:0]                 tlbidx_index,     //from csr
    output                      inst_tlbrd,
    output                      tlbrd_valid,

    //tlbwr
    input  [9:0]                tlbasid_asid,

    //input  [3:0]                tlbidx_index,
    input  [5:0]                tlbidx_ps,
    input                       tlbidx_ne,

    input  [18:0]               tlbehi_vppn,
    output [18:0]               tlbrd_tlbehi_vppn,

    input                       tlbelo0_v,
    input                       tlbelo0_d,
    input  [1:0]                tlbelo0_plv,
    input  [1:0]                tlbelo0_mat,
    input                       tlbelo0_g,
    input  [19:0]               tlbelo0_ppn,

    input                       tlbelo1_v,
    input                       tlbelo1_d,
    input  [1:0]                tlbelo1_plv,
    input  [1:0]                tlbelo1_mat,
    input                       tlbelo1_g,
    input  [19:0]               tlbelo1_ppn,

    output                      we,
    output [3:0]                w_index,
    output                      w_e,
    output [18:0]               w_vppn,
    output [5:0]                w_ps,
    output [9:0]                w_asid,
    output                      w_g,

    output [19:0]               w_ppn0,
    output [1:0]                w_plv0,
    output [1:0]                w_mat0,
    output                      w_d0,
    output                      w_v0,

    output [19:0]               w_ppn1,
    output [1:0]                w_plv1,
    output [1:0]                w_mat1,
    output                      w_d1,
    output                      w_v1,
    
    output [3:0]                r_index,
    input                       r_e,
    input  [18:0]               r_vppn,
    input  [5:0]                r_ps,
    input  [9:0]                r_asid,
    input                       r_g,

    input [19:0]                  r_ppn0,
    input [1:0]                   r_plv0,
    input [1:0]                   r_mat0,
    input                         r_d0,
    input                         r_v0,

    input [19:0]                  r_ppn1,
    input [1:0]                   r_plv1,
    input [1:0]                   r_mat1,
    input                         r_d1,
    input                         r_v1,

    //for invtlb
    output [4:0]                invtlb_op,
    output                      invtlb_valid,

    //for tlbrd
    output [19:0]               tlbrd_tlbelo0_ppn,
    output                      tlbrd_tlbelo0_g,
    output [1:0]                tlbrd_tlbelo0_mat,
    output [1:0]                tlbrd_tlbelo0_plv,
    output                      tlbrd_tlbelo0_d,
    output                      tlbrd_tlbelo0_v,

    output [19:0]               tlbrd_tlbelo1_ppn,
    output                      tlbrd_tlbelo1_g,
    output [1:0]                tlbrd_tlbelo1_mat,
    output [1:0]                tlbrd_tlbelo1_plv,
    output                      tlbrd_tlbelo1_d,
    output                      tlbrd_tlbelo1_v,

    output [5:0]                tlbrd_tlbidx_ps,
    output [9:0]                tlbrd_asid_asid,

    //tlb_reflush
    output                      tlb_reflush,
    output [31:0]               tlb_reflush_pc,

    output                      out_ex_tlb_refill,
    input  [5:0]                stat_ecode
);

/*-------------------------------tlb---------------------------*/
//for tlbsrch
assign inst_tlbsrch = ws_inst_tlbsrch;
assign tlbsrch_got = ws_s1_found;
assign tlbsrch_index = ws_s1_index;

//for tlbrd
assign inst_tlbrd = ws_inst_tlbrd;
assign tlbrd_valid = r_e;
assign r_index = tlbidx_index;

//for tlbwr
reg [3:0] random_index;
reg if_keep;

always @(posedge clk)
    begin
        if(reset)
            random_index <= 0;
        else if(ws_inst_tlbfill && ms_to_ws_valid)
            //prepare next random for next tlbfill inst
            random_index <= ( {$random()} % 16 );
    end

assign we = (ws_inst_tlbwr | ws_inst_tlbfill);
assign w_index = ws_inst_invtlb ? tlbsrch_index : ws_inst_tlbwr ? tlbidx_index : random_index;
assign w_e = (stat_ecode != 6'h3f)? ~tlbidx_ne: 1'b1;
assign w_vppn = tlbehi_vppn;
assign w_ps = tlbidx_ps;
assign w_asid = ws_inst_invtlb ? ws_s1_asid : tlbasid_asid;
assign w_g = tlbelo0_g && tlbelo1_g;

assign w_ppn0 = tlbelo0_ppn;
assign w_plv0 = tlbelo0_plv;
assign w_mat0 = tlbelo0_mat;
assign w_d0   = tlbelo0_d;
assign w_v0   = tlbelo0_v;

assign w_ppn1 = tlbelo1_ppn;
assign w_plv1 = tlbelo1_plv;
assign w_mat1 = tlbelo1_mat;
assign w_d1   = tlbelo1_d;
assign w_v1   = tlbelo1_v;

//for tlb_zombie
assign tlb_reflush = ws_tlb_zombie;
assign tlb_reflush_pc = ws_pc;

/*-------------------------------------------------------------*/

/*-----------------------receive ms_to_ws_bus----------------*/

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
wire        ws_ex_INE;
wire        ws_ex_ADEF;
wire        ws_ex_ALE;
wire        ws_ex_break;
wire        ws_has_int;
wire [31:0] ws_vaddr;

//tlb add
wire        ws_inst_tlbsrch;
wire        ws_inst_tlbrd;
wire        ws_inst_tlbwr;
wire        ws_inst_tlbfill;
wire        ws_inst_invtlb;

wire        ws_s1_found;
wire [3:0]  ws_s1_index;

wire [4:0]  ws_inst_invtlb_op;
wire        ws_tlb_zombie;
wire [9:0]  ws_s1_asid;

//tlb exception
wire ws_ex_fetch_tlb_refill;
wire ws_ex_inst_invalid;
wire ws_ex_fetch_plv_invalid;
wire ws_ex_loadstore_tlb_fill;
wire ws_ex_load_invalid;
wire ws_ex_store_invalid;
wire ws_ex_loadstore_plv_invalid;
wire ws_ex_store_dirty;

wire ex_plv_invalid;
assign ex_plv_invalid = ws_ex_fetch_plv_invalid | ws_ex_loadstore_plv_invalid;
wire ex_tlb_refill;
assign ex_tlb_refill = ws_ex_fetch_tlb_refill | ws_ex_loadstore_tlb_fill;

assign out_ex_tlb_refill = ex_tlb_refill;

reg [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ms_to_ws_bus_reg <= 0;
        else if(ms_to_ws_valid && ws_allow_in)
            ms_to_ws_bus_reg <= ms_to_ws_bus;
        else if((wb_ex || ertn_flush || tlb_reflush) && ws_valid)
            ms_to_ws_bus_reg <= 0;
    end 

assign {ws_ex_store_dirty, ws_ex_loadstore_plv_invalid, ws_ex_store_invalid, ws_ex_load_invalid, ws_ex_loadstore_tlb_fill,
        ws_ex_fetch_plv_invalid, ws_ex_inst_invalid, ws_ex_fetch_tlb_refill,
        ws_s1_asid, ws_tlb_zombie,
        ws_inst_invtlb_op, ws_s1_index, ws_s1_found, ws_inst_invtlb, ws_inst_tlbfill, ws_inst_tlbwr, ws_inst_tlbrd, ws_inst_tlbsrch,
        ws_vaddr, ws_has_int, ws_ex_break, ws_ex_ALE, ws_ex_ADEF, ws_ex_INE,
        ws_code, ws_ex_syscall, ws_csr_wvalue, ws_csr, ws_ertn_flush, ws_csr_write, ws_csr_wmask, ws_csr_num,
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

assign wb_ex = ws_ex_syscall || ws_ex_break || ws_ex_ADEF || ws_ex_ALE || ws_ex_INE || ws_has_int
            || ws_ex_fetch_tlb_refill || ws_ex_inst_invalid || ws_ex_fetch_plv_invalid
            || ws_ex_loadstore_tlb_fill || ws_ex_load_invalid || ws_ex_store_invalid
            || ws_ex_loadstore_plv_invalid || ws_ex_store_dirty;

assign wb_pc = ws_pc;
assign wb_vaddr = ws_vaddr;

/*
 *deal with ecode and esubcode according to kind of ex
 *in task12, we just finish syscall
 */
assign wb_ecode = ws_ex_syscall ? 6'hb : ws_ex_break ? 6'hc : 
                  ws_ex_ADEF ? 6'h8 : ws_ex_ALE ? 6'h9 : 
                  ws_ex_INE ? 6'hd : ws_has_int ? 6'h0 : 
                  ws_ex_load_invalid ? 6'h1 :
                  ws_ex_store_invalid ? 6'h2 :
                  ws_ex_inst_invalid ? 6'h3 :
                  ws_ex_store_dirty ? 6'h4 :
                  ex_plv_invalid ? 6'h7 :
                  ex_tlb_refill ? 6'h3f : 6'h0;

assign wb_esubcode = 9'h0;   //up to task13, add ex's esubcode are all 0x0

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

/*-------------------invtlb_op---------------------------*/
assign invtlb_op = (ws_inst_invtlb)?ws_inst_invtlb_op : 5'h0;
assign invtlb_valid = ws_inst_invtlb;
/*-------------------------------------------------------*/

/*--------------Some Others by Gu Chaoyang---------------*/
assign tlbrd_tlbehi_vppn = r_vppn;
assign tlbrd_tlbelo0_ppn = r_ppn0;
assign tlbrd_tlbelo0_g   = r_g;
assign tlbrd_tlbelo0_mat = r_mat0;
assign tlbrd_tlbelo0_plv = r_plv0;
assign tlbrd_tlbelo0_d   = r_d0;
assign tlbrd_tlbelo0_v   = r_v0;

assign tlbrd_tlbelo1_ppn = r_ppn1;
assign tlbrd_tlbelo1_g   = r_g;
assign tlbrd_tlbelo1_mat = r_mat1;
assign tlbrd_tlbelo1_plv = r_plv1;
assign tlbrd_tlbelo1_d   = r_d1;
assign tlbrd_tlbelo1_v   = r_v1;

assign tlbrd_tlbidx_ps   = r_ps;
assign tlbrd_asid_asid   = r_asid;
/*-------------------------------------------------------*/
endmodule