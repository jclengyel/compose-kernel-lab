#!/bin/sh
if [ -f tbdump ]
then
    rm tbdump
    if [ $? -ne 0 ]
    then
        echo "Failed to remove tbdump from current directory. Exiting..."
        exit -1
    fi
fi

cat > tbdump.c <<TBDUMPEND
/***************************************************************************
 *
 *                         INFORMIX SOFTWARE, INC.
 *
 *                            PROPRIETARY DATA
 *
 *      THIS DOCUMENT CONTAINS TRADE SECRET DATA WHICH IS THE PROPERTY OF
 *      INFORMIX SOFTWARE, INC.  THIS DOCUMENT IS SUBMITTED TO RECIPIENT IN
 *      CONFIDENCE.  INFORMATION CONTAINED HEREIN MAY NOT BE USED, COPIED OR
 *      DISCLOSED IN WHOLE OR IN PART EXCEPT AS PERMITTED BY WRITTEN AGREEMENT
 *      SIGNED BY AN OFFICER OF INFORMIX SOFTWARE, INC.
 *
 *      THIS MATERIAL IS ALSO COPYRIGHTED AS AN UNPUBLISHED WORK UNDER
 *      SECTIONS 104 AND 408 OF TITLE 17 OF THE UNITED STATES CODE.
 *      UNAUTHORIZED USE, COPYING OR OTHER REPRODUCTION IS PROHIBITED BY LAW.
 *
 * Title: tbdump.c
 *
 * Description: to view pages in TURBO raw device.  (Actually works on
 *              any file)
 *
 ****************************************************************************
 */

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>

#ifdef P4K 
#define PAGESIZE  4096
#else
#ifdef P8K
#define PAGESIZE  8192
#else
#define PAGESIZE  2048
#endif
#endif 

#ifdef NT
#include <windows.h>
#include <sys/types.h>
    char	*optarg;
    int		optind = 1;
    int		opterr, optopt;
    static off_t NT_lseek64(__int64 filedes, off_t offset, int whence);
    __int64 NT_open(const char* filename, int oflag, ...);
    size_t NT_read(__int64 filedes, void* buffer, size_t nbytes);
    int NT_close(__int64 filedes);
#else
    extern char  *optarg;
    extern int   optind;
#endif


#define ALIGN_BOUNDRY    (1024) 
#define ALIGN(x,y)       (((x)+(y)-1)&(-(y)))

int
usage(char *pname)
{
    fprintf(stderr,"\nUsage: %s -d device-name -o offset -n numpages\n",pname);
    fprintf(stderr,"\t\t\t     The page size is: %d\n",PAGESIZE);
    fprintf(stderr,"\t\t\t          Version 3.1\n");
    fprintf(stderr,"\t\t==========================================\n");
    fprintf(stderr,"\t\t-d\tdevice\t\tfile to be examined\n");
    fprintf(stderr,"\t\t-o\toffset\t\tnumber of pages as specified\n");
    fprintf(stderr,"\t\t-n\tnumpages\tnumber of pages to dump\n");
    fprintf(stderr,"\t\t-h\t\t\tprint the page header\n");
    fprintf(stderr,"\t\t-H\tlength\t\tamount of page to print(bytes)\n");
    exit(0);
}

int
main(int argc, char *argv[])
{
    char devname[64], errmsg[80];
    long offset, start_count, numpages;
    int fd,c,i,cnt,argn=0, hdr=PAGESIZE;
    char *buff,*mbuff;

    while ( (c=getopt(argc,argv,"hH:n:d:o:")) !=EOF) {
	switch(c) {
	case 'd':                         /* This is the device name */
	    sprintf(devname,"%s",optarg);
	    argn|=0x1;
	    break;
	case 'o':                        /* page offset into device */
	    offset = strtol(optarg,(char **) NULL, 0);
	    argn|=0x2;
	    break;
	case 'n':                        /* page offset into device */
	    numpages = strtol(optarg,(char **) NULL, 0);
	    argn|=0x4;
	    break;
	case 'H':                        /* print H bytes information */
	    hdr = strtol(optarg,(char **) NULL, 0);
	case 'h':                        /* Print page header information */
	    argn|=0x10;
	    if (hdr==PAGESIZE) hdr=24;
	    break;
	case '?':      /* Not a valid option error message */
	    break;
	default:
	    usage( argv[0] );
	    fatal( "Illegal Option") ;
	}
    }					/* Follow the old format */
    if ((optind==1)&&(argc==4)){
	sprintf(devname,"%s",argv[1]);
	offset = strtol(argv[2],(char **) NULL, 0);
	numpages = strtol(argv[3],(char **) NULL, 0);
	argn|=0x7;
    }
    if ((argn & 0x07) != 0x7)
	usage( argv[0] );


    if ((fd =
#ifdef NT
        NT_open
#else
        open
#endif
	 (devname, O_RDONLY)) == -1)
	{
	sprintf(errmsg, "open(%s) error: %d", devname, errno);
	fatal(errmsg);
	}

    if (
#ifdef NT
        NT_lseek64
#else
        lseek
#endif
    (fd, offset * PAGESIZE, 0) == -1)
	{
	sprintf(errmsg, "lseek(%d) error: %d", offset*PAGESIZE, errno);
	fatal(errmsg);
	}
    for (i=offset; i<(offset+numpages); i++)
	{
	printf("\nPage %08X\n", i);
	printf("=============\n");

	if ((mbuff = malloc(PAGESIZE+ALIGN_BOUNDRY)) == NULL)
	    {
	    sprintf(errmsg, "malloc(%d) error: %d", PAGESIZE, errno);
	    fatal(errmsg);
	    }
	buff=(char *)ALIGN((long)mbuff,ALIGN_BOUNDRY);

	if ((cnt =
#ifdef NT
        NT_read
#else
        read
#endif
	     (fd, buff, PAGESIZE)) < PAGESIZE)
	    {
	    sprintf(errmsg, "read(%d) error: %d", PAGESIZE, errno);
	    fatal(errmsg);
	    }
	hexdump(0, buff, hdr);

	free(mbuff);
	}
#ifdef NT
    NT_close(fd);
#else
    close(fd);
#endif
    exit(0);
}

int hexdump(long start_count, char *buff, long byte_count)
{
    int i,j,half,doneonce=0;
    char oline[81], lastline[40];
    char *cptr=buff;


    for (i=0;i<byte_count/16;i++)
	{
	sprintf(oline, "%08X",start_count+i*16);
	for (j=0,cptr=(&(buff[i*16]));j<8;j++,cptr+=2)
	    sprintf(oline,"%s %02X%02X",oline,((*cptr)&0xFF),((*(cptr+1))&0xFF));
	sprintf(oline,"%s ",oline);
	for (j=0,cptr=(&(buff[i*16]));j<16;j++,cptr++)
	    {
	    if (isprint(*cptr)&& ((unsigned char)*cptr<127) )
		sprintf(oline,"%s%c",oline,*cptr );
	    else
		sprintf(oline, "%s.", oline);
	    }
	if ((i>0) && (!strncmp(lastline,&(oline[9]),37) ) ) {
	    if (!doneonce){
		printf("%08X *\n",start_count+i*16); 
		doneonce=1;
	    }
	    continue;
	}
	else{
	    doneonce=0;
	    printf("%s\n",oline);
	}
	strncpy(lastline,&(oline[9]),38);
	}
    i=(byte_count/16);
    if (half = (byte_count - (byte_count/16)*16)){
	sprintf(oline, "%08X",start_count+i*16);
	for (j=0,cptr=(&(buff[i*16]));j<8;j++,cptr+=2)
	    if ((half/2) > j)
		sprintf(oline,"%s %02X%02X",oline,((*cptr)&0xFF),((*(cptr+1))&0xFF));
	    else 
		sprintf(oline,"%s     ",oline);
	sprintf(oline,"%s ",oline);
	for (j=0,cptr=(&(buff[i*16]));j<half;j++,cptr++)
	    {
	    if (isprint(*cptr) && ((unsigned char)*cptr < 127) )
		sprintf(oline,"%s%c",oline,*cptr );
	    else
		sprintf(oline, "%s.", oline);
	    }
	printf("%s\n",oline);
    }
}

fatal(char *txt)
{
    fprintf(stderr,"%s\n", txt);
    fflush(stderr);
    exit(1);
}

#ifdef NT
getopt(int argc, char *argv[], char *optstring)
{
    static int	index = 0;

    int					argvsize;
    char				option;
    char				*optchar;


    if (index == 0)
	{
	if ((optind >= argc) || (argv[optind] == NULL) || !strcmp(argv[optind], "-"))
	    return -1;

	if (*argv[optind] == '-')
	    index++;
	else
	    return 1;
	}

    option = *(argv[optind]+index);
    argvsize = strlen(argv[optind]);

    if ((optchar = strchr(optstring, option)) == NULL)
	return '?';

    if ( ((size_t)(optchar - optstring) < strlen(optstring)) && (*(optchar +1) == ':'))
	{
	if (strlen(argv[optind]+index) > 1)
	    {
	    optarg = argv[optind]+index+1;
	    optind++;
	    }
	else
	    {
	    if ((optind+1) < argc)
		{
		optarg = argv[optind+1];
		}
	    else
		{
		/* Missing option */
		optopt = option;
		if (*optstring == ':')
		    {
		    option = ':';
		    }
		else
		    {
		    option = '?';
		    if (opterr != 0)
			fprintf(stderr, "%s: option requires an argument -- %c\n\n", argv[0], optopt);
		    }
		}
	    optind += 2;
	    }
	index = 0;
	}
    else
	{
	optarg = NULL;
	index++;

	if(index == argvsize)
	    {
	    index = 0;
	    optind++;
	    }
	}

    return (int) option;
}

#define HILONG(LL)  ((long)((((__int64)(LL)) >> 32) & 0xFFFFFFFFF))
#define LOWLONG(LL) ((long)((LL) & 0xFFFFFFFFF))

#define MAKELONGLONG(LO,HI) ((((__int64)(HI)) << 32) | (LO))

#define RW_FLAG                 (_O_BINARY |    \
				 _O_TEXT |      \
				 _O_CREAT |     \
				 _O_EXCL |      \
				 _O_TRUNC)
#define CR_FLAG                 (_O_BINARY |    \
				 _O_TEXT |      \
				 _O_WRONLY |    \
				 _O_APPEND |    \
				 _O_RDWR |      \
				 _O_RDONLY)

int NT_ErrW32ToUnix(int ec)
{
    return ec;
}

off_t NT_lseek64(__int64 filedes, off_t offset, int whence)
{
    DWORD   NT_origin;
    DWORD   lowOffset;
    off_t highOffset;

    if (whence == SEEK_SET)         /* Beginning o file */
	{   
	NT_origin = FILE_BEGIN;
	}   
    else if (whence == SEEK_CUR)    /* Curr pos of file */
	{   
	NT_origin = FILE_CURRENT;
	}   
    else if (whence == SEEK_END)    /* End o File */
	{   
	NT_origin = FILE_END;
	}   
    else
	{   
	errno = EINVAL;
	return (off_t)-1;
	}   

    highOffset = HILONG(offset);
    lowOffset = SetFilePointer((HANDLE)filedes,
			       LOWLONG(offset), &highOffset, NT_origin);

    if (lowOffset == 0xFFFFFFFF && GetLastError() != NO_ERROR)
	{   
	printf("SetFilePointer()");
	errno = EBADF;          /* For Return Value */
	return (off_t)-1;
	}   

    return (long)MAKELONGLONG(lowOffset, highOffset);
} /* NT_lseek() */
__int64 NT_open(const char* filename, int oflag, ...)
{
    DWORD   fdwAccess = 0;
    DWORD   fdwShareMode = 0;
    DWORD   fdwCreate = 0;
    DWORD   fdwAttrsAndFlags = 0;
    DWORD   rwflag;
    DWORD   creatflag;
    HANDLE  hFile = 0;
    DWORD   dwPointer;
    BOOL    bTwoStars = FALSE;

    if (*filename == '*')
	{   
	/*  
	 * One Leading star "*" for: +only Non Cacheing Io
	 */

	filename++;
	fdwAttrsAndFlags |= FILE_FLAG_NO_BUFFERING;

	if (*filename == '*')
	    {
	    /*
	     * Filename begins with 2 stars "*": Non Blocking IO
	     */

	    filename++;
	    fdwAttrsAndFlags |= FILE_FLAG_OVERLAPPED;
	    bTwoStars = TRUE;
	    }
	}

    rwflag = oflag & ~RW_FLAG;
    creatflag = oflag & ~CR_FLAG;

    fdwAccess = GENERIC_READ;

    if (rwflag & _O_WRONLY)
	{
	fdwAccess = GENERIC_WRITE;
	}
    else if ((rwflag & _O_RDWR) || (rwflag & _O_APPEND))
	{
	fdwAccess |= GENERIC_WRITE;
	}

    if (bTwoStars)
	{
	fdwCreate = OPEN_EXISTING;
	}
    else
	{
	if ((creatflag & (_O_CREAT | _O_EXCL)) == (_O_CREAT | _O_EXCL))
	    {
	    fdwCreate = CREATE_NEW;
	    }
	else if ((creatflag & (_O_CREAT | _O_TRUNC)) == (_O_CREAT | _O_TRUNC))
	    {
	    fdwCreate = CREATE_ALWAYS;
	    }
	else if (creatflag & _O_CREAT)
	    {
	    fdwCreate = OPEN_ALWAYS;
	    }
	else if (creatflag & _O_TRUNC)
	    {
	    fdwCreate = TRUNCATE_EXISTING;
	    }
	else
	    {
	    fdwCreate = OPEN_EXISTING;
	    }
	}

    fdwAttrsAndFlags |= FILE_ATTRIBUTE_NORMAL|FILE_FLAG_BACKUP_SEMANTICS;
    fdwShareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;

    hFile = CreateFile(filename,
		       fdwAccess,
		       fdwShareMode,
		       NULL,
		       fdwCreate,
		       fdwAttrsAndFlags,
		       NULL);

    if (hFile == INVALID_HANDLE_VALUE)
	{
	int retval;

	retval = GetLastError();

	/*
	 * Map NT error codes to be compatible with Unix
	 */
	errno = NT_ErrW32ToUnix(retval);

	if (errno != ENOENT)
	    {
	    printf("CreateFile():%d", retval);
	    }

	return -1;
	}

    /*
     * If has to be opened in APPEND mode
     * Then Move the File pointer to the end of FILE
     */

    /*
     * BUGBUG: This does not follow the UNIX SEMANTICS, yet since this
     * is used from outside of mt_aio_open(), like when mt_logprintf()
     * wants to write a line to the log for every checkpoint, we leave
     * this in. It does no harm to mt_aio_* calls because we keep the
     * filepointer separately there and before doing a read/write always
     * do an lseek with that pointer.
     */

    if (oflag & _O_APPEND)
	{
	dwPointer = SetFilePointer(hFile, 0, NULL, FILE_END);

	if (dwPointer == 0xFFFFFFFF)
	    {
	    printf("SetFilePointer()");
	    CloseHandle (hFile);
	    hFile = 0;      /* For Return Value */
	    }

	/*BUGBUG why do this? We just seeked to the end of the file... */
	if (!SetEndOfFile(hFile))
	    {
	    printf("SetEndOfFile()");
	    }
	}

    return (__int64)hFile;
} /* NT_open() */



size_t NT_read(__int64 filedes, void* buffer, size_t nbytes)
{
    DWORD   dwBytesRead;

    /*BUGBUG can't read from stdin? NT_write can write to stdout... */

    if (!ReadFile((HANDLE)filedes, buffer, nbytes, &dwBytesRead, NULL))
	{
	int w32ec = GetLastError();

	errno = NT_ErrW32ToUnix(w32ec);

	if (errno != EBADF)
	    {
	    printf("ReadFile():%d", w32ec);
	    }

	return -1;
	}

    return (size_t)dwBytesRead;
} /* NT_read() */
int NT_close(__int64 filedes)
{
    if (!CloseHandle((HANDLE)filedes))
	{   
	int w32err = GetLastError();

	errno = NT_ErrW32ToUnix(w32err);

	if (errno != EBADF)
	    {   
	    printf("CloseHandle():%d", w32err);
	    }   

	return -1; 
	}   

    return 0;
} /* NT_close() */



#endif
TBDUMPEND
cc tbdump.c -o tbdump > /dev/null 2>&1
if [ -f tbdump ]
then
    echo "tbdump utility successfully created."
else
    echo "Compilation of tbdump failed. Try compiling it by hand."
fi
