/*  from soc_lite_top.v
mycpu_top u_cpu(
    .aclk      (cpu_clk       ),
    .aresetn   (cpu_resetn    ),   //low active

    .arid      (cpu_arid      ),
    .araddr    (cpu_araddr    ),
    .arlen     (cpu_arlen     ),
    .arsize    (cpu_arsize    ),
    .arburst   (cpu_arburst   ),
    .arlock    (cpu_arlock    ),
    .arcache   (cpu_arcache   ),
    .arprot    (cpu_arprot    ),
    .arvalid   (cpu_arvalid   ),
    .arready   (cpu_arready   ),
                
    .rid       (cpu_rid       ),
    .rdata     (cpu_rdata     ),
    .rresp     (cpu_rresp     ),
    .rlast     (cpu_rlast     ),
    .rvalid    (cpu_rvalid    ),
    .rready    (cpu_rready    ),
               
    .awid      (cpu_awid      ),
    .awaddr    (cpu_awaddr    ),
    .awlen     (cpu_awlen     ),
    .awsize    (cpu_awsize    ),
    .awburst   (cpu_awburst   ),
    .awlock    (cpu_awlock    ),
    .awcache   (cpu_awcache   ),
    .awprot    (cpu_awprot    ),
    .awvalid   (cpu_awvalid   ),
    .awready   (cpu_awready   ),
    
    .wid       (cpu_wid       ),
    .wdata     (cpu_wdata     ),
    .wstrb     (cpu_wstrb     ),
    .wlast     (cpu_wlast     ),
    .wvalid    (cpu_wvalid    ),
    .wready    (cpu_wready    ),
    
    .bid       (cpu_bid       ),
    .bresp     (cpu_bresp     ),
    .bvalid    (cpu_bvalid    ),
    .bready    (cpu_bready    ),

    //debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
*/

module mycpu_top(
    input           aclk,
    input           aresetn,

    //ar 读请求通道

    output [3:0]    arid,           //读请求ID号                           取指0，取数1        
    output [31:0]   araddr,         //读请求的地址                          
    output [7:0]    arlen,          //请求传输长度(数据传输拍数)            固定为0
    output [2:0]    arsize,         //请求传输大小(数据传输每拍的字节数)     
    output [1:0]    arburst,        //传输类型                             固定为2'b01
    output [1:0]    arlock,         //原子锁                               
    output [3:0]    arcache,        //CACHE属性
    output [2:0]    arprot,         //保护属性
    output          arvalid,        //读请求地址握手(读请求地址有效)
    input           arready,        //读请求地址握手(slave端准备好接收地址)

    //r  读响应通道
    input  [3:0]    rid,            //读请求的ID号，同一请求的rid=arid
    input  [31:0]   rdata,          //读请求的读回数据
    input  [1:0]    rresp,          //本次读请求是否成功完成(可忽略)
    input           rlast,          //本次读请求最后一拍指示信号(可忽略)
    input           rvalid,         //读请求数据握手(读请求数据有效)
    output          rready,         //读请求数据握手(master端准备好接收数据)

    //aw  写请求通道
    output [3:0]    awid,           //写请求的ID号
    output [31:0]   awaddr,         //写请求的地址
    output [7:0]    awlen,          //请求传输的长度
    output [2:0]    awsize,         //请求传输的大小(数据传输每拍的字节数)
    output [1:0]    awburst,        //传输类型
    output [1:0]    awlock,         //原子锁
    output [1:0]    awcache,        //CACHE属性
    output [2:0]    awprot,         //保护属性
    output          awvalid,        //写请求地址握手(写请求地址有效)
    input           awready,        //写请求地址握手(slave端准备好接收地址)

    //w  写数据通道
    output [3:0]    wid,            //写请求的ID号
    output [31:0]   wdata,          //写请求的写数据
    output [3:0]    wstrb,          //字节选通位
    output          wlast,          //本次写请求的最后一拍数据的指示信号
    output          wvalid,         //写请求数据握手(写请求数据有效)
    input           wready,         //写请求数据握手(slave端准备好接收数据)

    //b  写响应通道
    input  [3:0]    bid,            //bid = wid = awid
    input  [1:0]    bresp,          //本次写请求是否成功完成
    input           bvalid,         //写请求响应握手(写请求响应有效)
    output          bready,         //写请求响应握手(master端准备好接收写响应)

    // debug
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_we ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

wire        cpu_inst_req;
wire        cpu_inst_wr;
wire [1:0]  cpu_inst_size;
wire [31:0] cpu_inst_addr;
wire [3:0]  cpu_inst_wstrb;
wire [31:0] cpu_inst_wdata;
wire        cpu_inst_addr_ok;
wire        cpu_inst_data_ok;
wire [31:0] cpu_inst_rdata;

wire        cpu_data_req;
wire        cpu_data_wr;
wire [1:0]  cpu_data_size;
wire [31:0] cpu_data_addr;
wire [3:0]  cpu_data_wstrb;
wire [31:0] cpu_data_wdata;
wire        cpu_data_addr_ok;
wire        cpu_data_data_ok;
wire [31:0] cpu_data_rdata;

cpu_bridge_axi u_cpu_bridge_axi(
    .clk        (aclk),
    .resetn     (aresetn),

    //inst sram
    .inst_req       (cpu_inst_req),
    .inst_wr        (cpu_inst_wr),
    .inst_size      (cpu_inst_size),
    .inst_addr      (cpu_inst_addr),
    .inst_wstrb     (cpu_inst_wstrb),
    .inst_wdata     (cpu_inst_wdata),
    .inst_addr_ok   (cpu_inst_addr_ok),
    .inst_data_ok   (cpu_inst_data_ok),
    .inst_rdata     (cpu_inst_rdata),

    //data sram
    .data_req       (cpu_data_req),
    .data_wr        (cpu_data_wr),
    .data_size      (cpu_data_size),
    .data_addr      (cpu_data_addr),
    .data_wstrb     (cpu_data_wstrb),
    .data_wdata     (cpu_data_wdata),
    .data_addr_ok   (cpu_data_addr_ok),
    .data_data_ok   (cpu_data_data_ok),
    .data_rdata     (cpu_data_rdata),

    //ar
    .arid           (arid),
    .araddr         (araddr),
    .arlen          (arlen),
    .arsize         (arsize),
    .arburst        (arburst),
    .arlock         (arlock),
    .arcache        (arcache),
    .arprot         (arprot),
    .arvalid        (arvalid),
    .arready        (arready),
    
    //r
    .rid            (rid),
    .rdata          (rdata),
    .rresp          (rresp),
    .rlast          (rlast),
    .rvalid         (rvalid),
    .rready         (rready),
    
    //aw
    .awid           (awid),
    .awaddr         (awaddr),
    .awlen          (awlen),
    .awsize         (awsize),
    .awburst        (awburst),
    .awlock         (awlock),
    .awcache        (awcache),
    .awprot         (awprot),
    .awvalid        (awvalid),
    .awready        (awready),
    
    //w
    .wid            (wid),
    .wdata          (wdata),
    .wstrb          (wstrb),
    .wlast          (wlast),
    .wvalid         (wvalid),
    .wready         (wready),
    
    //b
    .bid            (bid),
    .bresp          (bresp),
    .bvalid         (bvalid),
    .bready         (bready)
);

mycpu u_cpu(
    .clk              (aclk),
    .resetn           (aresetn),  //low active

    // inst sram
    .inst_sram_req    (cpu_inst_req),
    .inst_sram_wr     (cpu_inst_wr),
    .inst_sram_size   (cpu_inst_size),
    .inst_sram_wstrb  (cpu_inst_wstrb),
    .inst_sram_addr   (cpu_inst_addr),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_addr_ok(cpu_inst_addr_ok),
    .inst_sram_data_ok(cpu_inst_data_ok),
    .inst_sram_rdata  (cpu_inst_rdata),

    // data sram
    .data_sram_req    (cpu_data_req),
    .data_sram_wr     (cpu_data_wr),
    .data_sram_size   (cpu_data_size),
    .data_sram_wstrb  (cpu_data_wstrb),
    .data_sram_addr   (cpu_data_addr),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_addr_ok(cpu_data_addr_ok),
    .data_sram_data_ok(cpu_data_data_ok),
    .data_sram_rdata  (cpu_data_rdata),

    //debug interface
    .debug_wb_pc      (debug_wb_pc),
    .debug_wb_rf_we  (debug_wb_rf_we),
    .debug_wb_rf_wnum (debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

// tlb my_tlb(
//     .clk
//     .s0_vppn
//     .s0_va_bit12
//     .s0_asid
//     .s0_found
//     .s0_index
//     .s0_ppn
//     .s0_ps
//     .s0_plv
//     .s0_mat
//     .s0_d
//     .s0_v

//     .s1_vppn
//     .s1_va_bit12
//     .s1_asid
//     .s1_index
//     .s1_ppn
//     .s1_ps
//     .s1_plv
//     .s1_mat
//     .s1_d
//     .s1_v

//     .invtlb_valid
//     .invtlb_op
    
//     .we
//     .w_index
//     .w_e
//     .w_vppn
//     .w_ps
//     .w_asid
//     .w_g
    
//     .w_ppn0
//     .w_plv0
//     .w_mat0
//     .w_d0
//     .w_v0

//     .w_ppn1
//     .w_plv1
//     .w_mat1
//     .w_d1
//     .w_v1

//     .r_index
//     .r_e
//     .r_vppn
//     .r_ps
//     .r_asid
//     .r_g

//     .r_ppn0
//     .r_plv0
//     .r_mat0
//     .r_d0
//     .r_v0

//     .r_ppn1
//     .r_plv1
//     .r_mat1
//     .r_d1
//     .r_v1
// );


endmodule