`include "width.vh"

module csr_reg(
    input                         clk,
    input                         reset,

    input [`WIDTH_CSR_NUM-1:0]     csr_num,           //寄存器号

    input                         csr_re,            //读使能
    output             [31:0]     csr_rvalue,        //读数据
    output             [31:0]     ertn_pc,
    output             [31:0]     ex_entry,

    input                         csr_we,            //写使能
    input              [31:0]     csr_wmask,         //写掩码
    input              [31:0]     csr_wvalue,        //写数据

    input                         wb_ex,             //写回级异常
    input              [31:0]     wb_pc,             //异常pc
    input                         ertn_flush,        //ertn指令执行有效信号
    input              [5:0]      wb_ecode,          //异常类型1级码
    input              [8:0]      wb_esubcode,       //异常类型2级码
    input              [31:0]     wb_vaddr, 
    input              [31:0]     coreid_in,

    output                        has_int,
    input              [7:0]      hw_int_in,
    input                         ipi_int_in
);

/*
寄存器号：
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
CSR分区
*/

/*--------------------------当前模式信息 CRMD-------------------------*/


//当前特权等级
/*
2'b00: 最高特权级  2'b11：最低特权等级
触发特例时应将plv设为0，确保陷入后处于内核态最高特权等级
当执行ERTN指令从例外处理程序返回时，讲CSR_PRMD[PPLV] --> CSR_CRMD[PLV]
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

//当前全局中断使能
/*
1'b1：可中断    1'b0：屏蔽中断
当触发例外时，硬件置为0，确保陷入后屏蔽中断
例外处理程序决定重新开启中断响应时，显示设1
当执行ERTN指令从例外处理程序返回时，讲CSR_PRMD[IE] --> CSR_CRMD[IE]
*/
reg csr_crmd_ie;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_ie <= 1'b0;
        else if(wb_ex)
            //进入中断后，关闭中断使能
            csr_crmd_ie <= 1'b0;
        else if(ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end

//直接地址翻译使能 --> 初始化置为1
reg csr_crmd_da;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_da <= 1'b1;
    end

//暂未使用
reg csr_crmd_pg;
reg [1:0] csr_crmd_datf;
reg [1:0] csr_crmd_datm;
reg [22:0] csr_crmd_zero;

/*---------------------------------------------------------------------*/

/*--------------------------例外前模式信息 PRMD-------------------------*/

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

//暂未使用的
reg [28:0] reg_prmd_zero;

/*---------------------------------------------------------------------*/

/*--------------------------例外控制 ECFG-------------------------------*/

//控制各中断的局部使能位
/*
1'b1：可中断    1'b0：屏蔽中断
低10位局部中断使能位与CSR_ESTAT中IS[9:0]域记录的10个中断源一一对应
12:11位局部中断使能位与CSR_ESTAT中IS[12:11]域记录的2个中断源一一对应
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

//暂未使用的
reg [18:0] csr_ecgh_zero;

/*---------------------------------------------------------------------*/

/*--------------------------例外状态 ESTAT-------------------------------*/

//2个软中断状态位， 0和1比特分别对应SWI0 和 SWI1
//8个硬中断状态位， 2至9比特分贝对应HWI0 到 HWI7
//1个保留域
//第11位对应定时器中断TI的状态位
//第12位对应核间中断
reg [12:0] csr_estat_is;

always @(posedge clk)
    begin
        //软中断位 -- RW
        if(reset)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= 2'b0;
        else if(csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_wvalue[`CSR_ESTAT_IS_SOFT]
                              | ~csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_estat_is[`CSR_ESTAT_IS_SOFT] ;

        //硬中断位 -- R
        csr_estat_is[`CSR_ESTAT_IS_HARD] <= hw_int_in[7:0];

        //保留位
        csr_estat_is[`CSR_ESTAT_IS_LEFT1] <= 1'b0;

        //时钟中断 -- R 但是写CSR_TICLR_CLR可改变CSR_ESTAT_IS_TI
        if(timer_cnt[31:0] == 32'b0)
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b1;
        else if(csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
                && csr_wvalue[`CSR_TICLR_CLR])
            //对CSR_TICLR定时中断清除寄存器的CLR位写1 代表 清除时钟中断标记
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b0;

        //核间中断标记
        csr_estat_is[`CSR_ESTAT_IS_IPI] <= ipi_int_in;
    end

//保留位
reg [2:0] csr_estat_left;

//中断类型1级2级编码
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

//暂未使用的
reg csr_estat_zero;

/*---------------------------------------------------------------------*/

/*-----------------------例外返回地址 ERA-------------------------------*/

//触发例外的指令PC将被记录在EPC寄存器
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

/*-----------------------出错虚地址 BADV-------------------------------*/

//触发地址错误相关例外时，记录出错的虚地址
reg [31:0] csr_badv_vaddr;

wire wb_ex_addr_err;
/*
ECODE_ADEF: 取值地址错例外
ECODE_ADEM：访存指令地址错例外
ECODE_ALE：地址非对齐例外
*/
assign wb_ex_addr_err = (wb_ecode == `ECODE_ADE) || (wb_ecode == `ECODE_ALE);

always @(posedge clk)
    begin
        if(wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode == `ECODE_ADE && 
                               wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    end

/*---------------------------------------------------------------------*/

/*-----------------------例外入口地址 EENTRY-------------------------------*/

//EENTRY用于配置除TLB充填例外之外的例外和中断的入口地址
//只能由CSR指令更新
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

/*-----------------------临时寄存器 SAVE0-3-------------------------------*/

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

/*-----------------------定时器编号寄存器 TID-------------------------------*/

//定时器编号寄存器
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

/*-----------------------定时器配置寄存器 TCFG-------------------------------*/

//定时器使能位，en为1时定时器才会进行倒计时自检，并在减为0时置起定时中断信号
reg csr_tcfg_en;
//定时器循环模式控制位，为1时会循环
reg csr_tcfg_periodic;
//定时器倒计时自减计数的初始值
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

/*-----------------------TVAL的TimeVal域-------------------------------*/

wire [31:0] tcfg_cur_value;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg  [31:0] timer_cnt;

/*
这里用两个wire类型信号定义cur_tcfg 和 next_tcfg
是为了能在当软件开启timer的使能的同时发起timer_cnt的更新操作
即在下面的时序逻辑中的
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
        将此时写入的timer配置寄存器的定时器初始值更新到timer_cnt中

因为是在软件写TCFG的同时更新timer，
所以要看当前写入TCFG寄存器的值(next_value)，而不是用cur_value
*/

/*
当timer_cnt减到全0且定时器不是周期性工作模式情况下。
timer_cnt继续减1变成32'hffffffff,之后应当停止即使，
所以timer_cnt自减的条件包含timer_cnt!=32'hffffffff

周期性工作模式下，就重置为{csr_tcfg_initval, 2'b0}
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
                    //循环计时
                    timer_cnt <= {csr_tcfg_initval, 2'b0};
                else
                    timer_cnt <= timer_cnt - 1'b1;
            end
    end

assign csr_tval = timer_cnt[31:0];

/*---------------------------------------------------------------------*/

/*-----------------------TICLR的CLR域----------------------------------*/

//软件通过对TICLR寄存器位0写1来清除定时器置起的定时中断信号
//CLR域的读写属性位W1,意味着软件对它写1才会产生执行效果，执行效果
//具体体现在TCFG_EN上，但CLR域的值实际上不变，恒为0
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