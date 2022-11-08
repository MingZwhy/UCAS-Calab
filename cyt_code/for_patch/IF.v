`include "width.vh"

module stage1_IF(
    input clk,
    input reset,
    input ertn_flush,
    input wb_ex,
    input [31:0] ertn_pc,
    input [31:0] ex_entry,

    input ds_allow_in,
    input [`WIDTH_BR_BUS-1:0] br_bus,
    output fs_to_ds_valid,
    output [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,

    output          inst_sram_req,
    output          inst_sram_wr,
    output [1:0]    inst_sram_size,
    output [3:0]    inst_sram_wstrb,
    output [31:0]   inst_sram_addr,
    output [31:0]   inst_sram_wdata,

    input           inst_sram_addr_ok,
    input           inst_sram_data_ok,
    input  [31:0]   inst_sram_rdata
);

/*--------------------------------valid-----------------------------*/
    
/*
pre_ifα��ˮ������ȡָ����:

hint1: when reset , stop req;
hint2: when br_stall, mean we're calculating for judging whether branch or not,
       so keep not req until we are sure branch or not;
hint3: using a reg inst_sram_req_reg, because we want to make sure that
       turn req to down after shaking_hands (next posedge clk), and 
       turn req to up when data_ok (got inst actually)
hint4: req when fs_allow_in , because we don't want to deal with the situation that
       fs_allow_in is down when (req && addr_ok) --> which is difficult to handle;
*/
assign inst_sram_req = (reset || br_stall) ? 1'b0 : fs_allow_in ? inst_sram_req_reg : 1'b0;

reg inst_sram_req_reg;
always @(posedge clk)
    begin
        if(reset)
            inst_sram_req_reg <= 1'b1;
        else if(inst_sram_req && inst_sram_addr_ok)
            //���ֳɹ��������ֳɹ�����һ��ʱ����������req
            inst_sram_req_reg <= 1'b0;
        else if(inst_sram_data_ok)
            //�����ֽ��յ�����(data_ok)ʱ����������req
            inst_sram_req_reg <= 1'b1;
    end

// ��req��addr_ok���ֳɹ�ʱ�����������ͳɹ�������ready_go
wire pre_if_ready_go;
assign pre_if_ready_go = inst_sram_req & inst_sram_addr_ok;
wire pre_if_to_fs_valid;
assign pre_if_to_fs_valid = !reset & pre_if_ready_go;

wire fs_ready_go;
// ��data_ok����ʱ����������ָ���룬��fs_ready_go����
// ��temp_inst��Чʱ˵��fs_ready_go�Ѿ����ߣ���ds_allow_inû����
// ��˴�ʱ�ڵ�ds_allow_in����Ҫ����temp_inst����
// ͬʱ��deal_with_cancel����ʱ��������Ҫ������һ���յ��Ĵ���ָ�����fs_ready_go����
//assign fs_ready_go = deal_with_cancel ? (inst_sram_data_ok ? 1'b1: 1'b0) : ((temp_inst != 0) || inst_sram_data_ok);
assign fs_ready_go = deal_with_cancel ? 1'b0 : ((temp_inst != 0) || inst_sram_data_ok);

reg fs_valid;
always @(posedge clk)
    begin
        if(reset)
            fs_valid <= 1'b0;
        else if(fs_allow_in)
            begin
                if(wb_ex || ertn_flush)
                    /*��Ӧ2.1�������IF��û����Чָ���
                    ����Чָ���Ҫ����ID�������յ�cancel
                    ����һ��fs_vaild��0*/
                    fs_valid <= 1'b0;
                else
                    fs_valid <= pre_if_to_fs_valid;
            end
        else if(br_taken_cancel)
            fs_valid <= 1'b0;
    end

wire fs_allow_in;
assign fs_allow_in = !fs_valid || (fs_ready_go && ds_allow_in) || (deal_with_cancel && inst_sram_data_ok);
assign fs_to_ds_valid = fs_valid && fs_ready_go;

//��fs_ready_go = 1 �� ds_allow_in = 0 ʱ
//IF���յ���ָ���ID�������ý��룬��Ҫ����һ�鴥����������ȡ����ָ��
//�����鴥��������Ч����ʱ����ѡ����鴥���������������ΪIF��ȡ�ص�ָ������ID��

reg [31:0] temp_inst;

always @(posedge clk)
    begin
        if(reset)
            temp_inst <= 0;
        else if(fs_ready_go)
            begin
                if(wb_ex || ertn_flush)
                    //��cancelʱ��������ָ����0
                    //��Ӧ2.2.1���
                    temp_inst <= 0;
                else if(!ds_allow_in)
                    //�ݴ�ָ��
                    temp_inst <= inst_sram_rdata;
                else
                    //��ds�������ʱ�������ʱ�����ؾ����̽�temp_inst
                    //����ds����ͬʱ��temp_inst���㣬�����ָ��治������Чָ��
                    temp_inst <= 0;
            end
    end

/*Ϊ�˽�������ˮ���е�1.2��2.2.2���
����cancel��IF�������յ��ĵ�һ�����ص�ָ�������ǶԵ�ǰ��cancel��ȡֵָ��ķ���
��˺����յ��ĵ�һ�����ص�ָ��������Ҫ��������������������ID��
��������ǣ�
ά��һ������������λֵΪ0��������1.2��2.2.2ʱ���ô�������1�����յ�data_okʱ����0
���ô�����Ϊ1ʱ����IF����ready_goĨ�㣬����data_ok���ٵ�ʱ�����أ�fs_ready_go
ǡ����Ϊ0�����¸պö�����data��������ָ� */
reg deal_with_cancel;
always @(posedge clk)
    begin
        if(reset)
            deal_with_cancel <= 1'b0;
        else if((wb_ex || ertn_flush) && pre_if_to_fs_valid)
            //pre_if_to_fs_valid ��Ӧ1.2�������pre-if���͵ĵ�ַ���ñ�����
            deal_with_cancel <= 1'b1;
        else if(~fs_allow_in && (wb_ex || ertn_flush) && ~fs_ready_go)
            //~fs_allow_in �� ~fs_ready_go ��Ӧ2.2.2�������IF�����ڵȴ�data_ok
            deal_with_cancel <= 1'b1;
        else if(inst_sram_data_ok)
            deal_with_cancel <= 1'b0;
    end

/*----------------------------------------------------------------*/

/*--------------------------------pc------------------------------*/

wire [31:0] br_target;  //��ת��ַ
wire br_taken;          //�Ƿ���ת
wire br_stall;          
wire br_taken_cancel; 
//br_taken��br_target����br_bus
assign {br_taken_cancel, br_stall, br_taken, br_target} = br_bus;

reg [31:0] fetch_pc; 

wire [31:0] seq_pc;     //˳��ȡַ
assign seq_pc = (fetch_pc + 4);
wire [31:0] next_pc;    //nextpc����seq��br
assign next_pc = if_keep_pc ? br_delay_reg : wb_ex ? ex_entry : ertn_flush? ertn_pc : (br_taken && ~br_stall) ? br_target : seq_pc;

/*
�������쳣���pc���쳣����pc����תpcʱ���źź�pc����ֻ��ά��һ�ģ�
����req�յ�addr_okǰ��Ҫά��ȡַ��ַ����
*/

reg if_keep_pc;
reg [31:0] br_delay_reg;
always @(posedge clk)
    begin
        if(reset)
            if_keep_pc <= 1'b0;
        else if(inst_sram_addr_ok && ~deal_with_cancel && ~wb_ex && ~ertn_flush)
            if_keep_pc <= 1'b0;
        else if((br_taken && ~br_stall) || wb_ex || ertn_flush)
            if_keep_pc <= 1'b1;
    end

always @(posedge clk)
    begin
        if(reset)
            br_delay_reg <= 32'b0;
        else if(wb_ex)
            br_delay_reg <= ex_entry;
        else if(ertn_flush)
            br_delay_reg <= ertn_pc;
        else if(br_taken && ~br_stall)
            br_delay_reg <= br_target;
    end

   
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
    output          inst_sram_req,
    output          inst_sram_wr,
    output [1:0]    inst_sram_size,
    output [3:0]    inst_sram_wstrb,
    output [31:0]   inst_sram_addr,
    output [31:0]   inst_sram_wdata,   
*/

//inst_sram_req�����渳ֵ
assign inst_sram_wr    = 1'b0;    //fetch�׶�ֻ����д
assign inst_sram_size  = 2'b10;   //fetch�׶η���4�ֽ�
assign inst_sram_wstrb = 4'b0;    //fetch�׶�wstrb������
assign inst_sram_addr  = next_pc;
assign inst_sram_wdata = 32'b0;

/*----------------------------------------------------------------*/

/*----------------------------deliver fs_to_ds_bus------------------------*/
wire [31:0] fetch_inst;
assign fetch_inst = inst_sram_rdata;

//task13 add ADEF fetch_addr_exception
wire fs_ex_ADEF;
//fs_ex_ADEF happen when ~inst_sram_wr and last 2 bits of inst_sram_addr are not 2'b00
assign fs_ex_ADEF = ~inst_sram_wr && (next_pc[1] | next_pc[0]);  //last two bit != 0 <==> error address

//assign fs_to_ds_bus = {fs_ex_ADEF, fetch_inst, fetch_pc};
assign fs_to_ds_bus[31:0] = fetch_pc;
//���ݴ�ָ�����Чʱ������temp_inst,��Чʱ�������� fetch_inst
assign fs_to_ds_bus[63:32] = (temp_inst == 0) ? fetch_inst : temp_inst;
assign fs_to_ds_bus[64:64] = fs_ex_ADEF;

/*----------------------------------------------------------------*/

endmodule