`define WIDTH_BR_BUS       34
`define WIDTH_FS_TO_DS_BUS 65
`define WIDTH_DS_TO_ES_BUS 234
`define WIDTH_ES_TO_MS_BUS 179
`define WIDTH_MS_TO_WS_BUS 171
`define WIDTH_WS_TO_DS_BUS 55
`define WIDTH_ES_TO_DS_BUS 55
`define WIDTH_MS_TO_DS_BUS 54

`define WIDTH_CSR_NUM 14

//寄存器号
`define CSR_CRMD 14'h0
`define CSR_PRMD 14'h1
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


//CSR分区

//CSR_CRMD
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2:2
`define CSR_CRMD_DA 3:3
`define CSR_CRMD_PG 4:4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7
`define CSR_CRMD_ZERO 31:9

//CSR_PRMD
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2:2
`define CSR_PRMD_ZERO 31:3

//CSR_ECFG
`define CSR_ECFG_LIE 12:0
`define CSR_ECFG_ZERO 31:13

//CSR_ESTAT
`define CSR_ESTAT_IS_SOFT 1:0     
`define CSR_ESTAT_IS_HARD 9:2   
`define CSR_ESTAT_IS_LEFT1 10    
`define CSR_ESTAT_IS_TI 11       
`define CSR_ESTAT_IS_IPI 12       
`define CSR_ESTAT_LEFT2 15:13  
`define CSR_ESTAT_ECODE 21:16  
`define CSR_ESTAT_ESUBCODE 30:22 
`define CSR_ESTAT_ZERO 31  

//CSR_ERA
`define CSR_ERA_PC 31:0

//CSR_BADV
`define CSR_BADV_VADDR 31:0

//CSR_EENTRY
`define CSR_EENTRY_ZERO 5:0
`define CSR_EENTRY_VA 31:6

//CSR_SAVR0-3
`define CSR_SAVE_DATA 31:0

//CSR_TID
`define CSR_TID_TID 31:0

//CSR_TCFG
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIODIC 1
`define CSR_TCFG_INITVAL 31:2

//CSR_TICLR
`define CSR_TICLR_CLR 0
`define CSR_TICLR_ZERO 31:1


//ECODE
`define ECODE_INT 6'h0
`define ECODE_PIL 6'h1
`define ECODE_PIS 6'h2
`define ECODE_PIF 6'h3
`define ECODE_PME 6'h4
`define ECODE_PPI 6'h7
`define ECODE_ADE 6'h8
`define ECODE_ALE 6'h9
`define ECODE_SYS 6'hb
`define ECODE_BRK 6'hc
`define ECODE_INE 6'hd
`define ECODE_IPE 6'he
`define ECODE_FPD 6'hf
`define ECODE_FPE 6'h12

`define ECODE_TLBR 6'h3f

//ESUBCODE
`define ESUBCODE_INT 9'h0
`define ESUBCODE_PIL 9'h0
`define ESUBCODE_PIS 9'h0
`define ESUBCODE_PIF 9'h0
`define ESUBCODE_PME 9'h0
`define ESUBCODE_PPI 9'h0
`define ESUBCODE_ADEF 9'h0
`define ESUBCODE_ADEM 9'h1
`define ESUBCODE_ALE 9'h0
`define ESUBCODE_SYS 9'h0
`define ESUBCODE_BRK 9'h0
`define ESUBCODE_INE 9'h0
`define ESUBCODE_IPE 9'h0
`define ESUBCODE_FPD 9'h0
`define ESUBCODE_FPE 9'h0

`define ESUBCODE_TLBR 9'h0