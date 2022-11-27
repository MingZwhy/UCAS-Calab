`include "width.vh"

module stage4_MEM(
    input clk,
    input reset,
    input ertn_flush,
    input wb_ex,

    input ws_allow_in,
    output ms_allow_in,

    input es_to_ms_valid,
    output ms_to_ws_valid,

    input [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    output [`WIDTH_MS_TO_DS_BUS-1:0] ms_to_ds_bus,
    output                           if_ms_ex,
    
    input        data_sram_data_ok,
    input [31:0] data_sram_rdata
);

/*-----------------------recerive es_to_ms_bus----------------*/

wire [31:0] ms_pc;
wire ms_gr_we;
wire ms_res_from_mem;
wire [4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [1:0] ms_unaligned_addr;
wire [4:0] ms_ld_op;

//task12
wire [13:0] ms_csr_num;
wire [31:0] ms_csr_wmask;
wire        ms_csr_write;
wire        ms_ertn_flush;
wire        ms_csr;
wire [31:0] ms_csr_wvalue;
wire        ms_ex_syscall;
wire [14:0] ms_code;
wire        ms_ex_INE;
wire        ms_ex_ADEF;
wire        ms_ex_ALE;
wire        ms_ex_break;
wire        ms_has_int;
wire [31:0] ms_vaddr;
wire        ms_mem_we;

//tlb add
wire        ms_inst_tlbsrch;
wire        ms_inst_tlbrd;
wire        ms_inst_tlbwr;
wire        ms_inst_tlbfill;
wire        ms_inst_invtlb;

wire        ms_s1_found;
wire [3:0]  ms_s1_index;

wire [4:0]  ms_inst_invtlb_op;

reg [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            es_to_ms_bus_reg <= 0;
        else if(ertn_flush || wb_ex)
            es_to_ms_bus_reg <= 0;
        else if(es_to_ms_valid && ms_allow_in)
            es_to_ms_bus_reg <= es_to_ms_bus;
    end 

assign {ms_inst_invtlb_op,ms_s1_index, ms_s1_found, ms_inst_invtlb, ms_inst_tlbfill, ms_inst_tlbwr, ms_inst_tlbrd, ms_inst_tlbsrch,
        ms_mem_we, ms_vaddr, ms_has_int, ms_ex_break, ms_ex_ALE, ms_ex_ADEF, ms_ex_INE,
        ms_code, ms_ex_syscall, ms_csr_wvalue, ms_csr, ms_ertn_flush, ms_csr_write, ms_csr_wmask, ms_csr_num,
        ms_ld_op, ms_unaligned_addr, ms_alu_result, ms_dest,
        ms_res_from_mem, ms_gr_we, ms_pc} = es_to_ms_bus_reg;

/*-------------------------------------------------------*/

/*----------------------deliver es_to_ws_bus-----------------*/
wire [31:0] mem_result;
wire [7:0] mem_byte;
wire [15:0] mem_word;
/* ld_op = (one hot)
* 5'b00001 ld_w
* 5'b00010 ld_b
* 5'b00100 ld_bu
* 5'b01000 ld_h
* 5'b10000 ld_hu
*/
assign mem_byte = (ms_unaligned_addr==2'b00) ? data_sram_rdata[7:0] :
                  (ms_unaligned_addr==2'b01) ? data_sram_rdata[15:8] : 
                  (ms_unaligned_addr==2'b10) ? data_sram_rdata[23:16] :
                  (ms_unaligned_addr==2'b11) ? data_sram_rdata[31:24] : 8'b0;

assign mem_word = ms_unaligned_addr[1] ? data_sram_rdata[31:16] : data_sram_rdata[15:0];

assign mem_result = ms_ld_op[0] ? data_sram_rdata : 
                    ms_ld_op[1] ? {{24{mem_byte[7]}},mem_byte} :
                    ms_ld_op[2] ? {24'b0,mem_byte} : 
                    ms_ld_op[3] ? {{16{mem_word[15]}},mem_word} :
                    ms_ld_op[4] ? {16'b0,mem_word} : 32'b0;

wire [31:0] ms_final_result;
assign ms_final_result = ms_res_from_mem? mem_result : ms_alu_result;

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
assign ms_to_ws_bus[167:167] = ms_ex_INE;
assign ms_to_ws_bus[168:168] = ms_ex_ADEF;
assign ms_to_ws_bus[169:169] = ms_ex_ALE;
assign ms_to_ws_bus[170:170] = ms_ex_break;
assign ms_to_ws_bus[171:171] = ms_has_int;
assign ms_to_ws_bus[203:172] = ms_vaddr;

//tlb add
assign ms_to_ws_bus[204:204] = ms_inst_tlbsrch;
assign ms_to_ws_bus[205:205] = ms_inst_tlbrd;
assign ms_to_ws_bus[206:206] = ms_inst_tlbwr;
assign ms_to_ws_bus[207:207] = ms_inst_tlbfill;
assign ms_to_ws_bus[208:208] = ms_inst_invtlb;

assign ms_to_ws_bus[209:209] = ms_s1_found;    //tlbsrch got
assign ms_to_ws_bus[213:210] = ms_s1_index;    //tlbsrch index

assign ms_to_ws_bus[218:214] = ms_inst_invtlb_op;
/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
reg ms_valid;    

wire ms_ready_go;

assign ms_ready_go = if_ms_ex ? 1'b1 : (ms_mem_we || ms_res_from_mem) ? data_sram_data_ok : 1'b1;
assign ms_allow_in = !ms_valid || ms_ready_go && ws_allow_in;
/*
add conditions & ~ertn_flush & ~wb_ex
because we can't use ertn_flush , wb_ex to clear ms_to_ws_bus_reg directly
like the way we clear ds_to_es, es_to_ms bus_reg
so we use another way to clear data from ms to ws
make ms_to_ws_valid signal down when ertn_flush or wb_ex
this will not influence fs, ds, es, ms 's signal including valid or allow_in
so will not influence assembly line except for ws 
when ms_to_ws_valid down, ws will not receive bus_reg
and when ertn_flush / wb_ex disappear in next clk, 
ms_to_ws_valid will raise again 
*/
assign ms_to_ws_valid = (ms_valid && ms_ready_go) & ~ertn_flush & ~wb_ex;

always @(posedge clk)
    begin
        if(reset)
            ms_valid <= 1'b0;
        else if(ms_allow_in)
            ms_valid <= es_to_ms_valid;
    end

/*-------------------------------------------------------*/

/*--------------------deliver ms_to_ds_bus-------------------*/
//task12 add ms_csr_write, ms_csr_num

wire if_ms_load;
assign if_ms_load = ms_res_from_mem;
assign ms_to_ds_bus = {ms_to_ws_valid,ms_valid,ms_gr_we,ms_dest,if_ms_load,ms_final_result,
                       ms_csr_write, ms_csr_num, ms_csr};
/*-------------------------------------------------------*/

/*--------------------deliver if_ms_ex to es------------------*/
//this signal is for helping ex_stage to judge if it should cancel inst_store due to exception
// in task 12 we just consider syscall
assign if_ms_ex = ms_ex_syscall || ms_ertn_flush || ms_ex_ADEF || ms_ex_INE || ms_ex_ALE || ms_ex_break || ms_has_int;

/*-------------------------------------------------------*/

endmodule