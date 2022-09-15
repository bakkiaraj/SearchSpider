use strict;
use warnings;
use DBI;

my $DBH = "";

$DBH = DBI->connect("dbi:SQLite:dbname=/mnt/E/Eclipse_WorkSpace/saaral-soft-search-spider/tst/testdb.sqlite","","");

my $sth = $DBH->prepare("SELECT * FROM STU");

$sth->execute( );

my @row;

while ( @row = $sth->fetchrow_array() ) {
    print "@row\n";
  }

undef $DBH;
