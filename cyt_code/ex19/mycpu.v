`include "width.vh"
/*
`include "stage1_IF.v"
`include "stage2_ID.v"
`include "stage3_EX.v"
`include "stage4_MEM.v"
`include "stage5_WB.v"
*/

module mycpu(
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
wire [31:0]               ex_tlbentry;

wire                      csr_we;
wire [31:0]               csr_wvalue;
wire [31:0]               csr_wmask;

wire                      wb_ex;
wire [31:0]               wb_pc; 
wire                      ertn_flush;
wire [5:0]                wb_ecode;
wire [8:0]                wb_esubcode;
wire [31:0]               wb_vaddr;
wire                      if_fetch_plv_ex;
wire                      if_fetch_tlb_refill;
wire [31:0]               coreid_in;

wire                      has_int;
wire [7:0]                hw_int_in = 8'b0;
wire                      ipi_int_in = 1'b0;

/*--------------------------tlb self----------------------------------*/
wire [18:0]                  s0_vppn;
wire                         s0_va_bit12;        
wire [9:0]                   s0_asid;
wire                         s0_found;
wire [3:0]                   s0_index;
wire [19:0]                  s0_ppn;
wire [5:0]                   s0_ps;
wire [1:0]                   s0_plv;
wire [1:0]                   s0_mat;
wire                         s0_d;
wire                         s0_v;

// search port 1 (for load/store)
wire [18:0]                  s1_vppn;
wire                         s1_va_bit12;      
wire [9:0]                   s1_asid;
wire                         s1_found;
wire [3:0]                   s1_index;
wire [19:0]                  s1_ppn;
wire [5:0]                   s1_ps;
wire [1:0]                   s1_plv;
wire [1:0]                   s1_mat;
wire                         s1_d;
wire                         s1_v;

// invtlb opcode
wire                         invtlb_valid;
wire [4:0]                   invtlb_op;

// write port
wire                         we;  //w(rite) e(nable)
wire [3:0]                   w_index;
wire                         w_e;
wire [18:0]                  w_vppn;
wire [5:0]                   w_ps;
wire [9:0]                   w_asid;
wire                         w_g;

wire [19:0]                  w_ppn0;
wire [1:0]                   w_plv0;
wire [1:0]                   w_mat0;
wire                         w_d0;
wire                         w_v0;

wire [19:0]                  w_ppn1;
wire [1:0]                   w_plv1;
wire [1:0]                   w_mat1;
wire                         w_d1;
wire                         w_v1;

//read port
wire [3:0]                   r_index;
wire                         r_e;
wire [18:0]                  r_vppn;
wire [5:0]                   r_ps;
wire [9:0]                   r_asid;
wire                         r_g;

wire [19:0]                  r_ppn0;
wire [1:0]                   r_plv0;
wire [1:0]                   r_mat0;
wire                         r_d0;
wire                         r_v0;

wire [19:0]                  r_ppn1;
wire [1:0]                   r_plv1;
wire [1:0]                   r_mat1;
wire                         r_d1;
wire                         r_v1;


/*--------------------------------------------------------------------*/

/*-------------------------read_write port----------------------------*/

//1:TLBIDX
wire [3:0]  tlbidx_index;
wire [5:0]  tlbidx_ps;
wire        tlbidx_ne;

//2:TLBEHI
wire [18:0] tlbehi_vppn;

//3:TLBELO0
wire        tlbelo0_v;
wire        tlbelo0_d;
wire [1:0]  tlbelo0_plv;
wire [1:0]  tlbelo0_mat;
wire        tlbelo0_g;
wire [19:0] tlbelo0_ppn;

//4:TLBELO1
wire        tlbelo1_v;
wire        tlbelo1_d;
wire [1:0]  tlbelo1_plv;
wire [1:0]  tlbelo1_mat;
wire        tlbelo1_g;
wire [19:0] tlbelo1_ppn;

//5:ASID
wire [9:0]  tlbasid_asid;

//6:DMW
wire        tlbdmw0_plv0;
wire        tlbdmw0_plv3;
wire [1:0]  tlbdmw0_mat;
wire [2:0]  tlbdmw0_pseg;
wire [2:0]  tlbdmw0_vseg;

wire        tlbdmw1_plv0;
wire        tlbdmw1_plv3;
wire [1:0]  tlbdmw1_mat;
wire [2:0]  tlbdmw1_pseg;
wire [2:0]  tlbdmw1_vseg;

//crmd
wire [1:0] crmd_plv;
wire crmd_da;
wire crmd_pg;
wire [1:0] crmd_datf;
wire [1:0] crmd_datm;

/*--------------------------------------------------------------------*/

/*-----------------------------guchaoyang----------------------------*/
wire [5:0] stat_ecode;
/*--------------------------------------------------------------------*/

/*-------------------------for specific inst--------------------------*/

//for tlbsrch
wire inst_tlbsrch;
wire tlbsrch_got;
wire [3:0] tlbsrch_index;

//for tlbrd
wire inst_tlbrd;         
wire tlbrd_valid;  

wire [18:0] tlbrd_tlbehi_vppn;

wire [19:0] tlbrd_tlbelo0_ppn;
wire        tlbrd_tlbelo0_g;
wire [1:0]  tlbrd_tlbelo0_mat;
wire [1:0]  tlbrd_tlbelo0_plv;
wire        tlbrd_tlbelo0_d;
wire        tlbrd_tlbelo0_v;

wire [19:0] tlbrd_tlbelo1_ppn;
wire        tlbrd_tlbelo1_g;
wire [1:0]  tlbrd_tlbelo1_mat;
wire [1:0]  tlbrd_tlbelo1_plv;
wire        tlbrd_tlbelo1_d;
wire        tlbrd_tlbelo1_v;

wire [5:0]  tlbrd_tlbidx_ps;
wire [9:0]  tlbrd_asid_asid;


/*--------------------------------------------------------------------*/

/*-------------------------for deal with crush--------------------------*/

wire if_ms_crush_with_tlbsrch;
wire if_ws_crush_with_tlbsrch;

wire tlb_zombie;

wire tlb_reflush;
wire [31:0] tlb_reflush_pc;

wire ex_tlb_refill;

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


/*---------------------------FETCH--------------------------*/

stage1_IF fetch(
    .clk                (clk),
    .reset              (reset),
    .ertn_flush         (ertn_flush),
    .ertn_pc            (ertn_pc),
    .ex_entry           (ex_entry),
    .ex_tlbentry        (ex_tlbentry),
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
    .inst_sram_rdata    (inst_sram_rdata),

    .tlb_zombie         (tlb_zombie),
    .tlb_reflush        (tlb_reflush),
    .tlb_reflush_pc     (tlb_reflush_pc),

    .crmd_da            (crmd_da),
    .crmd_pg            (crmd_pg),
    .crmd_datf          (crmd_datf),
    .crmd_datm          (crmd_datm),

    .plv                (crmd_plv),
    .datf               (crmd_datf),

    .DMW0_PLV0          (tlbdmw0_plv0),
    .DMW0_PLV3          (tlbdmw0_plv3),
    .DMW0_MAT           (tlbdmw0_mat),
    .DMW0_PSEG          (tlbdmw0_pseg),
    .DMW0_VSEG          (tlbdmw0_vseg),

    .DMW1_PLV0          (tlbdmw1_plv0),
    .DMW1_PLV3          (tlbdmw1_plv3),
    .DMW1_MAT           (tlbdmw1_mat),
    .DMW1_PSEG          (tlbdmw1_pseg),
    .DMW1_VSEG          (tlbdmw1_vseg),

    .tlbasid_asid       (tlbasid_asid),
    .s0_vppn            (s0_vppn),
    .s0_va_bit12        (s0_va_bit12),
    .s0_asid            (s0_asid),
    .s0_found           (s0_found),
    .s0_ppn             (s0_ppn),
    .s0_plv             (s0_plv),
    .s0_v               (s0_v),

    .in_ex_tlb_refill  (ex_tlb_refill)
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

    .data_sram_data_ok  (data_sram_data_ok),

    .tlb_zombie         (tlb_zombie),
    .tlb_reflush        (tlb_reflush)
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
    .if_ms_ex           (if_ms_ex),

    .data_sram_req      (data_sram_req),
    .data_sram_wr       (data_sram_wr),
    .data_sram_size     (data_sram_size),
    .data_sram_wstrb    (data_sram_wstrb),
    .data_sram_addr     (data_sram_addr),
    .data_sram_wdata    (data_sram_wdata),

    .data_sram_addr_ok  (data_sram_addr_ok),
    .data_sram_data_ok  (data_sram_data_ok),

    .global_time_cnt    (global_time_cnt),

    //port with tlb.v
    .s1_vppn            (s1_vppn),
    .s1_va_bit12        (s1_va_bit12),
    .s1_asid            (s1_asid),

    .s1_found           (s1_found),
    .s1_index           (s1_index),

    //for tlbsrch
    .tlbehi_vppn        (tlbehi_vppn),
    .tlbasid_asid       (tlbasid_asid),

    //for tlb crush
    .if_ms_crush_with_tlbsrch (if_ms_crush_with_tlbsrch),
    .if_ws_crush_with_tlbsrch (if_ws_crush_with_tlbsrch),
    .tlb_reflush        (tlb_reflush),

    .crmd_da            (crmd_da),
    .crmd_pg            (crmd_pg),

    .plv                (crmd_plv),
    .datm               (crmd_datm),

    .DMW0_PLV0          (tlbdmw0_plv0),
    .DMW0_PLV3          (tlbdmw0_plv3),
    .DMW0_MAT           (tlbdmw0_mat),
    .DMW0_PSEG          (tlbdmw0_pseg),
    .DMW0_VSEG          (tlbdmw0_vseg),

    .DMW1_PLV0          (tlbdmw1_plv0),
    .DMW1_PLV3          (tlbdmw1_plv3),
    .DMW1_MAT           (tlbdmw1_mat),
    .DMW1_PSEG          (tlbdmw1_pseg),
    .DMW1_VSEG          (tlbdmw1_vseg),

    .s1_ppn             (s1_ppn),
    .s1_plv             (s1_plv),
    .s1_d               (s1_d),
    .s1_v               (s1_v),

    .invtlb_op          (invtlb_op),
    .invtlb_valid       (invtlb_valid)
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
    .data_sram_rdata    (data_sram_rdata),

    //tlb crush
    .if_ms_crush_with_tlbsrch (if_ms_crush_with_tlbsrch),

    .tlb_reflush        (tlb_reflush)
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
    .wb_vaddr           (wb_vaddr),
    .if_fetch_plv_ex    (if_fetch_plv_ex),
    .if_fetch_tlb_refill(if_fetch_tlb_refill),

    .inst_tlbsrch       (inst_tlbsrch),
    .tlbsrch_got        (tlbsrch_got),
    .tlbsrch_index      (tlbsrch_index),

    .tlbidx_index       (tlbidx_index),
    .inst_tlbrd         (inst_tlbrd),
    .tlbrd_valid        (tlbrd_valid), 

    .tlbasid_asid       (tlbasid_asid),
    .tlbidx_ps          (tlbidx_ps),
    .tlbidx_ne          (tlbidx_ne),

    .tlbehi_vppn        (tlbehi_vppn),
    .tlbrd_tlbehi_vppn  (tlbrd_tlbehi_vppn),

    .tlbelo0_v          (tlbelo0_v),
    .tlbelo0_d          (tlbelo0_d),
    .tlbelo0_plv        (tlbelo0_plv),
    .tlbelo0_mat        (tlbelo0_mat),
    .tlbelo0_g          (tlbelo0_g),
    .tlbelo0_ppn        (tlbelo0_ppn),

    .tlbelo1_v          (tlbelo1_v),
    .tlbelo1_d          (tlbelo1_d),
    .tlbelo1_plv        (tlbelo1_plv),
    .tlbelo1_mat        (tlbelo1_mat),
    .tlbelo1_g          (tlbelo1_g),
    .tlbelo1_ppn        (tlbelo1_ppn),

    .we                 (we),
    .w_index            (w_index),
    .w_e                (w_e),
    .w_vppn             (w_vppn),
    .w_ps               (w_ps),
    .w_asid             (w_asid),
    .w_g                (w_g),

    .w_ppn0             (w_ppn0),
    .w_plv0             (w_plv0),
    .w_mat0             (w_mat0),
    .w_d0               (w_d0),
    .w_v0               (w_v0),

    .w_ppn1             (w_ppn1),
    .w_plv1             (w_plv1),
    .w_mat1             (w_mat1),
    .w_d1               (w_d1),
    .w_v1               (w_v1),

    .r_index            (r_index),
    .r_e                (r_e),
    .r_vppn             (r_vppn),
    .r_ps               (r_ps),
    .r_asid             (r_asid),
    .r_g                (r_g),

    .r_ppn0             (r_ppn0),
    .r_plv0             (r_plv0),
    .r_mat0             (r_mat0),
    .r_d0               (r_d0),
    .r_v0               (r_v0),

    .r_ppn1             (r_ppn1),
    .r_plv1             (r_plv1),
    .r_mat1             (r_plv1),
    .r_d1               (r_d1),
    .r_v1               (r_v1),

    .tlbrd_tlbelo0_ppn  (tlbrd_tlbelo0_ppn),
    .tlbrd_tlbelo0_g    (tlbrd_tlbelo0_g),
    .tlbrd_tlbelo0_mat  (tlbrd_tlbelo0_mat),
    .tlbrd_tlbelo0_plv  (tlbrd_tlbelo0_plv),
    .tlbrd_tlbelo0_d    (tlbrd_tlbelo0_d),
    .tlbrd_tlbelo0_v    (tlbrd_tlbelo0_v),

    .tlbrd_tlbelo1_ppn  (tlbrd_tlbelo1_ppn),
    .tlbrd_tlbelo1_g    (tlbrd_tlbelo1_g),
    .tlbrd_tlbelo1_mat  (tlbrd_tlbelo1_mat),
    .tlbrd_tlbelo1_plv  (tlbrd_tlbelo1_plv),
    .tlbrd_tlbelo1_d    (tlbrd_tlbelo1_d),
    .tlbrd_tlbelo1_v    (tlbrd_tlbelo1_v),

    .tlbrd_tlbidx_ps    (tlbrd_tlbidx_ps),
    .tlbrd_asid_asid    (tlbrd_asid_asid),

    .tlb_reflush        (tlb_reflush),
    .tlb_reflush_pc     (tlb_reflush_pc),

    .out_ex_tlb_refill  (ex_tlb_refill),
    .stat_ecode         (stat_ecode),

    //crush with tlbsrch
    .if_ws_crush_with_tlbsrch   (if_ws_crush_with_tlbsrch)
);

/*----------------------------------------------------------*/

/*---------------------------csr_reg--------------------------*/
csr_reg cr(
    .clk                (clk),
    .reset              (reset),

    .csr_num            (csr_num),
    
    .csr_re             (csr_re),
    .csr_rvalue         (csr_rvalue),
    .ertn_pc            (ertn_pc),
    .ex_entry           (ex_entry),
    .ex_tlbentry        (ex_tlbentry),

    .csr_we             (csr_we),
    .csr_wmask          (csr_wmask),
    .csr_wvalue         (csr_wvalue),

    .wb_ex              (wb_ex),
    .wb_pc              (wb_pc),
    .ertn_flush         (ertn_flush),
    .wb_ecode           (wb_ecode),
    .wb_esubcode        (wb_esubcode), 
    .wb_vaddr           (wb_vaddr),
    .if_fetch_plv_ex    (if_fetch_plv_ex),
    .if_fetch_tlb_refill(if_fetch_tlb_refill),
    .coreid_in          (coreid_in),

    .has_int            (has_int),
    .hw_int_in          (hw_int_in),
    .ipi_int_in         (ipi_int_in),

    //1:TLBIDX
    .tlbidx_index       (tlbidx_index),
    .tlbidx_ps          (tlbidx_ps),
    .tlbidx_ne          (tlbidx_ne),

    //2:TLBEHI
    .tlbehi_vppn        (tlbehi_vppn),

    .tlbelo0_v          (tlbelo0_v),
    .tlbelo0_d          (tlbelo0_d),
    .tlbelo0_plv        (tlbelo0_plv),
    .tlbelo0_mat        (tlbelo0_mat),
    .tlbelo0_g          (tlbelo0_g),
    .tlbelo0_ppn        (tlbelo0_ppn),

    .tlbelo1_v          (tlbelo1_v),
    .tlbelo1_d          (tlbelo1_d),
    .tlbelo1_plv        (tlbelo1_plv),
    .tlbelo1_mat        (tlbelo1_mat),
    .tlbelo1_g          (tlbelo1_g),
    .tlbelo1_ppn        (tlbelo1_ppn),


    //5:ASID
    .tlbasid_asid       (tlbasid_asid),

    //for tlbsrch
    .inst_tlbsrch       (inst_tlbsrch),
    .tlbsrch_got        (tlbsrch_got),
    .tlbsrch_index      (tlbsrch_index),

    //for tlbrd
    .inst_tlbrd         (inst_tlbrd),
    .tlbrd_valid        (tlbrd_valid),

    .tlbrd_tlbehi_vppn  (tlbrd_tlbehi_vppn),

    .tlbrd_tlbelo0_ppn  (tlbrd_tlbelo0_ppn),
    .tlbrd_tlbelo0_g    (tlbrd_tlbelo0_g),
    .tlbrd_tlbelo0_mat  (tlbrd_tlbelo0_mat),
    .tlbrd_tlbelo0_plv  (tlbrd_tlbelo0_plv),
    .tlbrd_tlbelo0_d    (tlbrd_tlbelo0_d),
    .tlbrd_tlbelo0_v    (tlbrd_tlbelo0_v),

    .tlbrd_tlbelo1_ppn  (tlbrd_tlbelo1_ppn),
    .tlbrd_tlbelo1_g    (tlbrd_tlbelo1_g),
    .tlbrd_tlbelo1_mat  (tlbrd_tlbelo1_mat),
    .tlbrd_tlbelo1_plv  (tlbrd_tlbelo1_plv),
    .tlbrd_tlbelo1_d    (tlbrd_tlbelo1_d),
    .tlbrd_tlbelo1_v    (tlbrd_tlbelo1_v),

    .tlbrd_tlbidx_ps    (tlbrd_tlbidx_ps),
    .tlbrd_asid_asid    (tlbrd_asid_asid),

    .ex_tlb_refill      (ex_tlb_refill),

    .crmd_plv           (crmd_plv),
    .crmd_da            (crmd_da),
    .crmd_pg            (crmd_pg),
    .crmd_datf          (crmd_datf),
    .crmd_datm          (crmd_datm),

    .tlbdmw0_plv0       (tlbdmw0_plv0),
    .tlbdmw0_plv3       (tlbdmw0_plv3),
    .tlbdmw0_mat        (tlbdmw0_mat),
    .tlbdmw0_pseg       (tlbdmw0_pseg),
    .tlbdmw0_vseg       (tlbdmw0_vseg),

    .tlbdmw1_plv0       (tlbdmw1_plv0),
    .tlbdmw1_plv3       (tlbdmw1_plv3),
    .tlbdmw1_mat        (tlbdmw1_mat),
    .tlbdmw1_pseg       (tlbdmw1_pseg),
    .tlbdmw1_vseg       (tlbdmw1_vseg),

    .stat_ecode         (stat_ecode)
);

tlb my_tlb(
    .clk                    (clk),
    .s0_vppn                (s0_vppn),
    .s0_va_bit12            (s0_va_bit12),
    .s0_asid                (s0_asid),
    .s0_found               (s0_found),
    .s0_index               (s0_index),
    .s0_ppn                 (s0_ppn),
    .s0_ps                  (s0_ps),
    .s0_plv                 (s0_plv),
    .s0_mat                 (s0_mat),
    .s0_d                   (s0_d),
    .s0_v                   (s0_v),

    .s1_vppn                (s1_vppn),
    .s1_va_bit12            (s1_va_bit12),
    .s1_asid                (s1_asid),
    .s1_found               (s1_found),
    .s1_index               (s1_index),
    .s1_ppn                 (s1_ppn),
    .s1_ps                  (s1_ps),
    .s1_plv                 (s1_plv),
    .s1_mat                 (s1_mat),
    .s1_d                   (s1_d),
    .s1_v                   (s1_v),

    .invtlb_valid           (invtlb_valid),
    .invtlb_op              (invtlb_op),

    .we                     (we),
    .w_index                (w_index),
    .w_e                    (w_e),
    .w_vppn                 (w_vppn),
    .w_ps                   (w_ps),
    .w_asid                 (w_asid),
    .w_g                    (w_g),
    
    .w_ppn0                 (w_ppn0),
    .w_plv0                 (w_plv0),
    .w_mat0                 (w_mat0),
    .w_d0                   (w_d0),
    .w_v0                   (w_v0),

    .w_ppn1                 (w_ppn1),
    .w_plv1                 (w_plv1),
    .w_mat1                 (w_mat1),
    .w_d1                   (w_d1),
    .w_v1                   (w_v1),

    .r_index                (r_index),
    .r_e                    (r_e),
    .r_vppn                 (r_vppn),
    .r_ps                   (r_ps),
    .r_asid                 (r_asid),
    .r_g                    (r_g),

    .r_ppn0                 (r_ppn0),
    .r_plv0                 (r_plv0),
    .r_mat0                 (r_mat0),
    .r_d0                   (r_d0),
    .r_v0                   (r_v0),

    .r_ppn1                 (r_ppn1),
    .r_plv1                 (r_plv1),
    .r_mat1                 (r_plv1),
    .r_d1                   (r_d1),
    .r_v1                   (r_v1)
);

/*------------------------------------------------------------*/

endmodule