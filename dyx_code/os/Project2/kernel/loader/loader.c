#include <os/task.h>
#include <os/string.h>
#include <os/kernel.h>
#include <type.h>
#define BIOS_SDREAD 11
int compare(char *a, char *b){
    int i;
    for(i=0; i<10; i++){
        if (a[i] == b[i] && a[i] == 0)
            return 1;
        if(a[i] != b[i])
            return 0;
    }
    return 1;
}
char batch[100];
char deals[TASK_MAXNUM][10];
int onedim2twodim(char *batch){
    int i = 0;
    int j = 0;
    while(*batch != 0){
        if(*batch == ' '){
            i++;
            j=0;
            batch++;
            continue;
        }
        deals[i][j] = *batch;
        j++;
        batch++;
    }
    return i;
}
uint64_t load_task_img(char *taskid)
{
    /**
     * TODO:
     * 1. [p1-task3] load task from image via task id, and return its entrypoint
     * 2. [p1-task4] load task via task name, thus the arg should be 'char *taskname'
     */
    if (!taskid)
    {
        bios_putstr("Error, no input\n");
        return 0;
    }
    int batchnum = 
    onedim2twodim(batch);
    int i = 0;
    if(compare(taskid, "batch")){
        for(i=0; i<batchnum+1; i++){
            load_task_img(deals[i]);
        }
        bios_putstr("[batch]finish the batch\n");
        return 0;
    }
    for(i=0; i<16; i++){
        if(compare(taskid, tasks[i].filename))
            break;
    }
    if (i == 16)
    {
        bios_putstr("There is no such program\n");
        return 0;
    }
    int offset = 0x52000000 + 0x10000*(i-2);
    int num = (tasks[i].bytes - tasks[i-1].bytes) / 512;
    int loc = (tasks[i-1].bytes/512);
    bios_sdread(offset, num + 2, loc);
    int adder = tasks[i-1].bytes % 0x200;
    int address = adder + offset;
    ((void(*)(void))(address))();
    
    asm volatile("nop");
    return 0;
}