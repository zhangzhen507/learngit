#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/timeb.h>

#define _1K (1024)
#define _1M (1024*1024)
#define _1G (1024*1024*1024)
#define LEN  (300*_1M)

int main()
{
	int i;
	char* ary = (char*) malloc(sizeof(char) * LEN);
	char* pch = 0;
	struct timeb tp;
	struct tm * tm;
	for(i = 0; i < LEN; i++){
		ary[i] = 'A';
	}
	while(1){
		ftime ( &tp );
		tm = localtime(&(tp.time));
		fprintf(stdout, "%d:%d:%d:%d\n", (tm->tm_hour), (tm->tm_min), (tm->tm_sec), (tp.millitm));
		for(i = 0; i < LEN; i++){
			ary[i] = tp.millitm;
		}
	}
	free(ary);
	return 0;
}
