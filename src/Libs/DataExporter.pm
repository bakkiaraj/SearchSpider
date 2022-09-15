package DataExporter;
########################################################################
#Author: Bakkiaraj M
#License: MIT License
########################################################################
#Note: This Moose class for exporting Search Results to various formats.
use strict;
use warnings;
use SpiderConst;
use SpiderDB;
use Moose;
use feature qw/switch/;
use File::Copy;
use Text::Reform;

#use Data::Dumper;


#Class Functions to process the Data retrived from DB.

#Process the DB results as a Excel (CSV) file, This function should be called from SpiderDB's processDBResults
sub _processAsExcel
{
	my $outputFN = shift @_;
    my $stHandle = shift @_;
    
    my $FH;
    my $dbRowRef = "";
    
    open ($FH,'>',$outputFN) or print "\n ERROR: Can not open CSV file $outputFN for writing. $!";
    
    #Write CSV template
    print $FH "URL ID, URL, URL's Reputation, Posting Thread's ID, Processed Thread's ID, Found Search Term?\n";
    #Fetch Data using DB iterator
    while ($dbRowRef = $stHandle->fetchrow_arrayref())
    {
        #print "\n ", Dumper($dbRowRef); 
        print $FH $dbRowRef->[0],',',$dbRowRef->[1],',',$dbRowRef->[2],',',$dbRowRef->[3],',',$dbRowRef->[4],',',$dbRowRef->[5],"\n"; 
    }
    close ($FH);
    
    return TRUE;
}

sub _processAsSQLite
{
    my $self = shift @_;
    my $srcFN = shift @_;
    my $desFN = shift @_;
    
    copy($srcFN,$desFN) or print "\n ERROR: Can not copy $srcFN to $desFN, $!";
    
    if (-e $desFN)
    {
    	return TRUE;
    }
    else
    {
    	return FALSE;
    }
}

sub _processAsText
{
    my $outputFN = shift @_;
    my $stHandle = shift @_;
    
    my $FH;
    my $dbRowRef = "";
    
    open ($FH,'>',$outputFN) or print "\n ERROR: Can not open Text file $outputFN for writing. $!";
    
    #Write Headers
    print $FH '#'x119 , "\n";
    print $FH form
    "#]]]]]] # [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[# ]]]] # [[[[[[[[[[[# [[[[[[[[[# ]]]#",
    'ID','URL','Repu','Post.Th','Proc.Th','Got';
    print $FH '#'x119 , "\n";
    
    #Fetch Data using DB iterator
    while ($dbRowRef = $stHandle->fetchrow_arrayref())
    {
        print $FH form
        "#]]]]]] | [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[| ]]]] | [[[[[[[[[[[| [[[[[[[[[| ]] #",        
         $dbRowRef->[0],$dbRowRef->[1],$dbRowRef->[2],$dbRowRef->[3],$dbRowRef->[4],$dbRowRef->[5]; 
    }
    print $FH '#'x119 , "\n";
    close ($FH);
    
    return TRUE;
}

sub _processAsHTML
{
    my $outputFN = shift @_;
    my $stHandle = shift @_;
    
    my $FH;
    my $dbRowRef = "";
    
    open ($FH,'>',$outputFN) or print "\n ERROR: Can not open HTML file $outputFN for writing. $!";
    
    #Write Headers
    print $FH <<"HTML_HEADER";
    <html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>NPoint Search Spider Results - </title>
 <style type="text/css">
body { 
    margin:0; 
    padding:20px; 
    font:13px "Lucida Grande", "Lucida Sans Unicode", Helvetica, Arial, sans-serif;
    }
p,
table, caption, td, tr, th {
    margin:0;
    padding:0;
    font-weight:normal;
    }
table {
    border-collapse:collapse;
    margin-bottom:15px;
    width:100%;
    }
    caption {
        text-align:left;
        font-size:15px;
        padding-bottom:10px;
        }
    table td,
    table th {
        padding:5px;
        border:1px solid #fff;
        border-width:0 1px 1px 0;
        }
    thead th {
        background:#91c5d4;
        }
    thead th[colspan],
    thead th[rowspan] {
            background:#66a9bd;
            }
    tbody th {
        text-align:left;
        background:#91c5d4;
        }
    tbody td {
        text-align:center;
        background:#d5eaf0;
        }
</style> </head> <body>
HTML_HEADER

    #Write Table
    print $FH <<"HTML_TABLE";
    <table> 
<caption><center>NPoint Search Spider Results</center></caption>
<thead>    
        <tr>
            <th scope="col">URL ID</th>
            <th scope="col">URL</th>
            <th scope="col">URL's Reputation</th>
            <th scope="col">URL Posting Thread</th>
            <th scope="col">URL Processed Thread</th>
            <th scope="col">Found Search Term?</th>
        </tr>        
</thead>
<tbody>
HTML_TABLE
    
    #Fetch Data using DB iterator
    while ($dbRowRef = $stHandle->fetchrow_arrayref())
    {
    	#Write Data into HTML Table
    	print $FH <<"HTML_DATA";
    <tr>
	    <td>$dbRowRef->[0]</td>
	    <th scope="row"><a target="_blank" href="$dbRowRef->[1]">$dbRowRef->[1]</a></th>
	    <td>$dbRowRef->[2]</td>
	    <td>$dbRowRef->[3]</td>
	    <td>$dbRowRef->[4]</td>
	    <td>$dbRowRef->[5]</td>
	    </tr>
HTML_DATA
 
    }
    
    #Write Footer
    print $FH <<"HTML_FOOTER";
    </tbody> </table> </body> </html>
HTML_FOOTER
    close ($FH);
    
    return TRUE;
}


sub exportSearchResults
{
	my $self = shift @_;
	my $fileName = shift @_;
	my $fileType = shift @_;
	
	my $spiderDBObj = SpiderDB->new();
	
	#Delete if the file presents
    unlink ($fileName) if (-e $fileName);
    	
	#Get Data & Process it
	if ($fileType eq '.csv'){$spiderDBObj->processDBResults($fileName,\&_processAsExcel);}
    if ($fileType eq '.sqlite'){$self->_processAsSQLite($spiderDBObj->spiderDBFileName(),$fileName);} #Just copy of the DB
    if ($fileType eq '.htm'){$spiderDBObj->processDBResults($fileName,\&_processAsHTML);}
    if ($fileType eq '.txt'){$spiderDBObj->processDBResults($fileName,\&_processAsText);}
 
	
}

#Do it for all classes so Moose will create fast object creation, so application runs faster
__PACKAGE__->meta->make_immutable();
no Moose;
TRUE;