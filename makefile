# makefile
# This makes "dbinfo"

CC=esql
#CC=c4gl

dbinfo: dbinfo.ec
	$(CC) -O dbinfo.ec -o dbinfo -s
	@rm -f dbinfo.c
