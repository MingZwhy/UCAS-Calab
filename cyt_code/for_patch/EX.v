`define WIDTH_BR_BUS       34
`define WIDTH_FS_TO_DS_BUS 64
`define WIDTH_DS_TO_ES_BUS 156
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
assign ds_to_es_bus[149:135] = alu_op;    
assign ds_to_es_bus[150:150] = src1_is_pc;   
assign ds_to_es_bus[151:151] = src2_is_imm;  
assign ds_to_es_bus[152:152] = res_from_mem; 
assign ds_to_es_bus[153:153] = need_wait_div; 
assign ds_to_es_bus[155:154] = div_op;
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
wire        es_need_wait_div;
wire [1:0]  es_div_op;

reg [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ds_to_es_bus_reg <= 0;
        else if(ds_to_es_valid && es_allow_in)
            ds_to_es_bus_reg <= ds_to_es_bus;
        else if(es_need_wait_div)        
            ds_to_es_bus_reg <= ds_to_es_bus_reg; 
        else
            ds_to_es_bus_reg <= 0;
    end

/*init
* when ds_to_es_bus_reg <= ds_to_es_bus ; init <= 1
* when es_need_wait_div and ds_to_es_bus_reg keep still, init <= 0

* init = 1 and es_need_wait_div --> raise (un)signed_dividend(divisor)_tvalid
* so that we can make sure tvalid = 1 and EX at the same time

* other time (un)signed_dividend(divisor)_tvalid = (un)signed_dividend(divisor)_tvalid_reg

* in (un)signed_dividend(divisor)_tvalid_reg
* when es_need_wait_div && es_div_op && init, (un)signed_dividend(divisor)_tvalid_reg <= 1
* "init" make sure we will not raise valid after shaking hand
* when ready (shake hand successfully), (un)signed_dividend(divisor)_tvalid_reg <= 0
*/
reg init;
always @(posedge clk)
    begin
        if(reset)
            init <= 0;
        else if(ds_to_es_valid && es_allow_in)
            init <= 1;
        else
            init <= 0;
    end

assign {es_div_op, es_need_wait_div, es_res_from_mem, es_src2_is_imm, es_src1_is_pc,
        es_alu_op, es_mem_we, es_gr_we, es_dest, es_imm,
        es_rkd_value, es_rj_value, es_pc} = ds_to_es_bus_reg;
/*-------------------------------------------------------*/

/*-----------------------deliver es_to_ms_bus----------------*/

wire [31:0] es_alu_result;    //alu result(including mul_result)
//wire [31:0] div_result;
wire [31:0] es_calcu_result;  // alu_result or div_result
assign es_calcu_result = es_need_wait_div ? div_result : es_alu_result;

assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_calcu_result;

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

/*-----------------------deal with div-------------------*/
wire signed_dividend_tvalid, unsigned_dividend_tvalid;
wire signed_divisor_tvalid, unsigned_divisor_tvalid;
wire signed_dividend_tready, unsigned_dividend_tready;
wire signed_divisor_tready, unsigned_divisor_tready;
wire signed_out_tvalid, unsigned_out_tvalid;

wire [31:0] signed_dividend, unsigned_dividend;
wire [31:0] signed_divisor, unsigned_divisor;
wire [63:0] signed_result, unsigned_result;
wire [31:0] signed_div_result, unsigned_div_result;
wire [31:0] signed_mod_result, unsigned_mod_result;

assign signed_dividend = es_rj_value;
assign unsigned_dividend = es_rj_value;
assign signed_divisor = es_rkd_value;
assign unsigned_divisor = es_rkd_value;

assign signed_div_result = signed_result[63:32];
assign signed_mod_result = signed_result[31:0];
assign unsigned_div_result = unsigned_result[63:32];
assign unsigned_mod_result = unsigned_result[31:0];

wire [31:0] div_result;
assign div_result = (~es_div_op[1] & ~es_div_op[0]) ? signed_div_result :
                    (~es_div_op[1] &  es_div_op[0]) ? unsigned_div_result :
                    ( es_div_op[1] & ~es_div_op[0]) ? signed_mod_result :
                    ( es_div_op[1] &  es_div_op[0]) ? unsigned_mod_result :
                    32'b0;

div_signed signed_div(
    .aclk(clk),
    .s_axis_divisor_tdata(signed_divisor),
    .s_axis_divisor_tready(signed_divisor_tready),
    .s_axis_divisor_tvalid(signed_divisor_tvalid),
    .s_axis_dividend_tdata(signed_dividend),
    .s_axis_dividend_tready(signed_dividend_tready),
    .s_axis_dividend_tvalid(signed_dividend_tvalid),
    .m_axis_dout_tdata(signed_result),
    .m_axis_dout_tvalid(signed_out_tvalid)
);

div_unsigned unsigned_div(
    .aclk(clk),
    .s_axis_divisor_tdata(unsigned_divisor),
    .s_axis_divisor_tready(unsigned_divisor_tready),
    .s_axis_divisor_tvalid(unsigned_divisor_tvalid),
    .s_axis_dividend_tdata(unsigned_dividend),
    .s_axis_dividend_tready(unsigned_dividend_tready),
    .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
    .m_axis_dout_tdata(unsigned_result),
    .m_axis_dout_tvalid(unsigned_out_tvalid)
);

reg signed_dividend_tvalid_reg, unsigned_dividend_tvalid_reg;
reg signed_divisor_tvalid_reg, unsigned_divisor_tvalid_reg;

//div_signed dividend shake hand
assign signed_dividend_tvalid = init ? (es_need_wait_div && ~es_div_op[0]) : signed_dividend_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            signed_dividend_tvalid_reg <= 0;
        else if(signed_dividend_tready)               //shake hand
            signed_dividend_tvalid_reg <= 0;
        else if(es_need_wait_div && ~es_div_op[0] && init)    //div_w or mod_w
            signed_dividend_tvalid_reg <= 1;
    end

//div_signed divisor shake hand
assign signed_divisor_tvalid = init ? (es_need_wait_div && ~es_div_op[0]) : signed_divisor_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            signed_divisor_tvalid_reg <= 0;
        else if(signed_divisor_tready)                //shake hand
            signed_divisor_tvalid_reg <= 0;
        else if(es_need_wait_div && ~es_div_op[0] && init)    //div_w or mod_w
            signed_divisor_tvalid_reg <= 1;
    end

//div_unsigned dividend shake hand
assign unsigned_dividend_tvalid = init ? (es_need_wait_div && es_div_op[0]) : unsigned_dividend_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            unsigned_dividend_tvalid_reg <= 0;
        else if(unsigned_dividend_tready)               //shake hand
            unsigned_dividend_tvalid_reg <= 0;
        else if(es_need_wait_div && es_div_op[0] && init)    //div_wu or mod_ww
            unsigned_dividend_tvalid_reg <= 1;
    end

//div_unsigned divisor shake hand
assign unsigned_divisor_tvalid = init ? (es_need_wait_div && es_div_op[0]) : unsigned_divisor_tvalid_reg;
always@(posedge clk)
    begin
        if(reset)
            unsigned_divisor_tvalid_reg <= 0;
        else if(unsigned_divisor_tready)                //shake hand
            unsigned_divisor_tvalid_reg <= 0;
        else if(es_need_wait_div && es_div_op[0] && init)    //div_wu or mod_wu
            unsigned_divisor_tvalid_reg <= 1;
    end

/*-------------------------------------------------------*/

/*-------------------------valid-------------------------*/
reg es_valid;   

wire es_ready_go;
assign es_ready_go = es_need_wait_div ? (signed_out_tvalid || unsigned_out_tvalid) : 1'b1;
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
assign es_to_ds_bus = {es_gr_we,es_dest,IF_LOAD,es_calcu_result};

/*-------------------------------------------------------*/

endmodule