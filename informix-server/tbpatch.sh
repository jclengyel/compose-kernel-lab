#!/bin/sh
if [ -f tbpatch ]
then
    rm tbpatch
    if [ $? -ne 0 ]
    then
        echo "Failed to remove tbpatch from current directory. Exiting..."
        exit -1
    fi
fi
cat > tbpatch.c <<TBPATCHEND
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <time.h>
#include <sys/types.h>

#ifdef P4K
#define PAGESIZE  4096
#else
#ifdef P8K
#define PAGESIZE  8192
#else
#define PAGESIZE  2048
#endif
#endif
#define BYTESHFT 8
#define KEY		 72767
#define ALIGN_BOUNDRY    (1024)
#define ALIGN(x,y)       (((x)+(y)-1)&(-(y)))

Fatal(ofile,txt,exit_code)
char *txt;
int  exit_code;
FILE *ofile;
{
  fprintf(ofile , "%s\n", txt);
  fflush(ofile);
  if (exit_code)
      exit(exit_code) ;
}
stlong(l,p)
register long l;
register char *p;
{
#ifndef SHORT
        p[0] = (l >> (BYTESHFT*3));
        p[1] = (l >> (BYTESHFT*2));
        p[2] = (l >> BYTESHFT);
        p[3] = l;
#define PATCHSIZE 4
#else
#define PATCHSIZE 2
        p[0] = (l >> BYTESHFT);
        p[1] = l;
#endif  
}
bccopy(src,dest,len)
char *src,*dest;
int len;
{
int c;
for(c=0;c<len;c++)
  dest[c]=src[c];
}
int Save_Page(rbuff,offset,length)
char *rbuff;
long offset,length;
{
char svpage[80],errmsg[80];
FILE *fdw,*rtn=NULL;
int  i=0;
 
   do {
       sprintf(svpage,"pg.%x.%x",offset,i);
       rtn = fopen(svpage,"r");
       i++;
      } while(rtn!=NULL );
   close(rtn); 
   if ( (fdw = fopen(svpage, "w")) == (FILE *)NULL )       /* open file */
           {
           sprintf(errmsg, "open(%s) error: %d", svpage, errno);
           Fatal(stderr,errmsg,-1);
           return(-1);
           }
   if ( fwrite(rbuff,sizeof(char),length * PAGESIZE, fdw) < length*PAGESIZE)
           {
           sprintf(errmsg, "write(%d) error: %d", PAGESIZE, errno);
           close(fdw);
           Fatal(stderr,errmsg,-1);
           return(-1);
           }
   close(fdw);
   return 0; 
}
Usage(pname)
char *pname;
{
  fprintf(stderr,"Usage: %s -d file-name -o pgoffset -b offset [-v value | -s string]\n",pname);
  fprintf(stderr,"\t\t\t     The page size is: %d\n",PAGESIZE);
  fprintf(stderr,"\t\t\t         Version 2.10 \n");
  fprintf(stderr,"\t\t============================================\n");
  fprintf(stderr,"\t-d\tfile-name\t= /dev/xxxx (or regular file)\n");
  fprintf(stderr,"\t-o\tpgoffset\t= number of pages into file to patch\n");
  fprintf(stderr,"\t-b\toffset\t\t= number of bytes from  boundary to patch\n");
  fprintf(stderr,"\t-v\tvalue\t\t= %d byte value\n",PATCHSIZE);
  fprintf(stderr,"\t-s\t\"string\"\t= string value to be patched\n");
  exit(0);
}

main(argc, argv)
int   argc;
char *argv[];
{
extern char  *optarg;
extern int   optind;
char devname[64], errmsg[80],svpage[80],pstring[PAGESIZE+1];
long offset, pgoffset, value,now;
int fd, i,c, cnt,argn=0;
struct tm *tm_today;
FILE *fdw;
char *mbuff,*buff, *malloc();
time(&now);tm_today=localtime(&now);
strcpy(pstring,"NUll");
while ( (c=getopt(argc,argv,"d:o:b:v:s:k:t:")) !=EOF) {
        switch(c) {
        case 'd':                         /* This is the device name */
           sprintf(devname,"%s",optarg);
           argn|=0x1;
           break;
        case 'o':                        /* page offset into device */
           pgoffset = strtol(optarg,(char **) NULL, 0);
           argn|=0x2;
           break;
        case 'b':                        /* byte offset into the page */
           offset = strtol(optarg, (char **) NULL, 0);
           argn|=0x4;
           break;
        case 'v':                        /* New long value to save  */
           value = strtol(optarg, (char **) NULL, 0);
           argn|=0x10;
           break;
        case 's':                         /* string value to patch */
           sprintf(pstring,"%s",optarg);
           argn|=0x30;
           break;
        case 't':                        /* Print information */
           printf("\n\n\t\tToday is %d/%d/%d\n\n",
               tm_today->tm_mon +1,tm_today->tm_mday,tm_today->tm_year);
           exit(0);
        case '?':      /* Not a valid option error message */
           break;
        default:
            Usage( argv[0] );
            Fatal(stderr,"Illegal Option",(-1)) ;
        }
    }

if ((argn&0x17)!=0x17)
     Usage(argv[0]);


if ((fd = open(devname, O_RDWR)) == -1)
        {
        sprintf(errmsg, "open(%s) error: %d", devname, errno);
        Fatal(stderr,errmsg,(-1));
        }

if (lseek(fd, pgoffset * PAGESIZE, 0) == -1)
        {
        sprintf(errmsg, "lseek(%d) error: %d (pre-read)", pgoffset*PAGESIZE, errno);
        Fatal(stderr,errmsg,(-1));
        }

if ((mbuff = malloc(PAGESIZE+ALIGN_BOUNDRY)) == NULL)
        {
        sprintf(errmsg, "malloc(%d) error: %d", PAGESIZE, errno);
        Fatal(stderr,errmsg,(-1));
        }
buff=(char *)ALIGN((long)mbuff,ALIGN_BOUNDRY);
if ((cnt = read(fd, buff, PAGESIZE)) < PAGESIZE)
        {
        sprintf(errmsg, "read(%d) error: %d", PAGESIZE, errno);
        Fatal(stderr,errmsg,(-1));
        }
if (Save_Page(buff,pgoffset,1)) {
        sprintf(errmsg, "Error saving page.", svpage, errno);
        Fatal(stderr,errmsg,(-1));
        }
if ((argn & 0x20) == 0x20)
   bccopy(pstring,buff+offset,strlen(pstring));
else
   stlong(value, buff+offset);

if (lseek(fd, pgoffset * PAGESIZE, 0) == -1)
        {
        sprintf(errmsg, "lseek(%d) error: %d (pre-write)", pgoffset*PAGESIZE, errno);
        Fatal(stderr,errmsg,(-1));
        }

if ((cnt = write(fd, buff, PAGESIZE)) < PAGESIZE)
        {
        sprintf(errmsg, "write(%d) error: %d", PAGESIZE, errno);
        Fatal(stderr,errmsg,(-1));
        }

        free(mbuff);
        
finish:

        close(fd);
        exit(0);
}
TBPATCHEND
cc tbpatch.c -o tbpatch > /dev/null 2>&1
if [ -f tbpatch ]
then
    echo "tbpatch utility successfully created."
else
    echo "Compilation of tbpatch failed. Try compiling it by hand."
fi
