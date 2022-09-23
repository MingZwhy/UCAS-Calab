#include <os/list.h>
#include <os/lock.h>
#include <os/sched.h>
#include <os/time.h>
#include <os/mm.h>
#include <screen.h>
#include <printk.h>
#include <assert.h>

pcb_t pcb[NUM_MAX_TASK];
const ptr_t pid0_stack = INIT_KERNEL_STACK + PAGE_SIZE;
pcb_t pid0_pcb = {
    .pid = 0,
    .kernel_sp = (ptr_t)pid0_stack,
    .user_sp = (ptr_t)pid0_stack
};

LIST_HEAD(ready_queue);
LIST_HEAD(sleep_queue);

/* current running task PCB */
pcb_t * volatile current_running;

/* global process id */
pid_t process_id = 1;

void enqueue(list_head* queue, pcb_t* item)
{
    list_add_tail(&item->list, queue);
}

pcb_t *getTheNextqueue(pcb_t *current)
{   
    pcb_t *next_list = current->list.next;
    next_list = (char *)next_list - 0x10;
    return (pcb_t *)next_list;//由于list node和pcb差了0x10字节，需要减去，至于这里怎么寻址的我也不知道，但是需要减一
}

void do_scheduler(void)
{
    // TODO: [p2-task3] Check sleep queue to wake up PCBs


    // TODO: [p2-task1] Modify the current_running pointer.
    if(current_running == &pcb[2])
        return;
    if(current_running->status == TASK_RUNNING && current_running->pid != 0){ 
        // enqueue(&ready_queue, current_running);
        current_running->status = TASK_READY;
    }
    pcb_t *last_running = current_running;
    pcb_t *next_running = getTheNextqueue(current_running);  
    // TODO: [p2-task1] switch_to current_running
    next_running->status = TASK_RUNNING;
    current_running = next_running;
    switch_to(last_running, next_running);
}

void do_sleep(uint32_t sleep_time)
{
    // TODO: [p2-task3] sleep(seconds)
    // NOTE: you can assume: 1 second = 1 `timebase` ticks
    // 1. block the current_running
    // 2. set the wake up time for the blocked task
    // 3. reschedule because the current_running is blocked.
}

void do_block(list_node_t *pcb_node, list_head *queue)
{
    // TODO: [p2-task2] block the pcb task into the block queue
}

void do_unblock(list_node_t *pcb_node)
{
    // TODO: [p2-task2] unblock the `pcb` from the block queue
}
