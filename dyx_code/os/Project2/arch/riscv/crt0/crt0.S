#include <asm.h>

.section ".entry_function","ax"
ENTRY(_start)

    /* TODO: [p1-task3] setup C runtime environment for the user program */
    la s2,__bss_start
    la s3,__BSS_END__
    li s4,0

T0:
    sw s4,0(s2)
    addi s2,s2,4
    blt s2,s3,T0

    /* TODO: [p1-task3] enter main function */
    addi sp, sp, -16
    sd ra, 8(sp) # 
    
    
    call main

    /* TODO: [p1-task3] finish task and return to the kernel */
    /* NOTE: You need to replace this with new mechanism in p3-task2! */
    ld ra, 8(sp) # 
    
    addi sp, sp, 16; # sp = t1 + imm
    
    jalr a1, (ra)
    
// while(1) loop, unreachable here
loop:
    wfi
    j loop

END(_start)
