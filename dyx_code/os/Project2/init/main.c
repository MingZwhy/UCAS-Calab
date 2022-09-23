/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  * * * * * * * * * * *
 *            Copyright (C) 2018 Institute of Computing Technology, CAS
 *               Author : Han Shukai (email : hanshukai@ict.ac.cn)
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  * * * * * * * * * * *
 *         The kernel's entry, where most of the initialization work is done.
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  * * * * * * * * * * *
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
 * persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  * * * * * * * * * * */

#include <common.h>
#include <asm.h>
#include <asm/unistd.h>
#include <os/loader.h>
#include <os/irq.h>
#include <os/sched.h>
#include <os/lock.h>
#include <os/kernel.h>
#include <os/task.h>
#include <os/string.h>
#include <os/mm.h>
#include <os/time.h>
#include <sys/syscall.h>
#include <screen.h>
#include <printk.h>
#include <assert.h>
#include <type.h>
#include <csr.h>

extern void ret_from_exception();

// Task info array
task_info_t tasks[TASK_MAXNUM];

static void init_jmptab(void)
{
    volatile long (*(*jmptab))() = (volatile long (*(*))())KERNEL_JMPTAB_BASE;

    jmptab[CONSOLE_PUTSTR]  = (long (*)())port_write;
    jmptab[CONSOLE_PUTCHAR] = (long (*)())port_write_ch;
    jmptab[CONSOLE_GETCHAR] = (long (*)())port_read_ch;
    jmptab[SD_READ]         = (long (*)())sd_read;
    jmptab[QEMU_LOGGING]    = (long (*)())qemu_logging;
    jmptab[SET_TIMER]       = (long (*)())set_timer;
    jmptab[READ_FDT]        = (long (*)())read_fdt;
    jmptab[MOVE_CURSOR]     = (long (*)())screen_move_cursor;
    jmptab[PRINT]           = (long (*)())printk;
    jmptab[YIELD]           = (long (*)())do_scheduler;
    jmptab[MUTEX_INIT]      = (long (*)())do_mutex_lock_init;
    jmptab[MUTEX_ACQ]       = (long (*)())do_mutex_lock_acquire;
    jmptab[MUTEX_RELEASE]   = (long (*)())do_mutex_lock_release;
}
int tasknum; //需要执行的任务个数
char batch[100]; // 批处理
static void init_task_info(void)
{
    // TODO: [p1-task4] Init 'tasks' array via reading app-info sector
    // NOTE: You need to get some related arguments from bootblock first
    int i;
    int location= 0x53000000;
    int info;

    tasknum = 4;
    for (i=0; i<16; i++){
        int *ptr = location;
        info = *ptr;
        tasks[i].bytes = info;
        location += 4;
    }
    // for(i=0; i<16/2; i++){
    //     int *ptr = location;
    //     info = *ptr;
    //     tasks[2*i].loc = info & 0x000000ff;
    //     tasks[2*i].num = (info & 0x0000ff00) >> 8;
    //     tasks[2*i+1].loc = (info & 0x00ff0000) >> 16;
    //     tasks[2*i+1].num = (info & 0xff000000) >> 24;
    //     location  += 4;
    // }
    int programNameAddr = location;
    char *ptr = programNameAddr;
    for(i=0; i<TASK_MAXNUM; i++){
        tasks[i].filename = (char *)programNameAddr;
        while(*ptr != 0){
            ptr += 1;
            programNameAddr += 1;
        }
        ptr += 1;
        programNameAddr += 1;
        if(*ptr == 0xff)
        {
            bios_putstr("go to handle info\n");
            break;
        }
    }
    programNameAddr += 1;
    char *loadbatch = programNameAddr;
    int k = 0;
    while (*loadbatch)
    {
        batch[k++] = *loadbatch;
        loadbatch++;
    }

}



static void init_pcb_stack(
    ptr_t kernel_stack, ptr_t user_stack, ptr_t entry_point,
    pcb_t *pcb)
{
     /* TODO: [p2-task3] initialization of registers on kernel stack
      * HINT: sp, ra, sepc, sstatus
      * NOTE: To run the task in user mode, you should set corresponding bits
      *     of sstatus(SPP, SPIE, etc.).
      */
    regs_context_t *pt_regs =
        (regs_context_t *)(kernel_stack - sizeof(regs_context_t));
        int i;
        for(i = 0; i < 32; i++){
            pt_regs->regs[i] = 0;
        }
        pt_regs->regs[2] = user_stack;
        pt_regs->regs[1] = entry_point;
        //pt_regs->regs[4] = (reg_t)&pcb[0];
        pt_regs->sepc = entry_point;
        pt_regs->sstatus = SR_SIE;
    printl("The kernel stack is at %x\n", kernel_stack);
    printl("The pt_regs is at %x\n", pt_regs);

    /* TODO: [p2-task1] set sp to simulate just returning from switch_to
     * NOTE: you should prepare a stack, and push some values to
     * simulate a callee-saved context.
     */
    switchto_context_t *pt_switchto =
        (switchto_context_t *)((ptr_t)pt_regs - sizeof(switchto_context_t));
    printl("The context address is at %x\n", pt_switchto);
    pt_switchto->regs[0] = entry_point; // ra寄存器的值

    printl("the address of entry point is at %x\n", &pt_switchto->regs[0]);
    printl("the value of the entry point is %x\n", pt_switchto->regs[0]);

    pcb->kernel_sp = pt_switchto;
    pt_switchto->regs[1] = pcb->kernel_sp;
    printl("the latest kernel sp is at %x\n", pcb->kernel_sp);
    printl("\n");
}

static void init_pcb(void)
{
    /* TODO: [p2-task1] load needed tasks and init their corresponding PCB */
    init_list_head(&ready_queue);
    int task1_to_handle = 3; // task1需要执行的任务，print1，pirnt2，fly
    for(int i = 0 ; i < task1_to_handle; i++){
        pcb[i].kernel_sp = allocKernelPage(1);
        pcb[i].user_sp = allocUserPage(1);
        pcb[i].pid = i + 1;
        pcb[i].cursor_x = 0;
        pcb[i].cursor_y = 0;
        pcb[i].status = TASK_READY;

        int task1_offset;
        if(i==0)
            task1_offset = 3;
        else if (i == 1)
            task1_offset = 5;
        else 
            task1_offset = 6;
        int offset = 0x52000000 + 0x10000*i;
        int num = (tasks[task1_offset].bytes - tasks[task1_offset-1].bytes) / 512 + 1;
        int loc = (tasks[task1_offset-1].bytes/512);
        bios_sdread(offset, num + 2, loc);
        int adder = tasks[task1_offset-1].bytes % 0x200;
        int address = adder + offset;

        init_pcb_stack(pcb[i].kernel_sp, pcb[i].user_sp, address ,&pcb[i]);
        enqueue(&ready_queue, &pcb[i]);
    }
    for (int i = 0; i < task1_to_handle; i++){
        if(i==0){
            pcb[i].list.prev = &pid0_pcb.list;
        }
        else{
            pcb[i].list.prev = &pcb[i-1].list;
        }
        if(i==2){
            pcb[i].list.next = &pid0_pcb.list;
        }
        else{
            pcb[i].list.next = &pcb[i+1].list;
        }
    }
    /* TODO: [p2-task1] remember to initialize 'current_running' */
    current_running = &pid0_pcb;
    pid0_pcb.list.next = &pcb[0].list;
}

static void init_syscall(void)
{
    // TODO: [p2-task3] initialize system call table.
}

int main(void)
{
    // Init jump table provided by kernel and bios(ΦωΦ)
    init_jmptab();

    // Init task information (〃'▽'〃)
    init_task_info();

    // Init Process Control Blocks |•'-'•) ✧
    init_pcb();
    printk("> [INIT] PCB initialization succeeded.\n");

    // Read CPU frequency (｡•ᴗ-)_
    time_base = bios_read_fdt(TIMEBASE);

    // Init lock mechanism o(´^｀)o
    init_locks();
    printk("> [INIT] Lock mechanism initialization succeeded.\n");

    // Init interrupt (^_^)
    init_exception();
    printk("> [INIT] Interrupt processing initialization succeeded.\n");

    // Init system call table (0_0)
    init_syscall();
    printk("> [INIT] System call initialized successfully.\n");

    // Init screen (QAQ)
    init_screen();
    printk("> [INIT] SCREEN initialization succeeded.\n");

    // TODO: [p2-task4] Setup timer interrupt and enable all interrupt globally
    // NOTE: The function of sstatus.sie is different from sie's


    // Infinite while loop, where CPU stays in a low-power state (QAQQQQQQQQQQQ)
    while (1)
    {
        // If you do non-preemptive scheduling, it's used to surrender control
        do_scheduler();
        break;
        // If you do preemptive scheduling, they're used to enable CSR_SIE and wfi
        // enable_preempt();
        // asm volatile("wfi");
    }

    return 0;
}
