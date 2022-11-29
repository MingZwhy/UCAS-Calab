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
    input crmd_da,      //当前翻译模式
    input crmd_pg,
    input [1:0] crmd_datf,
    input [1:0] crmd_datm,

    input [1:0] plv,    //当前特权等级, 0-3, 0为最高
    input [1:0] datf,   //直接地址翻译模式下，取指操作的存储访问类型

    input DMW0_PLV0,        //为1表示在PLV0下可以使用该窗口进行直接映射地址翻译
    input DMW0_PLV3,        //为1表示在PLV3下可以使用该窗口进行直接映射地址翻译
    input [1:0] DMW0_MAT,   //虚地址落在该映射窗口下访存操作的存储类型访问
    input [2:0] DMW0_PSEG,  //直接映射窗口物理地址高3位
    input [2:0] DMW0_VSEG,  //直接映射窗口虚地址高3位

    input DMW1_PLV0,        
    input DMW1_PLV3,       
    input [1:0] DMW1_MAT,  
    input [2:0] DMW1_PSEG,  
    input [2:0] DMW1_VSEG,

    //for 页表映射
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
pre_if伪流水级发出取指请求:

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
            //握手成功，在握手成功的下一个时钟上沿拉低req
            inst_sram_req_reg <= 1'b0;
        else if(inst_sram_data_ok)
            //在握手接收到数据(data_ok)时，重新拉高req
            inst_sram_req_reg <= 1'b1;
    end

// 当req与addr_ok握手成功时，代表请求发送成功，拉高ready_go
wire pre_if_ready_go;
assign pre_if_ready_go = inst_sram_req & inst_sram_addr_ok;
wire pre_if_to_fs_valid;
assign pre_if_to_fs_valid = !reset & pre_if_ready_go;

wire fs_ready_go;
// 当data_ok拉高时代表已送来指令码，将fs_ready_go拉高
// 当temp_inst有效时说明fs_ready_go已经拉高，而ds_allow_in没拉高
// 因此此时在等ds_allow_in，需要保持temp_inst拉高
// 同时当deal_with_cancel拉高时，表明需要丢弃下一个收到的错误指令，即将fs_ready_go拉低
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
                    /*对应2.1情况——IF级没有有效指令或
                    有有效指令但将要流向ID级，若收到cancel
                    则将下一拍fs_vaild置0*/
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

//当fs_ready_go = 1 而 ds_allow_in = 0 时
//IF级收到了指令但是ID级还不让进入，需要设置一组触发器来保存取出的指令
//当该组触发器有有效数据时，则选择该组触发器保存的数据作为IF级取回的指令送往ID级

reg [31:0] temp_inst;

always @(posedge clk)
    begin
        if(reset)
            temp_inst <= 0;
        else if(fs_ready_go)
            begin
                if(wb_ex || ertn_flush || tlb_reflush)
                    //当cancel时，将缓存指令清0
                    //对应2.2.1情况
                    temp_inst <= 0;
                else if(!ds_allow_in)
                    //暂存指令
                    temp_inst <= inst_sram_rdata;
                else
                    //当ds允许进入时，在这个时钟上沿就立刻将temp_inst
                    //送入ds级，同时将temp_inst清零，代表该指令缓存不再有有效指令
                    temp_inst <= 0;
            end
    end

/*为了解决清空流水级中的1.2和2.2.2情况
即在cancel后，IF级后续收到的第一个返回的指令数据是对当前被cancel的取值指令的返回
因此后续收到的第一个返回的指令数据需要被丢弃，不能让其流向ID级
解决方法是：
维护一个触发器，复位值为0，当遇到1.2或2.2.2时，该触发器置1，当收到data_ok时复置0
当该触发器为1时，将IF级的ready_go抹零，即当data_ok来临的时钟上沿，fs_ready_go
恰好仍为0，导致刚好丢弃了data（丢弃的指令） */
reg deal_with_cancel;
always @(posedge clk)
    begin
        if(reset)
            deal_with_cancel <= 1'b0;
        else if((wb_ex || ertn_flush || tlb_reflush) && pre_if_to_fs_valid)
            //pre_if_to_fs_valid 对应1.2情况——pre-if发送的地址正好被接收
            deal_with_cancel <= 1'b1;
        else if(~fs_allow_in && (wb_ex || ertn_flush || tlb_reflush) && ~fs_ready_go)
            //~fs_allow_in 且 ~fs_ready_go 对应2.2.2情况——IF级正在等待data_ok
            deal_with_cancel <= 1'b1;
        else if(inst_sram_data_ok)
            deal_with_cancel <= 1'b0;
    end

/*----------------------------------------------------------------*/

/*--------------------------------pc------------------------------*/

wire [31:0] br_target;  //跳转地址
wire br_taken;          //是否跳转
wire br_stall;          
wire br_taken_cancel; 
//br_taken和br_target来自br_bus
assign {br_taken_cancel, br_stall, br_taken, br_target} = br_bus;

reg [31:0] fetch_pc; 

wire [31:0] seq_pc;     //顺序取址
assign seq_pc = (fetch_pc + 4);
wire [31:0] next_pc;    //nextpc来自seq或br
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
assign if_dt = crmd_da & ~crmd_pg;   //da=1, pg=0 --> 直接地址翻译模式

wire if_indt;
assign if_indt = ~crmd_da & crmd_pg;   //da=0, pg=1 --> 映射地址翻译模式

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
1: fs_ex_fetch_tlb_refill         TLB重填例外
2: ex_load_invalid          load操作页无效例外
3: ex_store_invalid         store操作页无效例外
4: fs_ex_inst_invalid       取值操作页无效例外
5: fs_ex_fetch_plv_invalid        页特权等级不合规例外
6：ex_store_dirty           页修改例外  
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
当出现异常入口pc、异常返回pc和跳转pc时，信号和pc可能只能维持一拍，
但在req收到addr_ok前需要维持取址地址不变
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

//inst_sram_req锟斤拷锟斤拷锟芥赋值
assign inst_sram_wr    = 1'b0;    //fetch阶段只读不写
assign inst_sram_size  = 2'b10;   //fetch阶段访问4字节
assign inst_sram_wstrb = 4'b0;    //fetch阶段wstrb无意义
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
//当暂存指令缓存有效时，传入temp_inst,无效时正常传入 fetch_inst
assign fs_to_ds_bus[63:32] = (temp_inst == 0) ? fetch_inst : temp_inst;
assign fs_to_ds_bus[64:64] = fs_ex_ADEF;
assign fs_to_ds_bus[65:65] = tlb_zombie;
assign fs_to_ds_bus[66:66] = fs_ex_fetch_tlb_refill;
assign fs_to_ds_bus[67:67] = fs_ex_inst_invalid;
assign fs_to_ds_bus[68:68] = fs_ex_fetch_plv_invalid;

/*----------------------------------------------------------------*/

endmodule