module tlb
#(
    parameter TLBNUM = 16
    // $clog2(16) = 4
)
(
    input  wire             clk,
    //input  wire             resetn,       //tlb_top hasn't this signal

    /* TLB compare part
    *  -------------------------------------------------
    *  |       VPPN        |   PS   | G |   ASID   | E |         
    *  -------------------------------------------------
    * 30                  12       11  10         1   0
    *
    * E:     (tlb_e)     为1表示所在TLB表项非空，可以参与查找匹配
    * ASID:  (tlb_asid)  地址空间标识，用于区分不同进程中的同样的虚地址
    * G:     (tlb_g)     全局标志位，当g为1时为不进行asid一致性的检查
    * PS：   (tlb_ps)    页大小 --> 指定该页表项存放的页大小 (12-->4KB, 22-->4MB)
    * VPPN:  (tlb_vppn)  虚双页号，虚页号的最低位不需要存放在TLB中(被查找虚页号最低位决定奇数号/偶数号)
    */

    /* TLB phys_exchange part
    *  ------------------------------------------------------
    *  |       PPN0        |   PLV0   |   MAT0   | D0 | V0 |         
    *  -----------------------------------------------------
    *  |       PPN1        |   PLV1   |   MAT1   | D1 | V1 |         
    *  ----------------------------------------------------
    * 23                  4          3          2    1   0
    *
    * v:     (tlb_v)     为1表明该表项是有效的且被访问过的
    * d:     (tlb_d)     为1表明该页表项所对应的地址范围已经有脏数据
    * mat:   (tlb_mat)   存储访问类型
    * plv：  (tlb_plv)   该页表项对应的特权等级
    * ppn:   (tlb_ppn)   物理页号(20位)
    */

    //search port 0 (for fetch)
    input  wire [18:0]                  s0_vppn,
    input  wire                         s0_va_bit12,        
    input  wire [9:0]                   s0_asid,
    output wire                         s0_found,
    output wire [$clog2(TLBNUM)-1:0]    s0_index,
    output wire [19:0]                  s0_ppn,
    output wire [5:0]                   s0_ps,
    output wire [1:0]                   s0_plv,
    output wire [1:0]                   s0_mat,
    output wire                         s0_d,
    output wire                         s0_v,

    // search port 1 (for load/store)
    input  wire [18:0]                  s1_vppn,
    input  wire                         s1_va_bit12,      
    input  wire [9:0]                   s1_asid,
    output wire                         s1_found,
    output wire [$clog2(TLBNUM)-1:0]    s1_index,
    output wire [19:0]                  s1_ppn,
    output wire [5:0]                   s1_ps,
    output wire [1:0]                   s1_plv,
    output wire [1:0]                   s1_mat,
    output wire                         s1_d,
    output wire                         s1_v,

    // invtlb opcode
    input  wire                         invtlb_valid,
    input  wire [4:0]                   invtlb_op,

    // write port
    input  wire                         we,  //w(rite) e(nable)
    input  wire [$clog2(TLBNUM)-1:0]    w_index,
    input  wire                         w_e,
    input  wire [18:0]                  w_vppn,
    input  wire [5:0]                   w_ps,
    input  wire [9:0]                   w_asid,
    input  wire                         w_g,

    input  wire [19:0]                  w_ppn0,
    input  wire [1:0]                   w_plv0,
    input  wire [1:0]                   w_mat0,
    input  wire                         w_d0,
    input  wire                         w_v0,

    input  wire [19:0]                  w_ppn1,
    input  wire [1:0]                   w_plv1,
    input  wire [1:0]                   w_mat1,
    input  wire                         w_d1,
    input  wire                         w_v1,

    //read port
    input  wire [$clog2(TLBNUM)-1:0]    r_index,
    output wire                         r_e,
    output wire [18:0]                  r_vppn,
    output wire [5:0]                   r_ps,
    output wire [9:0]                   r_asid,
    output wire                         r_g,

    output wire [19:0]                  r_ppn0,
    output wire [1:0]                   r_plv0,
    output wire [1:0]                   r_mat0,
    output wire                         r_d0,
    output wire                         r_v0,

    output wire [19:0]                  r_ppn1,
    output wire [1:0]                   r_plv1,
    output wire [1:0]                   r_mat1,
    output wire                         r_d1,
    output wire                         r_v1
);

reg [TLBNUM-1:0]    tlb_e;
reg [TLBNUM-1:0]    tlb_ps4MB;  //pagesize 1:4MB, 0:4KB
reg [18:0]          tlb_vppn    [TLBNUM-1:0];
//reg [5:0]           tlb_ps      [TLBNUM-1:0];     //no need, tlb_ps4MB instead
reg [9:0]           tlb_asid    [TLBNUM-1:0];
reg                 tlb_g       [TLBNUM-1:0];
reg [19:0]          tlb_ppn0    [TLBNUM-1:0];
reg [1:0]           tlb_plv0    [TLBNUM-1:0];
reg [1:0]           tlb_mat0    [TLBNUM-1:0];
reg                 tlb_d0      [TLBNUM-1:0];
reg                 tlb_v0      [TLBNUM-1:0];
reg [19:0]          tlb_ppn1    [TLBNUM-1:0];
reg [1:0]           tlb_plv1    [TLBNUM-1:0];
reg [1:0]           tlb_mat1    [TLBNUM-1:0];
reg                 tlb_d1      [TLBNUM-1:0];
reg                 tlb_v1      [TLBNUM-1:0];

/*
match requirement1: 
if pagesize is 4MB (tlb_ps4MB[0] == 1), then only need match vppn[18:10]
else pagesize is 4KB, then need match vppn[18:0]

match requirement2:
if global, then needn't match asid
else tlb_g[0] == 1, then need match asis
*/

// port 0 (for fetch)
wire [TLBNUM-1:0] match0;

assign match0[0] = (s0_vppn[18:10] == tlb_vppn[0][18:10])
                && (tlb_ps4MB[0] || s0_vppn[9:0] == tlb_vppn[0][9:0])
                && ((s0_asid == tlb_asid[0]) || tlb_g[0]);

assign match0[1] = (s0_vppn[18:10] == tlb_vppn[1][18:10])
                && (tlb_ps4MB[1] || s0_vppn[9:0] == tlb_vppn[1][9:0])
                && ((s0_asid == tlb_asid[1]) || tlb_g[1]);
            
assign match0[2] = (s0_vppn[18:10] == tlb_vppn[2][18:10])
                && (tlb_ps4MB[2] || s0_vppn[9:0] == tlb_vppn[2][9:0])
                && ((s0_asid == tlb_asid[2]) || tlb_g[2]);

assign match0[3] = (s0_vppn[18:10] == tlb_vppn[3][18:10])
                && (tlb_ps4MB[3] || s0_vppn[9:0] == tlb_vppn[3][9:0])
                && ((s0_asid == tlb_asid[3]) || tlb_g[3]);

assign match0[4] = (s0_vppn[18:10] == tlb_vppn[4][18:10])
                && (tlb_ps4MB[4] || s0_vppn[9:0] == tlb_vppn[4][9:0])
                && ((s0_asid == tlb_asid[4]) || tlb_g[4]);

assign match0[5] = (s0_vppn[18:10] == tlb_vppn[5][18:10])
                && (tlb_ps4MB[5] || s0_vppn[9:0] == tlb_vppn[5][9:0])
                && ((s0_asid == tlb_asid[5]) || tlb_g[5]);
            
assign match0[6] = (s0_vppn[18:10] == tlb_vppn[6][18:10])
                && (tlb_ps4MB[6] || s0_vppn[9:0] == tlb_vppn[6][9:0])
                && ((s0_asid == tlb_asid[6]) || tlb_g[6]);

assign match0[7] = (s0_vppn[18:10] == tlb_vppn[7][18:10])
                && (tlb_ps4MB[7] || s0_vppn[9:0] == tlb_vppn[7][9:0])
                && ((s0_asid == tlb_asid[7]) || tlb_g[7]);

assign match0[8] = (s0_vppn[18:10] == tlb_vppn[8][18:10])
                && (tlb_ps4MB[8] || s0_vppn[9:0] == tlb_vppn[8][9:0])
                && ((s0_asid == tlb_asid[8]) || tlb_g[8]);

assign match0[9] = (s0_vppn[18:10] == tlb_vppn[9][18:10])
                && (tlb_ps4MB[9] || s0_vppn[9:0] == tlb_vppn[9][9:0])
                && ((s0_asid == tlb_asid[9]) || tlb_g[9]);
            
assign match0[10] = (s0_vppn[18:10] == tlb_vppn[10][18:10])
                && (tlb_ps4MB[10] || s0_vppn[9:0] == tlb_vppn[10][9:0])
                && ((s0_asid == tlb_asid[10]) || tlb_g[10]);

assign match0[11] = (s0_vppn[18:10] == tlb_vppn[11][18:10])
                && (tlb_ps4MB[11] || s0_vppn[9:0] == tlb_vppn[11][9:0])
                && ((s0_asid == tlb_asid[11]) || tlb_g[11]);

assign match0[12] = (s0_vppn[18:10] == tlb_vppn[12][18:10])
                && (tlb_ps4MB[12] || s0_vppn[9:0] == tlb_vppn[12][9:0])
                && ((s0_asid == tlb_asid[12]) || tlb_g[12]);

assign match0[13] = (s0_vppn[18:10] == tlb_vppn[13][18:10])
                && (tlb_ps4MB[13] || s0_vppn[9:0] == tlb_vppn[13][9:0])
                && ((s0_asid == tlb_asid[13]) || tlb_g[13]);

assign match0[14] = (s0_vppn[18:10] == tlb_vppn[14][18:10])
                && (tlb_ps4MB[14] || s0_vppn[9:0] == tlb_vppn[14][9:0])
                && ((s0_asid == tlb_asid[14]) || tlb_g[14]);

assign match0[15] = (s0_vppn[18:10] == tlb_vppn[15][18:10])
                && (tlb_ps4MB[15] || s0_vppn[9:0] == tlb_vppn[15][9:0])
                && ((s0_asid == tlb_asid[15]) || tlb_g[15]);

// port 1 (for load/store)
wire [TLBNUM-1:0] match1;

assign match1[0] = (s1_vppn[18:10] == tlb_vppn[0][18:10])
                && (tlb_ps4MB[0] || s1_vppn[9:0] == tlb_vppn[0][9:0])
                && ((s1_asid == tlb_asid[0]) || tlb_g[0]);

assign match1[1] = (s1_vppn[18:10] == tlb_vppn[1][18:10])
                && (tlb_ps4MB[1] || s1_vppn[9:0] == tlb_vppn[1][9:0])
                && ((s1_asid == tlb_asid[1]) || tlb_g[1]);
            
assign match1[2] = (s1_vppn[18:10] == tlb_vppn[2][18:10])
                && (tlb_ps4MB[2] || s1_vppn[9:0] == tlb_vppn[2][9:0])
                && ((s1_asid == tlb_asid[2]) || tlb_g[2]);

assign match1[3] = (s1_vppn[18:10] == tlb_vppn[3][18:10])
                && (tlb_ps4MB[3] || s1_vppn[9:0] == tlb_vppn[3][9:0])
                && ((s1_asid == tlb_asid[3]) || tlb_g[3]);

assign match1[4] = (s1_vppn[18:10] == tlb_vppn[4][18:10])
                && (tlb_ps4MB[4] || s1_vppn[9:0] == tlb_vppn[4][9:0])
                && ((s1_asid == tlb_asid[4]) || tlb_g[4]);

assign match1[5] = (s1_vppn[18:10] == tlb_vppn[5][18:10])
                && (tlb_ps4MB[5] || s1_vppn[9:0] == tlb_vppn[5][9:0])
                && ((s1_asid == tlb_asid[5]) || tlb_g[5]);
            
assign match1[6] = (s1_vppn[18:10] == tlb_vppn[6][18:10])
                && (tlb_ps4MB[6] || s1_vppn[9:0] == tlb_vppn[6][9:0])
                && ((s1_asid == tlb_asid[6]) || tlb_g[6]);

assign match1[7] = (s1_vppn[18:10] == tlb_vppn[7][18:10])
                && (tlb_ps4MB[7] || s1_vppn[9:0] == tlb_vppn[7][9:0])
                && ((s1_asid == tlb_asid[7]) || tlb_g[7]);

assign match1[8] = (s1_vppn[18:10] == tlb_vppn[8][18:10])
                && (tlb_ps4MB[8] || s1_vppn[9:0] == tlb_vppn[8][9:0])
                && ((s1_asid == tlb_asid[8]) || tlb_g[8]);

assign match1[9] = (s1_vppn[18:10] == tlb_vppn[9][18:10])
                && (tlb_ps4MB[9] || s1_vppn[9:0] == tlb_vppn[9][9:0])
                && ((s1_asid == tlb_asid[9]) || tlb_g[9]);
            
assign match1[10] = (s1_vppn[18:10] == tlb_vppn[10][18:10])
                && (tlb_ps4MB[10] || s1_vppn[9:0] == tlb_vppn[10][9:0])
                && ((s1_asid == tlb_asid[10]) || tlb_g[10]);

assign match1[11] = (s1_vppn[18:10] == tlb_vppn[11][18:10])
                && (tlb_ps4MB[11] || s1_vppn[9:0] == tlb_vppn[11][9:0])
                && ((s1_asid == tlb_asid[11]) || tlb_g[11]);

assign match1[12] = (s1_vppn[18:10] == tlb_vppn[12][18:10])
                && (tlb_ps4MB[12] || s1_vppn[9:0] == tlb_vppn[12][9:0])
                && ((s1_asid == tlb_asid[12]) || tlb_g[12]);

assign match1[13] = (s1_vppn[18:10] == tlb_vppn[13][18:10])
                && (tlb_ps4MB[13] || s1_vppn[9:0] == tlb_vppn[13][9:0])
                && ((s1_asid == tlb_asid[13]) || tlb_g[13]);

assign match1[14] = (s1_vppn[18:10] == tlb_vppn[14][18:10])
                && (tlb_ps4MB[14] || s1_vppn[9:0] == tlb_vppn[14][9:0])
                && ((s1_asid == tlb_asid[14]) || tlb_g[14]);

assign match1[15] = (s1_vppn[18:10] == tlb_vppn[15][18:10])
                && (tlb_ps4MB[15] || s1_vppn[9:0] == tlb_vppn[15][9:0])
                && ((s1_asid == tlb_asid[15]) || tlb_g[15]);

/*---------------------------------s0,s1 output----------------------------------*/

// whether found or not up to if match all zero
assign s0_found = |match0[TLBNUM-1:0];
assign s1_found = |match1[TLBNUM-1:0];


assign s0_index = match0[0]  ? 4'b0000 :
                  match0[1]  ? 4'b0001 :
                  match0[2]  ? 4'b0010 :
                  match0[3]  ? 4'b0011 :
                  match0[4]  ? 4'b0100 :
                  match0[5]  ? 4'b0101 :
                  match0[6]  ? 4'b0110 :
                  match0[7]  ? 4'b0111 :
                  match0[8]  ? 4'b1000 :
                  match0[9]  ? 4'b1001 :
                  match0[10] ? 4'b1010 :
                  match0[11] ? 4'b1011 :
                  match0[12] ? 4'b1100 :
                  match0[13] ? 4'b1101 :
                  match0[14] ? 4'b1110 :
                  match0[15] ? 4'b1111 : 4'b0000;

assign s1_index = match1[0]  ? 4'b0000 :
                  match1[1]  ? 4'b0001 :
                  match1[2]  ? 4'b0010 :
                  match1[3]  ? 4'b0011 :
                  match1[4]  ? 4'b0100 :
                  match1[5]  ? 4'b0101 :
                  match1[6]  ? 4'b0110 :
                  match1[7]  ? 4'b0111 :
                  match1[8]  ? 4'b1000 :
                  match1[9]  ? 4'b1001 :
                  match1[10] ? 4'b1010 :
                  match1[11] ? 4'b1011 :
                  match1[12] ? 4'b1100 :
                  match1[13] ? 4'b1101 :
                  match1[14] ? 4'b1110 :
                  match1[15] ? 4'b1111 : 4'b0000;

assign s0_ppn = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];

assign s1_ppn = (s1_va_bit12 ^ tlb_ps4MB[s1_index]) ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];

assign s0_ps = tlb_ps4MB[s0_index] ? 6'b010110 : 6'b001100;

assign s1_ps = tlb_ps4MB[s1_index] ? 6'b010110 : 6'b001100;

assign s0_plv = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_plv1[s0_index] : tlb_plv0[s0_index];

assign s1_plv = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_plv1[s1_index] : tlb_plv0[s1_index];

assign s0_mat = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_mat1[s0_index] : tlb_mat0[s0_index];

assign s1_mat = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_mat1[s1_index] : tlb_mat0[s1_index];

assign s0_d = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_d1[s0_index] : tlb_d0[s0_index];

assign s1_d = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_d1[s1_index] : tlb_d0[s1_index];

assign s0_v = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_v1[s0_index] : tlb_v0[s0_index];

assign s1_v = (s0_va_bit12 ^ tlb_ps4MB[s0_index]) ? tlb_v1[s1_index] : tlb_v0[s1_index];

/*-------------------------------------------------------------------------------*/

/*-----------------------------------read port------------------------------------*/

//part1

assign r_e = tlb_e[r_index];

assign r_vppn = tlb_vppn[r_index];

assign r_ps = (tlb_ps4MB[r_index]  ? 6'b010110 : 6'b001100);

assign r_asid = tlb_asid[r_index];

assign r_g = tlb_g[r_index];

//part 2

assign r_ppn0 = tlb_ppn0[r_index];
assign r_ppn1 = tlb_ppn1[r_index];

assign r_plv0 = tlb_plv0[r_index];
assign r_plv1 = tlb_plv1[r_index];

assign r_mat0 = tlb_mat0[r_index];
assign r_mat1 = tlb_mat1[r_index];

assign r_d0 = tlb_d0[r_index];
assign r_d1 = tlb_d1[r_index];

assign r_v0 = tlb_v0[r_index];
assign r_v1 = tlb_v1[r_index];

/*---------------------------------------------------------------------------------*/

/*-----------------------------------write port------------------------------------*/

wire if_4MB;
assign if_4MB = (w_ps == 6'b010110);

always @(posedge clk)
    begin
        if(we)
            begin
                tlb_e[w_index]      <= w_e;
                tlb_vppn[w_index]   <= w_vppn;
                tlb_ps4MB[w_index]  <= if_4MB;
                tlb_asid[w_index]   <= w_asid;
                tlb_g[w_index]      <= w_g;

                tlb_ppn0[w_index]   <= w_ppn0;
                tlb_plv0[w_index]   <= w_plv0;
                tlb_mat0[w_index]   <= w_mat0;
                tlb_d0[w_index]     <= w_d0;
                tlb_v0[w_index]     <= w_v0;

                tlb_ppn1[w_index]   <= w_ppn1;
                tlb_plv1[w_index]   <= w_plv1;
                tlb_mat1[w_index]   <= w_mat1;
                tlb_d1[w_index]     <= w_d1;
                tlb_v1[w_index]     <= w_v1;
            end
    end

/*---------------------------------------------------------------------------------*/

endmodule