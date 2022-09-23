#include <assert.h>
#include <elf.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <elf.h>

#define IMAGE_FILE "./image"
#define ARGS "[--extended] [--vm] <bootblock> <executable-file> ..."

#define SECTOR_SIZE 512
#define BOOT_LOADER_SIG_OFFSET 0x1fe
#define OS_SIZE_LOC (BOOT_LOADER_SIG_OFFSET - 2)
#define BOOT_LOADER_SIG_1 0x55
#define BOOT_LOADER_SIG_2 0xaa

#define NBYTES2SEC(nbytes) (((nbytes) / SECTOR_SIZE) + ((nbytes) % SECTOR_SIZE != 0))

/* TODO: [p1-task4] design your own task_info_t */
typedef struct {
    // char num;// 所占用块的个数
    // char loc;// 块的起始位置
    int bytes;
    char *filename;
} task_info_t;

#define TASK_MAXNUM 16
static task_info_t taskinfo[TASK_MAXNUM];

/* structure to store command line options */
static struct {
    int vm;
    int extended;
} options;

/* prototypes of local functions */
static void create_image(int nfiles, char *files[]);
static void error(char *fmt, ...);
static void read_ehdr(Elf64_Ehdr *ehdr, FILE *fp);
static void read_phdr(Elf64_Phdr *phdr, FILE *fp, int ph, Elf64_Ehdr ehdr);
static uint64_t get_entrypoint(Elf64_Ehdr ehdr);
static uint32_t get_filesz(Elf64_Phdr phdr);
static uint32_t get_memsz(Elf64_Phdr phdr);
static void write_segment(Elf64_Phdr phdr, FILE *fp, FILE *img, int *phyaddr);
static void write_padding(FILE *img, int *phyaddr, int new_phyaddr);
static void write_img_info(int nbytes_kernel, task_info_t *taskinfo,
                           short tasknum, FILE *img, int phyaddr);

int main(int argc, char **argv)
{
    char *progname = argv[0];

    /* process command line options */
    options.vm = 0;
    options.extended = 0;
    while ((argc > 1) && (argv[1][0] == '-') && (argv[1][1] == '-')) {
        char *option = &argv[1][2];

        if (strcmp(option, "vm") == 0) {
            options.vm = 1;
        } else if (strcmp(option, "extended") == 0) {
            options.extended = 1;
        } else {
            error("%s: invalid option\nusage: %s %s\n", progname,
                  progname, ARGS);
        }
        argc--;
        argv++;
    }
    if (options.vm == 1) {
        error("%s: option --vm not implemented\n", progname);
    }
    if (argc < 3) {
        /* at least 3 args (createimage bootblock main) */
        error("usage: %s %s\n", progname, ARGS);
    }
    create_image(argc - 1, argv + 1);
    return 0;
}

/* TODO: [p1-task4] assign your task_info_t somewhere in 'create_image' */
static void create_image(int nfiles, char *files[])
{
    int tasknum = nfiles - 2;
    int nbytes_kernel = 0;
    int phyaddr = 0;
    int former_phdaddr = 0;
    int programNameAddr = 0x1b0;
    FILE *fp = NULL, *img = NULL;
    Elf64_Ehdr ehdr;
    Elf64_Phdr phdr;
    /* open the image file */
    img = fopen(IMAGE_FILE, "w");
    assert(img != NULL);
    /* for each input file */
    for (int fidx = 0; fidx < nfiles; ++fidx) {

        int taskidx = fidx - 2;
        former_phdaddr = phyaddr;
        int programCounter = 0;
        /* open input file */
        fp = fopen(*files, "r");
        assert(fp != NULL);

        /* read ELF header */
        read_ehdr(&ehdr, fp);
        printf("0x%04lx: %s\n", ehdr.e_entry, *files);

        /* for each program header */
        for (int ph = 0; ph < ehdr.e_phnum; ph++) {

            /* read program header */
            read_phdr(&phdr, fp, ph, ehdr);

            /* write segment to the image */
            write_segment(phdr, fp, img, &phyaddr);

            /* update nbytes_kernel */
            if (strcmp(*files, "main") == 0) {
                nbytes_kernel += get_filesz(phdr);
            }
        }

        /* write padding bytes */
        /**
         * TODO:
         * 1. [p1-task3] do padding so that the kernel and every app program
         *  occupies the same number of sectors
         * 2. [p1-task4] only padding bootblock is allowed!
         */
        
        if (strcmp(*files, "bootblock") == 0) {
            write_padding(img, &phyaddr, SECTOR_SIZE);
        }
        // else if(strcmp(*files, "main") == 0){
        //     write_padding(img, &phyaddr, SECTOR_SIZE*8);
        // }
        // else 
        // {
        //     write_padding(img, &phyaddr, (phyaddr - phyaddr % SECTOR_SIZE + SECTOR_SIZE));
        //     taskinfo[fidx].num = (phyaddr - former_phdaddr) / SECTOR_SIZE;
        //     taskinfo[fidx].loc = former_phdaddr / SECTOR_SIZE;
        // }
        taskinfo[fidx].bytes = phyaddr;
        printf("The %s phyaddr is %x\n", files[0], phyaddr);
        int k = 0;
        taskinfo[fidx].filename = files[0];
        fclose(fp);
        files++;
    }
    write_img_info(nbytes_kernel, taskinfo, tasknum, img, phyaddr);

    fclose(img);
    printf("phyaddr: 0x%x\n", phyaddr);
}

static void read_ehdr(Elf64_Ehdr * ehdr, FILE * fp)
{
    int ret;

    ret = fread(ehdr, sizeof(*ehdr), 1, fp);
    assert(ret == 1);
    assert(ehdr->e_ident[EI_MAG1] == 'E');
    assert(ehdr->e_ident[EI_MAG2] == 'L');
    assert(ehdr->e_ident[EI_MAG3] == 'F');
}

static void read_phdr(Elf64_Phdr * phdr, FILE * fp, int ph,
                      Elf64_Ehdr ehdr)
{
    int ret;

    fseek(fp, ehdr.e_phoff + ph * ehdr.e_phentsize, SEEK_SET);
    ret = fread(phdr, sizeof(*phdr), 1, fp);
    assert(ret == 1);
    if (options.extended == 1) {
        printf("\tsegment %d\n", ph);
        printf("\t\toffset 0x%04lx", phdr->p_offset);
        printf("\t\tvaddr 0x%04lx\n", phdr->p_vaddr);
        printf("\t\tfilesz 0x%04lx", phdr->p_filesz);
        printf("\t\tmemsz 0x%04lx\n", phdr->p_memsz);
    }
}

static uint64_t get_entrypoint(Elf64_Ehdr ehdr)
{
    return ehdr.e_entry;
}

static uint32_t get_filesz(Elf64_Phdr phdr)
{
    return phdr.p_filesz;
}

static uint32_t get_memsz(Elf64_Phdr phdr)
{
    return phdr.p_memsz;
}

static void write_segment(Elf64_Phdr phdr, FILE *fp, FILE *img, int *phyaddr)
{
    if (phdr.p_memsz != 0 && phdr.p_type == PT_LOAD) {
        /* write the segment itself */
        /* NOTE: expansion of .bss should be done by kernel or runtime env! */
        if (options.extended == 1) {
            printf("\t\twriting 0x%04lx bytes\n", phdr.p_filesz);
        }
        fseek(fp, phdr.p_offset, SEEK_SET);
        while (phdr.p_filesz-- > 0) {
            fputc(fgetc(fp), img);
            (*phyaddr)++;
        }
    }
}

static void write_padding(FILE *img, int *phyaddr, int new_phyaddr)
{
    if (options.extended == 1 && *phyaddr < new_phyaddr) {
        printf("\t\twrite 0x%04lx bytes for padding\n", new_phyaddr - *phyaddr);
    }
    while (*phyaddr < new_phyaddr) {
        fputc(0, img);
        (*phyaddr)++;
    }
    printf("%d sectors have been written\n", new_phyaddr/512);
}

static void write_img_info(int nbytes_kern, task_info_t *taskinfo,
                           short tasknum, FILE * img, int phyaddr)
{
    // TODO: [p1-task3] & [p1-task4] write image info to some certain places
    // NOTE: os size, infomation about app-info sector(s) ...
    short os_size = nbytes_kern / 512 + 1;
    int loc = 0;
    loc = OS_SIZE_LOC;
    // fseek(img, loc, SEEK_SET);
    // fputc(4, img);
    char num = (char)tasknum;
    fseek(img, OS_SIZE_LOC, SEEK_SET);
    fputc(os_size, img);

    printf("os_size: %d sectors\n", os_size);
    printf("kernel size: %d\n", nbytes_kern);
    int i;
    printf("The phyaddr is %x, which is at the %d sector\n", phyaddr, phyaddr/512);
    char sectors = phyaddr/512;
    fseek(img, phyaddr, SEEK_SET);
    write_padding(img, &phyaddr, (phyaddr - phyaddr % SECTOR_SIZE + SECTOR_SIZE));
    fseek(img, OS_SIZE_LOC-4, SEEK_SET);
    fwrite(&phyaddr, 1, 4, img);
    printf("The info addr is at %x\n", phyaddr);
    for(i=0; i<16; i++){
        fseek(img, phyaddr, SEEK_SET);
        fwrite(&taskinfo[i].bytes, 1, 4, img);
        phyaddr+=4;
    }
    for(i=0; i<=tasknum+1; i++)
    {
        printf("%s\n", taskinfo[i].filename);
        fseek(img, phyaddr, SEEK_SET);
        int j = 0;
        while(taskinfo[i].filename[j] != 0)
        {
            fputc(taskinfo[i].filename[j], img);
            phyaddr++;
            j+=1;
        }
        fputc(0, img);
        phyaddr++;
        j+=1;
    }
    fputc(0xff, img);
    fseek(img, 0x1b0, SEEK_SET);
    FILE *P = fopen("batch.txt", "r");
    if(P == NULL)
        printf("open the file failed\n");
    char name[100];
    int k = 0;
    while(!feof(P)){
        name[k++] = getc(P);
    }
    phyaddr++;
    name[k-1] = 0;
    k = 0;
    printf("%s\n", name);
    printf("begin the name\n");
    while(name[k]){
        fseek(img, phyaddr + k, SEEK_SET);
        fputc(name[k], img);
        k++;
    }
    printf("complete the name\n");
}

/* print an error message and exit */
static void error(char *fmt, ...)
{
    va_list args;

    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    if (errno != 0) {
        perror(NULL);
    }
    exit(EXIT_FAILURE);
}
