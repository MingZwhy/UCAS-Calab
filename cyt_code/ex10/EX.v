`define WIDTH_BR_BUS       34
`define WIDTH_FS_TO_DS_BUS 64
`define WIDTH_DS_TO_ES_BUS 153
`define WIDTH_ES_TO_MS_BUS 71
`define WIDTH_MS_TO_WS_BUS 70
`define WIDTH_WS_TO_DS_BUS 38
`define WIDTH_ES_TO_DS_BUS 39
`define WIDTH_MS_TO_DS_BUS 38

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

/*-----------------------鎺ユ敹ds_to_es_bus----------------*/
/*
assign ds_to_es_bus[31:   0] = ds_pc;        
assign ds_to_es_bus[63:  32] = rj_value;  
assign ds_to_es_bus[95:  64] = rkd_value; 
assign ds_to_es_bus[127: 96] = imm;       
assign ds_to_es_bus[132:128] = dest;      
assign ds_to_es_bus[133:133] = gr_we;     
assign ds_to_es_bus[134:134] = mem_we;    
assign ds_to_es_bus[146:135] = alu_op;    
assign ds_to_es_bus[147:147] = src1_is_pc;   
assign ds_to_es_bus[148:148] = src2_is_imm;  
assign ds_to_es_bus[149:149] = res_from_mem; 
*/
wire [31:0] es_pc;
wire [31:0] es_rj_value;
wire [31:0] es_rkd_value;
wire [31:0] es_imm;
wire [4:0]  es_dest;
wire        es_gr_we;
wire        es_mem_we;
wire [14:0] es_alu_op;
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

/*-----------------------deliver es_to_ms_bus----------------*/

wire [31:0] es_alu_result;

assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_alu_result;

/*-------------------------------------------------------*/

/*-------------------------link alu---------------------*/

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
reg es_valid;   

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

/*----------------------link data_sram------------------*/
assign data_sram_en    = 1'b1;   //allowing reading data_sram
assign data_sram_wen   = (es_mem_we && es_valid) ? 4'b1111 : 4'b0000;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rkd_value;        //st_w --> write rd_value into data_sram
/*--------------------------------------------------------*/

/*-----------------------deliver es_to_ds_bus----------------*/
wire IF_LOAD;   //if inst is load --> which means forward needs block for one clk
assign IF_LOAD = es_res_from_mem;
assign es_to_ds_bus = {es_gr_we,es_dest,IF_LOAD,es_alu_result};

/*-------------------------------------------------------*/

endmodule