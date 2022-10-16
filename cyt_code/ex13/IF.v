`include "width.vh"

module stage1_IF(
    input clk,
    input reset,
    input ertn_flush,
    input has_int,
    input wb_ex,
    input [31:0] ertn_pc,
    input [31:0] ex_entry,

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

/*--------------------------------valid-----------------------------*/

reg fs_valid;    

//��fs_valid��˵��ֻҪȡ��reset���൱ȥǰһ�׶ζ���������valid�ź�
wire pre_if_to_fs_valid;
assign pre_if_to_fs_valid = !reset;

wire fs_ready_go;

always @(posedge clk)
    begin
        if(reset)
            fs_valid <= 1'b0;
        else if(fs_allow_in)
            fs_valid <= pre_if_to_fs_valid;
        /*
        else if(br_taken_cancel)
            fs_valid <= 1'b0;
        */
    end

//��output-fs_to_ds_valid��reg fs_valid����
//���ǵ��������һ��clk��ɲ���FETCH��raise fs_ready_go
assign fs_ready_go = 1'b1;
wire fs_allow_in;
assign fs_allow_in = !fs_valid || fs_ready_go && ds_allow_in;
assign fs_to_ds_valid = fs_valid && fs_ready_go;

/*----------------------------------------------------------------*/

/*--------------------------------pc------------------------------*/

wire [31:0] br_target;  //��ת��ַ
wire br_taken;          //�Ƿ���ת
wire br_taken_cancel;
//br_taken��br_target����br_bus
assign {br_taken_cancel,br_taken,br_target} = br_bus;

reg [31:0] fetch_pc; 

wire [31:0] seq_pc;     //˳��ȡַ
assign seq_pc = fetch_pc + 4;
wire [31:0] next_pc;    //nextpc����seq��br
assign next_pc = (has_int || wb_ex)? ex_entry : ertn_flush? ertn_pc : br_taken? br_target : seq_pc;
   
always @(posedge clk)
    begin
        if(reset)
            fetch_pc <= 32'h1BFFFFFC;
        else if(pre_if_to_fs_valid && fs_allow_in)
            fetch_pc <= next_pc;
    end

/*----------------------------------------------------------------*/

/*----------------------------Link to inst_ram---------------------*/

/*
    output inst_sram_en,                
    output [3:0] inst_sram_wen,         
    output [31:0] inst_sram_addr,       
    output [31:0] inst_sram_wdata,      
    input [31:0] inst_sram_rdata       
*/

assign inst_sram_en = pre_if_to_fs_valid && ds_allow_in;
assign inst_sram_wen = 4'b0;    //fetch�׶β�д
assign inst_sram_addr = next_pc;
assign inst_sram_wdata = 32'b0;

/*----------------------------------------------------------------*/

/*----------------------------deliver fs_to_ds_bus------------------------*/
wire [31:0] fetch_inst;
assign fetch_inst = inst_sram_rdata;

//task13 add ADEF fetch_addr_exception
wire fs_ex_ADEF;
//fs_ex_ADEF happen when inst_sram_en and last 2 bits of inst_sram_addr are not 2'b00
assign fs_ex_ADEF = inst_sram_en && (fetch_pc[1] | fetch_pc[0]);  //last two bit != 0 <==> error address

assign fs_to_ds_bus = {fs_ex_ADEF, fetch_inst, fetch_pc};

/*----------------------------------------------------------------*/

endmodule