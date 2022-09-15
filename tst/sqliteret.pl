use strict;
use warnings;
use DBI;
use DBD::SQLite;
use Data::Dumper;

my $DBH = "";
my $STH = "";
my $sqlStmt = "";
#connect
#drop table URLTOSEARCH
$DBH = DBI->connect("dbi:SQLite:dbname=E:/Eclipse_WorkSpace/saaral-soft-search-spider/src/spiderDB.sqlite","","",{AutoCommit=>1, PrintError=>1, RaiseError=>1});

$DBH->{'AutoCommit'}=1;

#create Table
#$DBH->do (qq{create table SPIDERDATA ( id INTEGER PRIMARY KEY , url VARCHAR(100) NOT NULL , urlrepu BIGINT , urlposttid TEXT , urlprocesstid TEXT , UNIQUE(url) )}) or print "\n ERROR:", $DBH->errstr();

#insert values
#$sqlStmt = qq{INSERT INTO URLTOSEARCH (id, url , rep , processed) VALUES(NULL, ? , 1,0)};

#$STH = $DBH->prepare($sqlStmt) or print "\n ERROR:", $DBH->errstr();

#select

$STH = $DBH->prepare(qq{SELECT id FROM SPIDERDATA WHERE SPIDERDATA.url = ?}); 
my $arr = $DBH->selectrow_arrayref($STH,undef,'http://blogs.perl.org/');

print "\n ID: ", $arr->[0];
 
print "\n",Dumper ($arr);

#Close DBH
$DBH->disconnect();

undef $DBH;

