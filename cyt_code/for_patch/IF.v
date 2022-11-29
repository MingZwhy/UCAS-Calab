`include "width.vh"

module stage1_IF(
    input clk,
    input reset,
    input ertn_flush,
    input wb_ex,
    input [31:0] ertn_pc,
    input [31:0] ex_entry,
    input [31:0] ex_tlbentry,

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
    input  [31:0]   inst_sram_rdata,

    input tlb_zombie,
    input tlb_reflush,
    input [31:0] tlb_reflush_pc,

    //for translate
    input crmd_da,      //��ǰ����ģʽ
    input crmd_pg,
    input [1:0] crmd_datf,
    input [1:0] crmd_datm,

    input [1:0] plv,    //��ǰ��Ȩ�ȼ�, 0-3, 0Ϊ���
    input [1:0] datf,   //ֱ�ӵ�ַ����ģʽ�£�ȡָ�����Ĵ洢��������

    input DMW0_PLV0,        //Ϊ1��ʾ��PLV0�¿���ʹ�øô��ڽ���ֱ��ӳ���ַ����
    input DMW0_PLV3,        //Ϊ1��ʾ��PLV3�¿���ʹ�øô��ڽ���ֱ��ӳ���ַ����
    input [1:0] DMW0_MAT,   //���ַ���ڸ�ӳ�䴰���·ô�����Ĵ洢���ͷ���
    input [2:0] DMW0_PSEG,  //ֱ��ӳ�䴰�������ַ��3λ
    input [2:0] DMW0_VSEG,  //ֱ��ӳ�䴰�����ַ��3λ

    input DMW1_PLV0,        
    input DMW1_PLV3,       
    input [1:0] DMW1_MAT,  
    input [2:0] DMW1_PSEG,  
    input [2:0] DMW1_VSEG,

    //for ҳ��ӳ��
    input [9:0] tlbasid_asid,

    output [18:0] s0_vppn,
    output s0_va_bit12,
    output [9:0] s0_asid,
    input s0_found,
    input [19:0] s0_ppn,
    input [1:0] s0_plv,
    input s0_v,

    input in_ex_tlb_refill
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
                if(wb_ex || ertn_flush || tlb_reflush)
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
                if(wb_ex || ertn_flush || tlb_reflush)
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
        else if((wb_ex || ertn_flush || tlb_reflush) && pre_if_to_fs_valid)
            //pre_if_to_fs_valid ��Ӧ1.2�������pre-if���͵ĵ�ַ���ñ�����
            deal_with_cancel <= 1'b1;
        else if(~fs_allow_in && (wb_ex || ertn_flush || tlb_reflush) && ~fs_ready_go)
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
assign next_pc = if_keep_pc ? br_delay_reg : wb_ex ? ex_entry : ertn_flush ? ertn_pc : 
                 tlb_reflush ? tlb_reflush_pc : (br_taken && ~br_stall) ? br_target : seq_pc;

wire [31:0] next_pc_dt;   //dt --> directly translate
assign next_pc_dt = next_pc;

wire [31:0] next_pc_dmw0; //DMW0
assign next_pc_dmw0 = {DMW0_PSEG , next_pc[28:0]};

wire [31:0] next_pc_dmw1; //DMW1
assign next_pc_dmw1 = {DMW1_PSEG , next_pc[28:0]};

wire [31:0] next_pc_ptt; //ppt --> page table translate
assign next_pc_ptt = {s0_ppn, next_pc[11:0]};

//s0_vppn
assign s0_vppn = next_pc[31:13];
//s0_va_12bit
assign s0_va_bit12 = next_pc[12];
//s0_asid
assign s0_asid = tlbasid_asid;

//choose next_pc
wire if_dt;
assign if_dt = crmd_da & ~crmd_pg;   //da=1, pg=0 --> ֱ�ӵ�ַ����ģʽ

wire if_indt;
assign if_indt = ~crmd_da & crmd_pg;   //da=0, pg=1 --> ӳ���ַ����ģʽ

wire if_dmw0;
assign if_dmw0 = ((plv == 0 && DMW0_PLV0) || (plv == 3 && DMW0_PLV3)) &&
                    (datf == DMW0_MAT) && (next_pc[31:29] == DMW0_VSEG);
                    
wire if_dmw1;
assign if_dmw1 = ((plv == 0 && DMW1_PLV0) || (plv == 3 && DMW1_PLV3)) &&
                    (datf == DMW1_MAT) && (next_pc[31:29] == DMW1_VSEG);

wire [31:0] next_pc_p;
assign next_pc_p = if_dt ? next_pc_dt : if_indt ? 
                (if_dmw0 ? next_pc_dmw0 : if_dmw1 ? next_pc_dmw1 : next_pc_ptt) : 0;

/*
1: fs_ex_fetch_tlb_refill         TLB��������
2: ex_load_invalid          load����ҳ��Ч����
3: ex_store_invalid         store����ҳ��Ч����
4: fs_ex_inst_invalid       ȡֵ����ҳ��Ч����
5: fs_ex_fetch_plv_invalid        ҳ��Ȩ�ȼ����Ϲ�����
6��ex_store_dirty           ҳ�޸�����  
*/

wire fs_ex_fetch_tlb_refill;
wire fs_ex_inst_invalid;
wire fs_ex_fetch_plv_invalid;

wire if_ppt;
assign if_ppt = if_indt && ~(if_dmw0 | if_dmw1);

assign fs_ex_fetch_tlb_refill = if_ppt & ~s0_found;
assign fs_ex_inst_invalid = if_ppt & s0_found & ~s0_v;
assign fs_ex_fetch_plv_invalid = if_ppt & s0_found & s0_v & (plv > s0_plv);

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
        else if(inst_sram_addr_ok && ~deal_with_cancel && ~wb_ex && ~ertn_flush && ~tlb_reflush)
            if_keep_pc <= 1'b0;
        else if((br_taken && ~br_stall) || wb_ex || ertn_flush || tlb_reflush)
            if_keep_pc <= 1'b1;
    end

always @(posedge clk)
    begin
        if(reset)
            br_delay_reg <= 32'b0;
        else if(wb_ex && in_ex_tlb_refill)
            br_delay_reg <= ex_tlbentry;
        else if(wb_ex)
            br_delay_reg <= ex_entry;
        else if(ertn_flush)
            br_delay_reg <= ertn_pc;
        else if(tlb_reflush)
            br_delay_reg <= tlb_reflush_pc;
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
assign inst_sram_addr  = next_pc_p;
assign inst_sram_wdata = 32'b0;

/*----------------------------------------------------------------*/

/*----------------------------deliver fs_to_ds_bus------------------------*/
wire [31:0] fetch_inst;
assign fetch_inst = inst_sram_rdata;

//task13 add ADEF fetch_addr_exception
wire fs_ex_ADEF;
//fs_ex_ADEF happen when ~inst_sram_wr and last 2 bits of inst_sram_addr are not 2'b00
assign fs_ex_ADEF = (if_ppt && next_pc[31]) || (next_pc_p[1] | next_pc_p[0]);  //last two bit != 0 <==> error address

assign fs_to_ds_bus[31:0] = fetch_pc;
//���ݴ�ָ�����Чʱ������temp_inst,��Чʱ�������� fetch_inst
assign fs_to_ds_bus[63:32] = (temp_inst == 0) ? fetch_inst : temp_inst;
assign fs_to_ds_bus[64:64] = fs_ex_ADEF;
assign fs_to_ds_bus[65:65] = tlb_zombie;
assign fs_to_ds_bus[66:66] = fs_ex_fetch_tlb_refill;
assign fs_to_ds_bus[67:67] = fs_ex_inst_invalid;
assign fs_to_ds_bus[68:68] = fs_ex_fetch_plv_invalid;

/*----------------------------------------------------------------*/

endmodule