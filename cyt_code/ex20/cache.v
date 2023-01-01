module cache(
    input       clk,
    input       resetn,
    
    //cache模块与CPU流水线的交互接口
    input           valid,          //cpu发来的请求有效
    input           op,             //0 --> 读 ; 1 --> 写
    input  [7:0]    index,          //地址的index域(addr[11:4])(虚)
    input  [19:0]   tag,            //虚实转换后的地址高20位
    input  [3:0]    offset,         //地址的offset域(addr[3:0])
    input  [3:0]    wstrb,          //写字节使能信号
    input  [31:0]   wdata,          //写数据
    
    output          addr_ok,        //该次请求的地址传输OK
    output          data_ok,        //该次请求的数据传输OK
    output [31:0]   rdata,          //读cache结果

    //cache模块与AXI总线接口模块接口

    //part1 --> read
    output          rd_req,         //读请求有效信号
    output [2:0]    rd_type,        //读请求类型:
    //3'b000 : 字节 ; 3'b001 : 半字 ; 3'b010 : 字 ; 3'b100 : cache行
    output [31:0]   rd_addr,        //读请求起始地址
    input           rd_rdy,         //读请求能否被接收的握手信号
    input           ret_valid,      //返回数据有效信号后，高电平有效
    input           ret_last,       //返回数据是一次读请求对应的最后一个返回数据
    input  [31:0]   ret_data,       //读返回数据

    //part2 --> write
    output          wr_req,         //写请求有效信号
    output [2:0]    wr_type,        //写请求类型
    //3'b000 : 字节 ; 3'b001 : 半字 ; 3'b010 : 字 ; 3'b100 : cache行
    output [31:0]   wr_addr,        //写请求起始地址
    output [3:0]    wr_wstrb,       //写操作的字节掩码
    output [127:0]  wr_data,        //写数据
    input           wr_rdy          //写请求能否被接收的握手信号
);

/*-----------------------------------状态机-----------------------------------------*/

localparam  IDLE            = 5'b00001,
            LOOKUP          = 5'b00010,
            //讲义中名字为MISS，但似乎并不准确，实际要做的工作室将脏块写回
            DIRTY_WB        = 5'b00100,
            REPLACE         = 5'b01000,
            REFILL          = 5'b10000,

            //Write Buffer状态机
            WB_IDLE         = 2'b01,
            WB_WRITE        = 2'b10;

reg [4:0] curr_state;
reg [4:0] next_state;
reg [1:0] wb_curr_state;
reg [1:0] wb_next_state;

//part1: 主状态机

always @(posedge clk)
    begin
        if(~resetn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

always @(*)
    begin
        case(curr_state)
            IDLE:
                begin
                    if(~valid)
                        //如果cpu没有发来请求，停留在IDLE
                        next_state <= IDLE;
                    else
                        begin
                            if(hit_write)
                                //如果有请求但该请求与Hit Write冲突而无法被Cache接收
                                next_state <= IDLE;
                            else
                                //有请求且不冲突
                                next_state <= LOOKUP;
                        end
                end
            LOOKUP:
                begin
                    if(cache_hit)
                        begin
                            if(~valid)
                                //若cache命中且没有新请求，则返回IDLE等待
                                next_state <= IDLE;
                            else
                                begin
                                //若cache命中但有新请求，需分情况讨论
                                    if(hit_write)
                                        //有新请求但是hit write冲突，暂时无法接收
                                        //暂时没有处理Hit Write的第一种情况
                                        next_state <= IDLE;
                                    else
                                        //可以接收新请求
                                        next_state <= LOOKUP;
                                end
                        end
                    else
                        begin
                            if(if_dirty)
                                //若被替换块是脏块，则需要写回
                                next_state <= DIRTY_WB;
                            else
                                //若被替换块非脏块，则不需要写回
                                next_state <= REPLACE;
                        end
                end
            DIRTY_WB:
                begin
                    if(~wr_rdy)
                        //总线并没有准备好接受写请求，状态阻塞在DIRTY_WB
                        next_state <= DIRTY_WB;
                    else
                        //总线准备好接受写请求，此时将发出wr_req
                        //同时发出的有wr_type,wr_addr,wr_wtrb,wr_data
                        //因此wr_req的判断条件应为
                        //(curr_state == DIRTY_WB) && (wr_rdy) 
                        next_state <= REPLACE;
                end
            REPLACE:
                begin
                    if(~rd_rdy)
                        //AXI总线没有准备好接收读请求
                        next_state <= REPLACE;
                    else
                        //AXI总线准备好接收读请求
                        //也对AXI总线发起缺失cache的读请求
                        next_state <= REFILL;
                end
            REFILL:
                begin
                    if(ret_valid && ret_last)
                         next_state <= IDLE;
                    // if(ret_valid && ~ret_last)
                    //     //并未发来最后一个32位数据
                    //     next_state <= REFILL;
                    // else if(ret_valid && ret_last)
                    //     next_state <= IDLE;
                end
        endcase
    end

//part2: Write Buffer状态机

always @(posedge clk)
    begin
        if(~resetn)
            wb_curr_state <= WB_IDLE;
        else
            wb_curr_state <= wb_next_state;
    end

always @(*)
    begin
        case(wb_curr_state)
            WB_IDLE:
                begin
                    if(((curr_state == LOOKUP) && (op == 1) && cache_hit) || (curr_state == REFILL && buff_op == 1 && ret_last && ret_valid))
                        //主状态机处于LOOKUP状态且发现Store操作命中Cache
                        wb_next_state <= WB_WRITE;
                    else
                        wb_next_state <= WB_IDLE;
                end
            WB_WRITE:
                begin
                    if((curr_state == LOOKUP) && (op == 1) && cache_hit)
                        //主状态机发现新的Hit Write
                        wb_next_state <= WB_WRITE;
                    else
                        wb_next_state <= WB_IDLE;
                end
        endcase
    end

/*---------------------------------------------------------------------------------*/

/*-------------------------------BLOCK RAM(v,tag)----------------------------------*/
reg [19:0] reg_tag;

//当接受请求的同时，将从MMU传来实tag，需要将其保存
always @(posedge clk)
    begin
        if(~resetn)
            reg_tag <= 0;
        else if((curr_state == IDLE && valid && wb_curr_state != WB_WRITE) || (curr_state == LOOKUP && next_state == LOOKUP))
            reg_tag <= tag;
    end

//这里为LOOKUP阶段查找时的命中路
//需要与replace_way区分开

wire way0_v;
wire way1_v;

assign way0_v = tagv_rdata[0][20];
assign way1_v = tagv_rdata[1][20];

wire [19:0] way0_tag;
wire [19:0] way1_tag;

assign way0_tag = tagv_rdata[0][19:0];
assign way1_tag = tagv_rdata[1][19:0];

wire way0_hit;
wire way1_hit;
wire cache_hit;

assign way0_hit = way0_v && (way0_tag == reg_tag);
assign way1_hit = way1_v && (way1_tag == reg_tag);
assign cache_hit = way0_hit || way1_hit;

assign tagv_we[0] = (curr_state == REFILL) && (buff_way == 0);
assign tagv_we[1] = (curr_state == REFILL) && (buff_way == 1);

assign tagv_addr[0] = index;
assign tagv_addr[1] = index;

assign tagv_wdata[0] = {1'b1, reg_tag};
assign tagv_wdata[1] = {1'b1, reg_tag};

//共两路，每路4x(20 + 1)，共8块bank
wire        tagv_we   [1:0];
wire [7:0]  tagv_addr [1:0];       //depth = 256 = 2 ^ 8
wire [20:0] tagv_wdata[1:0];
wire [20:0] tagv_rdata[1:0];

//way0
TAGV_RAM tagv_way0_ram
(
    .clka (clk),
    .ena(1'b1),
    .wea  (tagv_we[0]),
    .addra(tagv_addr[0]),
    .dina (tagv_wdata[0]),
    .douta(tagv_rdata[0])
);

//way1
TAGV_RAM tagv_way1_ram
(
    .clka (clk),
    .ena(1'b1),
    .wea  (tagv_we[1]),
    .addra(tagv_addr[1]),
    .dina (tagv_wdata[1]),
    .douta(tagv_rdata[1])
);

/*---------------------------------------------------------------------------------*/

/*----------------------------------reg file(d)------------------------------------*/
reg [255:0] way0_d_reg;
reg [255:0] way1_d_reg;

always @(posedge clk)
    begin
        if(~resetn)
            begin
                way0_d_reg <= 256'b0;
                way1_d_reg <= 256'b0;
            end
        if(curr_state == LOOKUP && op == 1 && cache_hit)
            //当cache命中且为写操作时，需要置脏位
            begin
                if(way0_hit == 1)
                    way0_d_reg[index] <= 1'b1;
                else if(way1_hit == 1)
                    way1_d_reg[index] <= 1'b1;
            end
        else if(curr_state == REFILL)
            //当cache重填时，若为读操作，则将脏位置0，若为写操作则置1
            begin
                if(op == 0)
                    //读操作：将脏位置0
                    begin
                        if(buff_way == 0)
                            way0_d_reg[index] <= 1'b0;
                        else
                            way1_d_reg[index] <= 1'b0;
                    end
                else
                    //写操作：将脏位置1
                    begin
                        if(buff_way == 0)
                            way0_d_reg[index] <= 1'b1;
                        else
                            way1_d_reg[index] <= 1'b1;
                    end
            end
    end

wire way0_d;
wire way1_d;

wire replace_way;
reg  random_way;               //设计随机的路
always @(posedge clk) begin
    if(~resetn)
        random_way <= 1'b0;
    else if(next_state == LOOKUP)
        random_way <= ({$random()} % 2);
end
assign replace_way = random_way;      //使用随机替换算法


assign way0_d = way0_d_reg[index];
assign way1_d = way1_d_reg[index];

wire if_dirty;
assign if_dirty = replace_way ? way1_d : way0_d;

/*---------------------------------------------------------------------------------*/

/*-----------------------------BLOCK RAM(data_bank)--------------------------------*/

//共两路，每路4x32，共8块bank
wire [3:0]  data_bank_we   [1:0][3:0];         //开启了字节写使能之后we为4位
wire [7:0]  data_bank_addr [1:0][3:0];         //depth = 256 = 2 ^ 8
wire [31:0] data_bank_wdata[1:0][3:0];
wire [31:0] data_bank_rdata[1:0][3:0];

//最终读出的数据
wire [127:0] cache_rdata;
assign cache_rdata = (buff_way == 1'b0) ? {data_bank_rdata[0][3], data_bank_rdata[0][2], data_bank_rdata[0][1], data_bank_rdata[0][0]} :
                                         {data_bank_rdata[1][3], data_bank_rdata[1][2], data_bank_rdata[1][1], data_bank_rdata[1][0]};

//在wb_curr_state即将由WB_IDEL进入WB_WRITE时需将写信息寄存

wire if_write;
assign if_write = (wb_curr_state == WB_WRITE);

assign data_bank_we[0][0] = ({4{if_write && ~buff_way && buff_offset[3:2] == 0}} & buff_wstrb) | {4{ret_valid & ~buff_way & ret_cnt == 2'b00}};
assign data_bank_we[0][1] = ({4{if_write && ~buff_way && buff_offset[3:2] == 1}} & buff_wstrb) | {4{ret_valid & ~buff_way & ret_cnt == 2'b01}};
assign data_bank_we[0][2] = ({4{if_write && ~buff_way && buff_offset[3:2] == 2}} & buff_wstrb) | {4{ret_valid & ~buff_way & ret_cnt == 2'b10}};
assign data_bank_we[0][3] = ({4{if_write && ~buff_way && buff_offset[3:2] == 3}} & buff_wstrb) | {4{ret_valid & ~buff_way & ret_cnt == 2'b11}};
assign data_bank_we[1][0] = ({4{if_write && buff_way  && buff_offset[3:2] == 0}} & buff_wstrb) | {4{ret_valid & buff_way  & ret_cnt == 2'b00}};
assign data_bank_we[1][1] = ({4{if_write && buff_way  && buff_offset[3:2] == 1}} & buff_wstrb) | {4{ret_valid & buff_way  & ret_cnt == 2'b01}};
assign data_bank_we[1][2] = ({4{if_write && buff_way  && buff_offset[3:2] == 2}} & buff_wstrb) | {4{ret_valid & buff_way  & ret_cnt == 2'b10}};
assign data_bank_we[1][3] = ({4{if_write && buff_way  && buff_offset[3:2] == 3}} & buff_wstrb) | {4{ret_valid & buff_way  & ret_cnt == 2'b11}};

assign data_bank_addr[0][0] = buff_index;
assign data_bank_addr[0][1] = buff_index;
assign data_bank_addr[0][2] = buff_index;
assign data_bank_addr[0][3] = buff_index;
assign data_bank_addr[1][0] = buff_index;
assign data_bank_addr[1][1] = buff_index;
assign data_bank_addr[1][2] = buff_index;
assign data_bank_addr[1][3] = buff_index;

assign data_bank_wdata[0][0] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[0][1] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[0][2] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[0][3] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][0] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][1] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][2] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][3] = (ret_valid)? ret_data : buff_wdata;

genvar i;

//way0
generate
     for (i = 0; i < 4; i = i + 1)
        begin
            DATA_bank_RAM data_bank_way0_ram_i
            (
                .clka (clk),
                .ena(1'b1),
                .wea  (data_bank_we[0][i]),
                .addra(data_bank_addr[0][i]),
                .dina (data_bank_wdata[0][i]),
                .douta(data_bank_rdata[0][i])
            );
        end
endgenerate

//way1
generate
     for (i = 0; i < 4; i = i + 1)
        begin
            DATA_bank_RAM data_bank_way1_ram_i
            (
                .clka (clk),
                .ena(1'b1),
                .wea  (data_bank_we[1][i]),
                .addra(data_bank_addr[1][i]),
                .dina (data_bank_wdata[1][i]),
                .douta(data_bank_rdata[1][i])
            );
        end
endgenerate
/*---------------------------------------------------------------------------------*/

/*-------------------------------API with CPU and AXI------------------------------*/

/*接收valid请求时向CPU拉高addr_ok，注意接收请求分两种情况
1：由IDLE即将进入LOOKUP
2：由LOOKUP继续接收请求扔留在LOOKUP
这两种情况的next_state均为LOOKUP
*/
assign addr_ok = (next_state == LOOKUP);

/*准备好读的数据或写成功时向CPU拉高data_ok，分三种情况
1：在LOOKUP状态下是写操作，此时无论命中与否都可以返回data_ok
2：在LOOKUP状态下是读操作且命中cache
3：在REFILL状态下的最后一拍，即读出AXI发来的最后一个32位数据时
*/
assign data_ok = ((curr_state == LOOKUP) && (op == 1 || cache_hit)) || 
                 (curr_state == REFILL && op == 0 && ret_valid && ret_last);

//在REPLACE状态下发出读请求
assign rd_req  = curr_state == REPLACE;

reg reg_wr_req;
always @(posedge clk)
begin
    if(~resetn)
        reg_wr_req <= 1'b0;
    else 
        begin
            if(curr_state == DIRTY_WB && wr_rdy == 1)
                reg_wr_req <= 1'b1;
            else if(wr_rdy)
                reg_wr_req <= 1'b0;
        end
end
assign wr_req  = reg_wr_req;

assign rdata   =  way0_hit?
                  ((offset[3:2] == 2'b00) ? data_bank_rdata[0][0] :
                   (offset[3:2] == 2'b01) ? data_bank_rdata[0][1] :
                   (offset[3:2] == 2'b10) ? data_bank_rdata[0][2] :
                   data_bank_rdata[0][3]) :
                  way1_hit?
                  ((offset[3:2] == 2'b00) ? data_bank_rdata[1][0] :
                   (offset[3:2] == 2'b01) ? data_bank_rdata[1][1] :
                   (offset[3:2] == 2'b10) ? data_bank_rdata[1][2] :
                   data_bank_rdata[1][3]) : 32'b0;

assign rd_addr = {buff_tag, buff_index, buff_offset};

assign wr_addr = (buff_way == 0) ?
                 {tagv_rdata[0], tagv_addr[0], 4'b0}:
                 {tagv_rdata[1], tagv_addr[1], 4'b0};

assign wr_data = cache_rdata;

reg        buff_op;
reg [7:0]  buff_index;
reg [19:0] buff_tag;
reg [3:0]  buff_offset;
reg [3:0]  buff_wstrb;
reg [31:0] buff_wdata;

always @(posedge clk)
begin
    if(~resetn)
        begin
            buff_op <= 0;
            buff_index <= 0;
            buff_tag <= 0;
            buff_offset <= 0;
            buff_wstrb  <= 0;
            buff_wdata  <= 0;
        end
    else if(next_state == LOOKUP)
        begin
            buff_op <= op;
            buff_index <= index;
            buff_tag <= tag;
            buff_offset <= offset;
            buff_wstrb  <= wstrb;
            buff_wdata  <= wdata;
        end
end

reg        buff_way;
always @(posedge clk)
    begin
        if(~resetn)
            buff_way <= 0;
        else if(curr_state == LOOKUP && cache_hit)
            buff_way <= way0_hit ? 1'b0 : 1'b1;
        else if(curr_state == LOOKUP && ~cache_hit)
            buff_way <= replace_way;
    end

//测试程序没有用到
assign rd_type  = 3'b100;
assign wr_type  = 3'b100;
assign wr_wstrb = 4'hf;

//for ret cnt, 用于依次读出一个cache行的每个32位数据
reg [1:0] ret_cnt;
always@(posedge clk)
begin
    if(~resetn)
        ret_cnt <= 2'b0;
    else if(ret_valid && ret_last)
        ret_cnt <= 2'b0;
    else if(ret_valid)
        ret_cnt <= ret_cnt + 2'b1;
end

//for hit write
wire hit_write = (curr_state == LOOKUP && wb_next_state == WB_WRITE) ||
                 (wb_curr_state == WB_WRITE) || 
                 (curr_state == REFILL && buff_op == 1 && ret_last && ret_valid);

endmodule