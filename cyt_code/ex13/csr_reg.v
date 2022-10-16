`include "width.vh"

module csr_reg(
    input                         clk,
    input                         reset,

    input [`WIDTH_CSR_NUM-1:0]     csr_num,           //�Ĵ�����

    input                         csr_re,            //��ʹ��
    output             [31:0]     csr_rvalue,        //������
    output             [31:0]     ertn_pc,
    output             [31:0]     ex_entry,

    input                         csr_we,            //дʹ��
    input              [31:0]     csr_wmask,         //д����
    input              [31:0]     csr_wvalue,        //д����

    input                         wb_ex,             //д�ؼ��쳣
    input              [31:0]     wb_pc,             //�쳣pc
    input                         ertn_flush,        //ertnָ��ִ����Ч�ź�
    input              [5:0]      wb_ecode,          //�쳣����1����
    input              [8:0]      wb_esubcode,       //�쳣����2����
    input              [31:0]     wb_vaddr, 
    input              [31:0]     coreid_in,

    output                        has_int,
    input              [7:0]      hw_int_in,
    input                         ipi_int_in
);

/*
�Ĵ����ţ�
`define CSR_CRMD 0x0
`define CSR_PRMD 0x1
`define CSR_ECFG 0x4
`define CSR_ESTAT 0x5
`define CSR_ERA 0x6
`define CSR_BADV 0x7
`define CSR_EENTRY 0xc
`define CSR_SAVE0 0x30
`define CSR_SAVE1 0x31
`define CSR_SAVE2 0x32
`define CSR_SAVE3 0x33
`define CSR_TID 0x40
`define CSR_TCFG 0x41
`define CSR_TVAL 0x42
`define CSR_TICLR 0x44
*/

/*
CSR����
*/

/*--------------------------��ǰģʽ��Ϣ CRMD-------------------------*/


//��ǰ��Ȩ�ȼ�
/*
2'b00: �����Ȩ��  2'b11�������Ȩ�ȼ�
��������ʱӦ��plv��Ϊ0��ȷ����������ں�̬�����Ȩ�ȼ�
��ִ��ERTNָ������⴦����򷵻�ʱ����CSR_PRMD[PPLV] --> CSR_CRMD[PLV]
*/
reg [1:0] csr_crmd_plv;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_plv <= 2'b0;
        else if(wb_ex)
            csr_crmd_plv <= 2'b0;
        else if(ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                         | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
    end

//��ǰȫ���ж�ʹ��
/*
1'b1�����ж�    1'b0�������ж�
����������ʱ��Ӳ����Ϊ0��ȷ������������ж�
���⴦�����������¿����ж���Ӧʱ����ʾ��1
��ִ��ERTNָ������⴦����򷵻�ʱ����CSR_PRMD[IE] --> CSR_CRMD[IE]
*/
reg csr_crmd_ie;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_ie <= 1'b0;
        else if(wb_ex)
            //�����жϺ󣬹ر��ж�ʹ��
            csr_crmd_ie <= 1'b0;
        else if(ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end

//ֱ�ӵ�ַ����ʹ�� --> ��ʼ����Ϊ1
reg csr_crmd_da;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_da <= 1'b1;
    end

//��δʹ��
reg csr_crmd_pg;
reg [1:0] csr_crmd_datf;
reg [1:0] csr_crmd_datm;
reg [22:0] csr_crmd_zero;

/*---------------------------------------------------------------------*/

/*--------------------------����ǰģʽ��Ϣ PRMD-------------------------*/

reg [1:0] csr_prmd_pplv;
reg csr_prmd_pie;

always @(posedge clk)
    begin
        if(wb_ex)
            begin
                csr_prmd_pplv <= csr_crmd_plv;
                csr_prmd_pie  <= csr_crmd_ie;
            end
        else if(csr_we && csr_num == `CSR_PRMD)
            begin
                csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                              | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
                csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                              | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
            end
    end

//��δʹ�õ�
reg [28:0] reg_prmd_zero;

/*---------------------------------------------------------------------*/

/*--------------------------������� ECFG-------------------------------*/

//���Ƹ��жϵľֲ�ʹ��λ
/*
1'b1�����ж�    1'b0�������ж�
��10λ�ֲ��ж�ʹ��λ��CSR_ESTAT��IS[9:0]���¼��10���ж�Դһһ��Ӧ
12:11λ�ֲ��ж�ʹ��λ��CSR_ESTAT��IS[12:11]���¼��2���ж�Դһһ��Ӧ
*/
reg [12:0] csr_ecfg_lie;

always @(posedge clk)
    begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                         | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end

//��δʹ�õ�
reg [18:0] csr_ecgh_zero;

/*---------------------------------------------------------------------*/

/*--------------------------����״̬ ESTAT-------------------------------*/

//2�����ж�״̬λ�� 0��1���طֱ��ӦSWI0 �� SWI1
//8��Ӳ�ж�״̬λ�� 2��9���طֱ���ӦHWI0 �� HWI7
//1��������
//��11λ��Ӧ��ʱ���ж�TI��״̬λ
//��12λ��Ӧ�˼��ж�
reg [12:0] csr_estat_is;

always @(posedge clk)
    begin
        //���ж�λ -- RW
        if(reset)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= 2'b0;
        else if(csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_wvalue[`CSR_ESTAT_IS_SOFT]
                              | ~csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_estat_is[`CSR_ESTAT_IS_SOFT] ;

        //Ӳ�ж�λ -- R
        csr_estat_is[`CSR_ESTAT_IS_HARD] <= hw_int_in[7:0];

        //����λ
        csr_estat_is[`CSR_ESTAT_IS_LEFT1] <= 1'b0;

        //ʱ���ж� -- R ����дCSR_TICLR_CLR�ɸı�CSR_ESTAT_IS_TI
        if(timer_cnt[31:0] == 32'b0)
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b1;
        else if(csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
                && csr_wvalue[`CSR_TICLR_CLR])
            //��CSR_TICLR��ʱ�ж�����Ĵ�����CLRλд1 ���� ���ʱ���жϱ��
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b0;

        //�˼��жϱ��
        csr_estat_is[`CSR_ESTAT_IS_IPI] <= ipi_int_in;
    end

//����λ
reg [2:0] csr_estat_left;

//�ж�����1��2������
reg [5:0] csr_estat_ecode;
reg [8:0] csr_estat_esubcode;

always @(posedge clk)
    begin
        if(wb_ex)
            begin
                csr_estat_ecode <= wb_ecode;
                csr_estat_esubcode <= wb_esubcode;
            end
    end

//��δʹ�õ�
reg csr_estat_zero;

/*---------------------------------------------------------------------*/

/*-----------------------���ⷵ�ص�ַ ERA-------------------------------*/

//���������ָ��PC������¼��EPC�Ĵ���
reg [31:0] csr_era_pc;

always @(posedge clk)
    begin
        if(wb_ex)
            csr_era_pc <= wb_pc;
        else if(csr_we && csr_num == `CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                       | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc; 
    end

/*---------------------------------------------------------------------*/

/*-----------------------�������ַ BADV-------------------------------*/

//������ַ�����������ʱ����¼��������ַ
reg [31:0] csr_badv_vaddr;

wire wb_ex_addr_err;
/*
ECODE_ADEF: ȡֵ��ַ������
ECODE_ADEM���ô�ָ���ַ������
ECODE_ALE����ַ�Ƕ�������
*/
assign wb_ex_addr_err = (wb_ecode == `ECODE_ADE) || (wb_ecode == `ECODE_ALE);

always @(posedge clk)
    begin
        if(wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode == `ECODE_ADE && 
                               wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    end

/*---------------------------------------------------------------------*/

/*-----------------------������ڵ�ַ EENTRY-------------------------------*/

//EENTRY�������ó�TLB��������֮���������жϵ���ڵ�ַ
//ֻ����CSRָ�����
reg [5:0] csr_eentry_zero;
reg [25:0] csr_eentry_va;

always @(posedge clk)
    begin
        if(reset)
            csr_eentry_zero <= 6'b0;
    end

always @(posedge clk)
    begin
        if(csr_we && csr_num == `CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                          | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end
/*---------------------------------------------------------------------*/

/*-----------------------��ʱ�Ĵ��� SAVE0-3-------------------------------*/

reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;

always @(posedge clk)
    begin
        if(csr_we && csr_num == `CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;

        if(csr_we && csr_num == `CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;

        if(csr_we && csr_num == `CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;

        if(csr_we && csr_num == `CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end

/*---------------------------------------------------------------------*/

/*-----------------------��ʱ����żĴ��� TID-------------------------------*/

//��ʱ����żĴ���
reg [31:0] csr_tid_tid;

always @(posedge clk)
    begin
        if(reset)
            csr_tid_tid <= coreid_in;
        else if(csr_we && csr_num == `CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end

/*---------------------------------------------------------------------*/

/*-----------------------��ʱ�����üĴ��� TCFG-------------------------------*/

//��ʱ��ʹ��λ��enΪ1ʱ��ʱ���Ż���е���ʱ�Լ죬���ڼ�Ϊ0ʱ����ʱ�ж��ź�
reg csr_tcfg_en;
//��ʱ��ѭ��ģʽ����λ��Ϊ1ʱ��ѭ��
reg csr_tcfg_periodic;
//��ʱ������ʱ�Լ������ĳ�ʼֵ
reg [29:0] csr_tcfg_initval;

always @(posedge clk)
    begin
        if(reset)
            csr_tcfg_en <= 1'b0;
        else if(csr_we && csr_num == `CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;

        if(csr_we && csr_num == `CSR_TCFG)
            begin
                csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC] & csr_wvalue[`CSR_TCFG_PERIODIC]
                                | ~csr_wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
                csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL]
                                | ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
            end
    end

/*---------------------------------------------------------------------*/

/*-----------------------TVAL��TimeVal��-------------------------------*/

wire [31:0] tcfg_cur_value;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg  [31:0] timer_cnt;

/*
����������wire�����źŶ���cur_tcfg �� next_tcfg
��Ϊ�����ڵ��������timer��ʹ�ܵ�ͬʱ����timer_cnt�ĸ��²���
���������ʱ���߼��е�
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
        ����ʱд���timer���üĴ����Ķ�ʱ����ʼֵ���µ�timer_cnt��

��Ϊ�������дTCFG��ͬʱ����timer��
����Ҫ����ǰд��TCFG�Ĵ�����ֵ(next_value)����������cur_value
*/

/*
��timer_cnt����ȫ0�Ҷ�ʱ�����������Թ���ģʽ����¡�
timer_cnt������1���32'hffffffff,֮��Ӧ��ֹͣ��ʹ��
����timer_cnt�Լ�����������timer_cnt!=32'hffffffff

�����Թ���ģʽ�£�������Ϊ{csr_tcfg_initval, 2'b0}
*/

assign tcfg_cur_value = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                      | ~csr_wmask[31:0] & tcfg_cur_value;

always @(posedge clk)
    begin
        if(reset)
            timer_cnt <= 32'hffffffff;
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
        else if(csr_tcfg_en && timer_cnt!=32'hffffffff)
            begin
                if(timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                    //ѭ����ʱ
                    timer_cnt <= {csr_tcfg_initval, 2'b0};
                else
                    timer_cnt <= timer_cnt - 1'b1;
            end
    end

assign csr_tval = timer_cnt[31:0];

/*---------------------------------------------------------------------*/

/*-----------------------TICLR��CLR��----------------------------------*/

//���ͨ����TICLR�Ĵ���λ0д1�������ʱ������Ķ�ʱ�ж��ź�
//CLR��Ķ�д����λW1,��ζ���������д1�Ż����ִ��Ч����ִ��Ч��
//����������TCFG_EN�ϣ���CLR���ֵʵ���ϲ��䣬��Ϊ0
wire csr_ticlr_clr;
assign csr_ticlr_clr = 1'b0;

/*---------------------------------------------------------------------*/

/*-----------------------rvalue----------------------------------------*/
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_eentey_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;

assign csr_crmd_rvalue = {28'b0, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 
                           3'b0, csr_estat_is};
assign csr_era_rvalue = csr_era_pc;
assign csr_badv_rvalue = csr_badv_vaddr;
assign csr_eentey_rvalue = {csr_eentry_va, 6'b0};
assign csr_save0_rvalue = csr_save0_data;
assign csr_save1_rvalue = csr_save1_data;
assign csr_save2_rvalue = csr_save2_data;
assign csr_save3_rvalue = csr_save3_data;
assign csr_tid_rvalue = csr_tid_tid;
assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign csr_tval_rvalue = csr_tval;

assign csr_rvalue = {32{csr_num==`CSR_CRMD}} & csr_crmd_rvalue
                  | {32{csr_num==`CSR_PRMD}} & csr_prmd_rvalue
                  | {32{csr_num==`CSR_ECFG}} & csr_ecfg_rvalue
                  | {32{csr_num==`CSR_ESTAT}} & csr_estat_rvalue
                  | {32{csr_num==`CSR_ERA}} & csr_era_rvalue
                  | {32{csr_num==`CSR_BADV}} & csr_badv_rvalue
                  | {32{csr_num==`CSR_EENTRY}} & csr_eentey_rvalue
                  | {32{csr_num==`CSR_SAVE0}} & csr_save0_rvalue
                  | {32{csr_num==`CSR_SAVE1}} & csr_save1_rvalue
                  | {32{csr_num==`CSR_SAVE2}} & csr_save2_rvalue
                  | {32{csr_num==`CSR_SAVE3}} & csr_save3_rvalue
                  | {32{csr_num==`CSR_TID}} & csr_tid_rvalue
                  | {32{csr_num==`CSR_TCFG}} & csr_tcfg_rvalue
                  | {32{csr_num==`CSR_TVAL}} & csr_tval_rvalue;

/*---------------------------------------------------------------------*/

/*-------------------------------output--------------------------------*/

assign ertn_pc = csr_era_rvalue;
assign ex_entry = csr_eentey_rvalue;

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0)
                && (csr_crmd_ie == 1'b1);


/*---------------------------------------------------------------------*/

endmodule