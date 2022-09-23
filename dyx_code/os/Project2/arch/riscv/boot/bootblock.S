#include <asm/biosdef.h>

// os size location (os_size could be sectors [p1-task3] or bytes [p1-task4])
.equ os_info_loc ,0x502001f8
.equ os_size_loc, 0x502001fc
.equ os_start, 0x50200000
// kernel address (move kernel to here, and jmp here to start kernel)
.equ kernel, 0x50201000
.equ info, 0x53000000
// BIOS function entry (jump here to use BIOS APIs)
.equ bios_func_entry, 0x50150000

.text
.global main

main:
	// fence on all memory and I/O
	fence

	// TODO: [p1-task1] call BIOS to print string "It's bootblock!"
	li a0, BIOS_PUTSTR
	la a1, msg
	call bios_func_entry	
	// TODO: [p1-task2] call BIOS to read kernel in SD card

	li a0, BIOS_SDREAD
	la a1, kernel
	la t0, os_size_loc
	lw a2, 0(t0)
	li a3, 1
	call bios_func_entry

	# addi t0, t0, -4
	# lw a3, 0(t0)
	# li t2, 0x200
	# div a3, a3, t2

	li a0, BIOS_SDREAD
	la a1, info
	la t0, os_info_loc
	lw t0, 0(t0)
	li t1, 512
	div a3, t0, t1
	li a2, 1
	# li a3, 31
	call bios_func_entry


	// TODO: [p1-task4] load task-related arguments and pass them to kernel
	# la s1, os_size_loc # 
	
	# lw t1, 0(s1) # 
	
	// TODO: [p1-task2] jump to kernel to start UCAS-OS
	j kernel

// while(1) --> stop here
stop:
	j stop
	nop

.data

msg: .string "It's a bootloader...\n\r"

