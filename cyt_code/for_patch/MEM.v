`define WIDTH_BR_BUS       34
`define WIDTH_FS_TO_DS_BUS 64
`define WIDTH_DS_TO_ES_BUS 164
`define WIDTH_ES_TO_MS_BUS 78
`define WIDTH_MS_TO_WS_BUS 70
`define WIDTH_WS_TO_DS_BUS 38
`define WIDTH_ES_TO_DS_BUS 39
`define WIDTH_MS_TO_DS_BUS 38

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

/*-----------------------recerive es_to_ms_bus----------------*/
/*
assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_calcu_result;
assign es_to_ms_bus[72:71] = es_unaligned_addr;
assign es_to_ms_bus[77:73] = es_ld_op;
*/

wire [31:0] ms_pc;
wire ms_gr_we;
wire ms_res_from_mem;
wire [4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [1:0] ms_unaligned_addr;
wire [4:0] ms_ld_op;

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

assign {ms_ld_op, ms_unaligned_addr, ms_alu_result, ms_dest,
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
/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
reg ms_valid;    

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

/*--------------------鍙戯拷?锟絤s_to_ds_bus-------------------*/
assign ms_to_ds_bus = {ms_gr_we,ms_dest,ms_final_result};
/*-------------------------------------------------------*/

endmodule