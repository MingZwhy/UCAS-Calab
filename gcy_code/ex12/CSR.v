`define CSR_CRMD 14'h0
`define CSR_PRMD 14'h1
`define CSR_EUEN 14'h2
`define CSR_ECFG 14'h4
`define CSR_ESTAT 14'h5
`define CSR_ERA 14'h6
`define CSR_BADV 14'h7
`define CSR_EENTRY 14'hc
`define CSR_SAVE0 14'h30   
`define CSR_SAVE1 14'h31
`define CSR_SAVE2 14'h32
`define CSR_SAVE3 14'h33
`define CSR_TID 14'h40
`define CSR_TCFG 14'h41
`define CSR_TVAL 14'h42
`define CSR_TICLR 14'h44

`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_PIE 2
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2
`define CSR_ECFG_LIE 12:0
`define TICLR 9'h44
`define CSR_ESTAT_IS10 1:0
`define CSR_TICLR_CLR 0
`define CSR_ERA_PC 31:0
`define CSR_EENTRY_VA 31:6
`define CSR_SAVE_DATA 31:0
`define CSR_TID_TID 31:0
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2
`define CSR_TCFG_INITVAL 31:2
module csrCXK (
    input clk,
    input reset,
    input csr_re,
    input [13:0] csr_num,
    output [31:0] csr_rvalue,
    input csr_we,
    input [31:0] csr_wmask,
    input [31:0] csr_wvalue,
    input ertn_flush,
    input wb_ex
);

reg [1:0] csr_crmd_plv;
reg csr_crmd_ie;

reg [1:0] csr_prmd_pplv;
reg csr_prmd_pie;

reg [12:0] csr_ecfg_lie;

reg [12:0] csr_estat_is;
reg [5:0] csr_estat_ecode;
reg [8:0] csr_estat_esubcode;

reg [31:0] csr_era_pc;

reg [31:0] csr_badv_vaddr;

reg [25:0] csr_eentry_va;

reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;

reg [31:0] csr_tid_tid;

reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg [29:0] csr_tcfg_initval;

wire ipi_int_in =1'b0;
wire [5:0] wb_ecode;
wire [8:0] wb_esubcode;
wire [31:0] wb_pc;
wire [31:0] coreid_in;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg [31:0] timer_cnt;
wire csr_ticlr_clr;
wire [31:0]hw_int_in = 32'b0;


//CRMD域的设置
always @(posedge clk) 
begin
    if (reset)
    begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie <= 1'b0;
    end
    else if (wb_ex)
    begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie <= 1'b0;
    end
    else if (ertn_flush)
    begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie <= csr_prmd_pie;
    end
    else if (csr_we && csr_num==`CSR_CRMD)
    begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
                        |~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wvalue[`CSR_CRMD_PIE]
                       |~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
    end
end

//PRMD域的设置
always @(posedge clk) 
begin
    if(reset)
    begin
        csr_prmd_pplv<=2'b0;
        csr_prmd_pie<=1'b0;
    end
    else if (wb_ex) 
    begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if (csr_we && csr_num==`CSR_PRMD) 
    begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
                        | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
        csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
                        | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
    end
end

//ECFG域的设置
always @(posedge clk) 
begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num==`CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wvalue[`CSR_ECFG_LIE]
                        | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
end

//ESTAT域的设置
always @(posedge clk) 
begin
    if (reset)
        csr_estat_is[12:0] <= 13'b0;
    else
    begin 
        if (csr_we && csr_num==`CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
                            | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
    csr_estat_is[9:2] <= hw_int_in[7:0];
    csr_estat_is[10] <= 1'b0;
    if (timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;
    csr_estat_is[12] <= ipi_int_in;
    end
end

always @(posedge clk) 
begin
    if(reset)
    begin
        csr_estat_ecode <= 6'h0b;
        csr_estat_esubcode <= 9'b0;
    end
    /*else if (wb_ex) 
    begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end*/
end

//ERA域的设置
always @(posedge clk) 
begin
    if(reset)
        csr_era_pc <= 32'b0;
    //else if (wb_ex)
     //   csr_era_pc <= wb_pc;
    else if (csr_we && csr_num==`CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]
                    | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
end

//BADV域的设置
//assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
/*always @(posedge clk) 
begin
    if (wb_ex && wb_ex_addr_err)
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADE &&wb_esubcode==`ESUBCODE_ADEF) ? 
                            wb_pc : wb_vaddr;
end
*/
//EENTRY域的设置
always @(posedge clk) 
begin
    if(reset)
        csr_eentry_va <= 26'b0;
    else if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
                        | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
end

//SAVE域的设置
always @(posedge clk) 
begin
    if(reset)
    begin
        csr_save0_data <= 32'b0;
        csr_save1_data <= 32'b0;
        csr_save2_data <= 32'b0;
        csr_save3_data <= 32'b0;
    end
    if (csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
end

//TID域的设置
always @(posedge clk)
begin
    if (reset)
        csr_tid_tid <= coreid_in;
    else if (csr_we && csr_num==`CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
                    | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
end

//TCFG域的设置
always @(posedge clk) 
begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
                       | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
    if (csr_we && csr_num==`CSR_TCFG) 
    begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
                        | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]
                        | ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
    end
end

//TVAL域的设置
assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]
                        | ~csr_wmask[31:0]&{csr_tcfg_initval,
                        csr_tcfg_periodic, csr_tcfg_en};
always @(posedge clk) 
begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) 
    begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
                timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval = timer_cnt[31:0];

//TICLR域的设置
assign csr_ticlr_clr = 1'b0;

//CSR读出逻辑
wire [31:0] csr_crmd_rvalue = {29'b1, csr_crmd_ie, csr_crmd_plv};
wire [31:0] csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
wire [31:0] csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
wire [31:0] csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};
wire [31:0] csr_era_rvalue  = csr_era_pc;
wire [31:0] csr_badv_rvalue = csr_badv_vaddr;
wire [31:0] csr_eentry_rvalue = {csr_eentry_va,6'b0};
wire [31:0] csr_save0_rvalue = csr_save0_data;
wire [31:0] csr_save1_rvalue = csr_save1_data;
wire [31:0] csr_save2_rvalue = csr_save2_data;
wire [31:0] csr_save3_rvalue = csr_save3_data;
wire [31:0] csr_tid_rvalue   = csr_tid_tid;
wire [31:0] csr_tcfg_rvalue  = {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};
wire [31:0] csr_tval_rvalue  = csr_tval;
wire [31:0] csr_ticlr_rvalue = {31'b0,csr_ticlr_clr}; 

assign csr_rvalue = {32{csr_num==`CSR_CRMD}} & csr_crmd_rvalue
                  | {32{csr_num==`CSR_PRMD}} & csr_prmd_rvalue
                //  | {32{csr_num==`CSR_ECFG}} & csr_ecfg_rvalue
                  | {32{csr_num==`CSR_ESTAT}} & csr_estat_rvalue
                  | {32{csr_num==`CSR_ERA}} & csr_era_rvalue
             //     | {32{csr_num==`CSR_BADV}} & csr_badv_rvalue
                  | {32{csr_num==`CSR_EENTRY}} & csr_eentry_rvalue
                  | {32{csr_num==`CSR_SAVE0}} & csr_save0_rvalue
                  | {32{csr_num==`CSR_SAVE1}} & csr_save1_rvalue
                  | {32{csr_num==`CSR_SAVE2}} & csr_save2_rvalue
                  | {32{csr_num==`CSR_SAVE3}} & csr_save3_rvalue
            /*      | {32{csr_num==`CSR_TID}} & csr_tid_rvalue
                  | {32{csr_num==`CSR_TCFG}} & csr_tcfg_rvalue
                  | {32{csr_num==`CSR_TVAL}} & csr_tval_rvalue*/
                  | {32{csr_num==`CSR_TICLR}} & csr_ticlr_rvalue;
endmodule