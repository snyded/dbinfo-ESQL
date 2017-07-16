/*
    dbinfo.ec - prints the schema of a database table to stdout
    Copyright (C) 1989-1997  David A. Snyder
 
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; version 2 of the License.
 
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
 
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#ifndef lint
static char sccsid[] = "@(#) dbinfo.ec 4.4  97/05/02 15:33:22";
#endif /* not lint */


#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include "decimal.h"
$include sqlca;
$include sqltypes;
$include datetime;

#define SUCCESS	0
#define VCMIN(size) (((size) >> 8) & 0x00ff)
#define VCMAX(size) ((size) & 0x00ff)

char	*database = NULL, *table = NULL;
char	*dtetim[][10] = {
	{"year","year(1)","year(2)","year(3)","year","year(5)","year(6)","year(7)","year(8)","year(9)"},
	{"","","","","","","","","",""},
	{"month","month(1)","month","month(3)","month(4)","month(5)","month(6)","month(7)","month(8)","month(9)"},
	{"","","","","","","","","",""},
	{"day","day(1)","day","day(3)","day(4)","day(5)","day(6)","day(7)","day(8)","day(9)"},
	{"","","","","","","","","",""},
	{"hour","hour(1)","hour","hour(3)","hour(4)","hour(5)","hour(6)","hour(7)","hour(8)","hour(9)"},
	{"","","","","","","","","",""},
	{"minute","minute(1)","minute","minute(3)","minute(4)","minute(5)","minute(6)","minute(7)","minute(8)","minute(9)"},
	{"","","","","","","","","",""},
	{"second","second(1)","second","second(3)","second(4)","second(5)","second(6)","second(7)","second(8)","second(9)"},
	{"fraction(1)","","","","","","","","",""},
	{"fraction","fraction(1)","fraction(2)","fraction(3)","fraction(4)","fraction(5)","","","",""},
	{"fraction(3)","","","","","","","","",""},
	{"fraction(4)","","","","","","","","",""},
	{"fraction(5)","","","","","","","","",""}
};
void	exit();

$struct _systables {
	char	tabname[19];
	char	owner[9];
	char	dirpath[65];
	long	tabid;
	short	rowsize;
	short	ncols;
	short	nindexes;
	long	nrows;
	long	created;
	long	version;
	char	tabtype[2];
	char	audpath[65];
} systables;

$struct _syscolumns {
	char	colname[19];
	long	tabid;
	short	colno;
	short	coltype;
	short	collength;
} syscolumns;

$struct _sysindexes {
	char	idxname[19];
	char	owner[9];
	long	tabid;
	char	idxtype[2];
	char	clustered[2];
	short	part1;
	short	part2;
	short	part3;
	short	part4;
	short	part5;
	short	part6;
	short	part7;
	short	part8;
	short	part9;
	short	part10;
	short	part11;
	short	part12;
	short	part13;
	short	part14;
	short	part15;
	short	part16;
} sysindexes;

main(argc, argv)
int	argc;
char	*argv[];
{

	$char	exec_stmt[32], qry_stmt[128];
	extern char	*optarg;
	extern int	optind, opterr;
	int	c, dflg = 0, errflg = 0, tflg = 0;

	/* Print copyright message */
	(void)fprintf(stderr, "DBINFO version 4.4, Copyright (C) 1989-1997 David A. Snyder\n\n");

	/* get command line options */
	while ((c = getopt(argc, argv, "d:t:")) != EOF)
		switch (c) {
		case 'd':
			dflg++;
			database = optarg;
			break;
		case 't':
			tflg++;
			table = optarg;
			break;
		default:
			errflg++;
			break;
		}

	/* validate command line options */
	if (errflg || !dflg) {
		(void)fprintf(stderr, "usage: %s -d dbname [-t tabname]\n", argv[0]);
		exit(1);
	}

	/* locate the database in the system */
	sprintf(exec_stmt, "database %s", database);
	$prepare db_exec from $exec_stmt;
	$execute db_exec;
	if (sqlca.sqlcode != SUCCESS) {
		(void)fprintf(stderr, "Database not found or no system permission.\n\n");
		exit(1);
	}

	/* build the select statement */
	if (tflg) {
		if (strchr(table, '*') == NULL &&
		    strchr(table, '[') == NULL &&
		    strchr(table, '?') == NULL)
			sprintf(qry_stmt, "select tabname, tabid, tabtype, owner from 'informix'.systables where tabname = \"%s\" and tabtype in (\"T\",\"V\")", table);
		else
			sprintf(qry_stmt, "select tabname, tabid, tabtype, owner from 'informix'.systables where tabname matches \"%s\" and tabtype in (\"T\",\"V\")", table);
	} else
		sprintf(qry_stmt, "select tabname, tabid, tabtype, owner from 'informix'.systables where tabtype in (\"T\",\"V\") order by tabname");

	/* declare some cursors */
	$prepare tab_query from $qry_stmt;
	$declare tab_cursor cursor for tab_query;
	$prepare col_query from "select colname, tabid, colno, coltype, collength from 'informix'.syscolumns where tabid = ?";
	$declare col_cursor cursor for col_query;
	$prepare idx_query from "select idxname, owner, tabid, idxtype, clustered, part1, part2, part3, part4, part5, part6, part7, part8, part9, part10, part11, part12, part13, part14, part15, part16 from 'informix'.sysindexes where tabid = ?";
	$declare idx_cursor cursor for idx_query;
	$prepare idxcol_query from "select colname from 'informix'.syscolumns where tabid = ? and colno = ?";
	$declare idxcol_cursor cursor for idxcol_query;

	/* read the database for the table(s) and create some output */
	$open tab_cursor;
	$fetch tab_cursor into $systables.tabname, $systables.tabid, $systables.tabtype, $systables.owner;
	if (sqlca.sqlcode == SQLNOTFOUND)
		fprintf(stderr, "Table %s not found.\n", table);
	while (sqlca.sqlcode == SUCCESS) {
		rtrim(systables.tabname);
		rtrim(systables.owner);
		if ((systables.tabid >= 100 &&
		    strcmp(systables.tabname, "sysmenus") &&
		    strcmp(systables.tabname, "sysmenuitems") &&
		    strcmp(systables.tabname, "syscolatt") &&
		    strcmp(systables.tabname, "sysvalatt")) || tflg) {
			switch (systables.tabtype[0]) {
			    case 'T':
				printf("I N F O   F O R   T A B L E   %s.%s\n\n\n", systables.owner, systables.tabname);
				break;
			    case 'V':
				printf("I N F O   F O R   V I E W   %s.%s\n\n\n", systables.owner, systables.tabname);
				break;
			}
			print_sysindexes();
			print_syscolumns();
			if (!tflg)
				putchar('\f');
			else
				if (!(strchr(table, '*') == NULL &&
				    strchr(table, '[') == NULL &&
				    strchr(table, '?') == NULL))
					putchar('\f');
		}
		$fetch tab_cursor into $systables.tabname, $systables.tabid, $systables.tabtype, $systables.owner;
	}
	$close tab_cursor;

	exit(0);
}


print_sysindexes()
{
	char	*idx2col(), *order, *idxtype, *clustered;

	printf("Index name          Owner     Type    Cluster  Columns\n\n");

	$open idx_cursor using $systables.tabid;
	$fetch idx_cursor into $sysindexes.idxname, $sysindexes.owner,
	  $sysindexes.tabid, $sysindexes.idxtype, $sysindexes.clustered,
	  $sysindexes.part1, $sysindexes.part2, $sysindexes.part3, $sysindexes.part4,
	  $sysindexes.part5, $sysindexes.part6, $sysindexes.part7, $sysindexes.part8,
	  $sysindexes.part9, $sysindexes.part10, $sysindexes.part11, $sysindexes.part12,
	  $sysindexes.part13, $sysindexes.part14, $sysindexes.part15, $sysindexes.part16;
	while (sqlca.sqlcode == SUCCESS) {
		if (sysindexes.idxtype[0] == 'U')
			idxtype = "unique";
		else
			idxtype = "dupls";
		if (sysindexes.clustered[0] == 'C')
			clustered = "Yes";
		else
			clustered = "No";
		if (sysindexes.part1 < 0)
			order = "Decending";
		else
			order = "";
		printf("%-20.20s%-10.10s%-8.8s%-9.9s%-20.20s%s\n", sysindexes.idxname, sysindexes.owner, idxtype,
		  clustered, idx2col(sysindexes.part1), order);

		if (sysindexes.part2 != 0) {
			if (sysindexes.part2 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part2), order);
		}

		if (sysindexes.part3 != 0) {
			if (sysindexes.part3 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part3), order);
		}

		if (sysindexes.part4 != 0) {
			if (sysindexes.part4 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part4), order);
		}

		if (sysindexes.part5 != 0) {
			if (sysindexes.part5 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part5), order);
		}

		if (sysindexes.part6 != 0) {
			if (sysindexes.part6 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part6), order);
		}

		if (sysindexes.part7 != 0) {
			if (sysindexes.part7 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part7), order);
		}

		if (sysindexes.part8 != 0) {
			if (sysindexes.part8 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part8), order);
		}

		if (sysindexes.part9 != 0) {
			if (sysindexes.part9 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part9), order);
		}

		if (sysindexes.part10 != 0) {
			if (sysindexes.part10 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part10), order);
		}

		if (sysindexes.part11 != 0) {
			if (sysindexes.part11 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part11), order);
		}

		if (sysindexes.part12 != 0) {
			if (sysindexes.part12 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part12), order);
		}

		if (sysindexes.part13 != 0) {
			if (sysindexes.part13 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part13), order);
		}

		if (sysindexes.part14 != 0) {
			if (sysindexes.part14 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part14), order);
		}

		if (sysindexes.part15 != 0) {
			if (sysindexes.part15 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part15), order);
		}

		if (sysindexes.part16 != 0) {
			if (sysindexes.part16 < 0)
				order = "Decending";
			else
				order = "";
			printf("%-47.47s%-20.20s%s\n", "", idx2col(sysindexes.part16), order);
		}
		putchar('\n');

		$fetch idx_cursor into $sysindexes.idxname, $sysindexes.owner,
		  $sysindexes.tabid, $sysindexes.idxtype, $sysindexes.clustered,
		  $sysindexes.part1, $sysindexes.part2, $sysindexes.part3, $sysindexes.part4,
		  $sysindexes.part5, $sysindexes.part6, $sysindexes.part7, $sysindexes.part8,
		  $sysindexes.part9, $sysindexes.part10, $sysindexes.part11, $sysindexes.part12,
		  $sysindexes.part13, $sysindexes.part14, $sysindexes.part15, $sysindexes.part16;
	}
	$close idx_cursor;

	putchar('\n');
}


print_syscolumns()
{
	char	coltype[41], *nulls;
	int	prec, scale, len;

	printf("Column name          Type                                    Nulls\n\n");

	$open col_cursor using $systables.tabid;
	$fetch col_cursor into $syscolumns.colname, $syscolumns.tabid,
	  $syscolumns.colno, $syscolumns.coltype, $syscolumns.collength;
	while (sqlca.sqlcode == SUCCESS) {
		switch (syscolumns.coltype & SQLTYPE) {
		case SQLCHAR:
			sprintf(coltype, "char(%d)", syscolumns.collength);
			break;
		case SQLSMINT:
			strcpy(coltype, "smallint");
			break;
		case SQLINT:
			strcpy(coltype, "integer");
			break;
		case SQLDECIMAL:
			prec = PRECTOT(syscolumns.collength);
			scale = PRECDEC(syscolumns.collength);
			if (scale == 255)
				sprintf(coltype, "decimal(%d)", prec);
			else
				sprintf(coltype, "decimal(%d,%d)", prec, scale);
			break;
		case SQLSMFLOAT:
			strcpy(coltype, "smallfloat");
			break;
		case SQLFLOAT:
			strcpy(coltype, "float");
			break;
		case SQLMONEY:
			prec = PRECTOT(syscolumns.collength);
			scale = PRECDEC(syscolumns.collength);
			if (scale == 255)
				sprintf(coltype, "money(%d)", prec);
			else
				sprintf(coltype, "money(%d,%d)", prec, scale);
			break;
		case SQLSERIAL:
			strcpy(coltype, "serial");
			break;
		case SQLDATE:
			strcpy(coltype, "date");
			break;
		case SQLDTIME:
			prec = TU_START(syscolumns.collength);
			scale = TU_END(syscolumns.collength);
			sprintf(coltype, "datetime %s to %s", dtetim[prec][0], dtetim[scale][(scale == TU_FRAC) ? 2 : 0]);
			break;
		case SQLBYTES:
			strcpy(coltype, "byte");
			break;
		case SQLTEXT:
			strcpy(coltype, "text");
			break;
		case SQLVCHAR:
			prec = VCMAX(syscolumns.collength);
			scale = VCMIN(syscolumns.collength);
			sprintf(coltype, "varchar(%d,%d)", prec, scale);
			break;
		case SQLINTERVAL:
			prec = TU_START(syscolumns.collength);
			scale = TU_END(syscolumns.collength);
			len = TU_LEN(syscolumns.collength) - (scale - prec);
			sprintf(coltype, "interval %s to %s", dtetim[prec][(prec == TU_FRAC) ? 0 : len], dtetim[scale][(scale == TU_FRAC) ? 2 : 0]);
			break;
		}
		if (syscolumns.coltype & SQLNONULL)
			nulls = "no";
		else
			nulls = "yes";
		printf("%-21.21s%-40.40s%s\n", syscolumns.colname, coltype, nulls);

		$fetch col_cursor into $syscolumns.colname, $syscolumns.tabid,
		  $syscolumns.colno, $syscolumns.coltype, $syscolumns.collength;
	}
	$close col_cursor;

	putchar('\n');
}


/*******************************************************************************
* This function will trim trailing spaces from s.                              *
*******************************************************************************/

rtrim(s)
char	*s;
{
	int	i;

	for (i = strlen(s) - 1; i >= 0; i--)
		if (!isgraph(s[i]) || !isascii(s[i]))
			s[i] = '\0';
		else
			break;
}


/*******************************************************************************
* This function will returns a colname given an index part number.             *
*******************************************************************************/

char *idx2col(idxpart)
short idxpart;
{
	$static char	colname[19];
	$short	colno;

	colno = abs(idxpart);
	$open idxcol_cursor using $systables.tabid, $colno;
	$fetch idxcol_cursor into $colname;
	$close idxcol_cursor;

	return(colname);
}


