module branchpre (
    input clk,
    input reset,
    input [31:0] inst,
    input [31:0] pc,
    input we,
    input in_b,
    output [31:0] pre_pc,
    output out_b
);
    reg [1:0] reg_pre;
    wire [1:0] wir_pre;
    wire is_16;
    wire is_26; 

    assign wir_pre = we? {in_b,reg_pre[1]}:reg_pre;
    always @(posedge clk) begin
        if(reset)
            reg_pre <= 2'b11;
        else if(we)
            reg_pre <= {in_b,reg_pre[1]};
    end
    assign is_16 = inst[31:27] == 5'b01011; 
    assign is_26 = inst[31:27] == 5'b01010;

    assign out_b = (is_16|is_26)?
                   (wir_pre==2'b11 || wir_pre==2'b10)?1'b1:1'b0
                   :1'b0;
    
    assign pre_pc = (out_b)? 
                    is_16? pc + {{14{inst[25]}},inst[25:10],2'b0} :
                    is_26? pc + {{4{inst[9]}},inst[9:0],inst[25:10],2'b0} : 
                    pc+4 : pc+4;
    
endmodule