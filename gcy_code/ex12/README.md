*版本 v1.0*

v1.0

本代码完成了ex12任务



信号如下所示：

WB指令：

pc：63-32

gr_we：寄存器写指令64

dest：寄存器写地址69-65

final_result：寄存器写数据101-70

ertn_flush: 102

has_exception: 103 这个也是wb_ex信号



MEM指令：

pc：63-32

gr_we：寄存器写指令64

dest：寄存器写  地址69-65

res_from_mem：寄存器写数据70

ex_result：内存地址102-71

loadop：105-103 三位 load信号符号位，最高位表示是否是全加载，次高位表示是否是半加载，最低位表示是否是符号加载

csr_num：csr编号 119-106

csrw_en：csr写使能 120

csrm_en：掩码使能 121

csr_mask：csr掩码 153-122

csr_inst:是否是csr指令 154

ertn_flush：155

syscall: 156



EX指令：

gr_we：寄存器写指令64

dest：寄存器写地址69-65

res_from_mem：寄存器写数据70

mem_we：内存写指令71

aluop：alu指令83-72

alu_src1：alu参数a115-84

alu_src2：alu参数b147-116

rkd_value：内存写数据179-148

mulop: 00代表无事，01代表mulw  11代表mulhw  10代表mulhwu 181-180

divop：三位，最高位表示是否为除法，次高位表示是否取商or余数，最低位表示是否为有符号数 184-182

loadop：三位 187-185 load信号符号位，最高位表示是否是全加载，次高位表示是否是半加载，最低位表示是否是符号加载

storeop：三位 190-188 store信号符号位，最高位表示是否是store指令，次高位表示是否是全存，最低位表示是否是半存

 csr_num：csr编号 204-191

csrw_en：csr写使能 205

csrm_en：掩码使能 206

csr_mask：csr掩码 238-207

csr_inst: 是否是csr指令 239

ertn_flush：240

syscall: 241



DE指令：

PC：PC的值63-32
