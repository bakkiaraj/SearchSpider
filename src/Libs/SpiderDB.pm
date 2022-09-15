package SpiderDB;
########################################################################
#Author: Bakkiaraj M
#License: MIT License
########################################################################
#Note: This Moose class provides SQLite DB functionality for search Spider.
use strict;
use warnings;
use SpiderConst;
use DBI;
use DBD::SQLite;
use Moose;
with 'SingletoneRole'; #Only one object can be created.

use FindBin qw($RealBin); 


has 'spiderDBFileName',is=>'rw',isa=>'Str';
sub BUILD
{
	my $self = shift @_;
    my $constArgsHashRef = shift @_; # Hash ref of arguments passed to constructor at the time of object creation
    
    my $spiderDBFileName = $RealBin.'/'.SPIDER_DB_NAME;
	$self->spiderDBFileName($spiderDBFileName);
		
	return TRUE;
}


#Reads all the data from DB and pass it to data processor
sub processDBResults
{
	my $self = shift @_;
	my $outputFN = shift @_;
	my $dataProcessor = shift @_; #processor function
	
    my $dbHandle;
    my $stHandle;
    
    #Connect to DB
    $dbHandle = DBI->connect("dbi:SQLite:dbname=".$self->spiderDBFileName(),"","",{PrintError=>1, PrintWarn=>1}) or 
                         do {print "\n ERROR: processDBResults: Can not connect to DB ", $self->spiderDBFileName(); return FALSE;};
    
    #Select all data
    $stHandle = $dbHandle->prepare( qq{
                                       SELECT * FROM SPIDERDATA;
                                      } ) or print "\n ERROR: Can not prepare SELECT all data for getDBReadIterator ", $dbHandle->errstr();
    #Execute
    $stHandle->execute();
    
    #Pass the statement handle to process ths data
    $dataProcessor->($outputFN,$stHandle);
    
    #close and return    
    $dbHandle->disconnect();
    undef $dbHandle;   
}
#Retrives URL for processing.
# Looks for URL with 
# 1. urlprocessid = STh.Null - Not yet processed 
#  AND
# 2. foundsearchterm = 0 - Not yet processed
# 3. Orderby Desending order of urlrepu - Most reputated URL comes first
# 4. TOP 1 - pick only first row

sub getURLToProcess
{
    my $self = shift @_;
    my $tid = shift @_;
    
    $tid = 'STh.'.$tid;
    
    my $dbRow = "";
    my $dbHandle;
    my $stHandle;
    my $upHandle;
    
    #Connect to DB
    $dbHandle = DBI->connect("dbi:SQLite:dbname=".$self->spiderDBFileName(),"","",{PrintError=>1, PrintWarn=>1}) or 
                         do {print "\n ERROR: getURLToProcess: Can not connect to DB ", $self->spiderDBFileName(); return FALSE;};
    
    #Select 
    $stHandle = $dbHandle->prepare( qq{
                                       SELECT * FROM SPIDERDATA WHERE  urlprocesstid='STh.NULL' AND foundsearchterm=0 ORDER BY urlrepu DESC LIMIT 1;
                                      } ) or print "\n ERROR: Can not prepare SELECT URL for getURLToProcess ", $dbHandle->errstr();
                                      
    $dbRow = $dbHandle->selectrow_arrayref($stHandle);
    
     #0th element is ID. It should be > 0 if exists
    if (defined ($dbRow->[0]) && $dbRow->[0] > 0)
    {
      	#This url is going to be processed. So Update the urlprocesstid to current thread.
    	#Update processing thread id
        $upHandle = $dbHandle->prepare( qq{
                                            UPDATE SPIDERDATA SET urlprocesstid=? WHERE id=?
                                          } ) or print "\n ERROR: Can not prepare UPDATE ".$dbRow->[1]." for getURLToProcess ", $dbHandle->errstr();
                                              
        $dbHandle->do('BEGIN EXCLUSIVE TRANSACTION') or print "\n ERROR: Can not BEGIN EXCLUSIVE transaction ", $dbHandle->errstr();
    
        $upHandle->execute($tid,$dbRow->[0]) or 
                   print "\n ERROR: Can not EXECUTE UPDATE $dbRow->[0],  ", $upHandle->errstr();
    
        $dbHandle->do('COMMIT TRANSACTION')  or print "\n ERROR: Can not COMMIT EXCLUSIVE transaction ", $dbHandle->errstr();
        
        #print "\n ** URL: ",$dbRow->[1]," Repu: ",$dbRow->[2];    
        #close and return    
        $dbHandle->disconnect();
        undef $dbHandle;
        
        #return URL
    	return $dbRow->[1];
    }
    else
    {
    	$dbHandle->disconnect();
        undef $dbHandle;
        #return undef
    	return ;
    }
}


sub foundSearchTermInURL
{
    my $self = shift @_;
    my $url = shift @_;
    
    my $dbHandle;
    my $upHandle;
    
    #Connect to DB
    $dbHandle = DBI->connect("dbi:SQLite:dbname=".$self->spiderDBFileName(),"","",{PrintError=>1, PrintWarn=>1}) or 
                         do {print "\n ERROR: foundSearchTermInURL: Can not connect to DB ", $self->spiderDBFileName(); return FALSE;};
    
    $upHandle = $dbHandle->prepare( qq{
                                        UPDATE SPIDERDATA SET urlrepu=(urlrepu+5) , foundsearchterm=1 WHERE url=?
                                      } ) or print "\n ERROR: Can not prepare UPDATE $url for foundSearchTermInURL , ", $dbHandle->errstr();
                                              
    $dbHandle->do('BEGIN EXCLUSIVE TRANSACTION') or print "\n ERROR: Can not BEGIN EXCLUSIVE transaction ", $dbHandle->errstr();
    
    $upHandle->execute($url) or 
           print "\n ERROR: Can not EXECUTE UPDATE $url in foundSearchTermInURL ,  ", $upHandle->errstr();
    
    $dbHandle->do('COMMIT TRANSACTION')  or print "\n ERROR: Can not COMMIT EXCLUSIVE transaction ", $dbHandle->errstr();
        
    #close and return    
    $dbHandle->disconnect();
    undef $dbHandle;
        
    return TRUE;
}



sub addURLData
{
    my $self = shift @_;
    
    my $url = shift @_;
    my $urlrepu = shift @_ || 1;
    my $urlposttid = shift @_ || 'INIT';
    my $urlprocesstid = shift @_ || 'NULL';
    
    my $dbHandle;
    my $stHandle;
    my $dbRow = "";
    my $upHandle;
    
    $urlposttid = 'STh.'.$urlposttid;
    $urlprocesstid = 'STh.'.$urlprocesstid;
        
    #Connect to DB
    eval
    {    
        $dbHandle = DBI->connect("dbi:SQLite:dbname=".$self->spiderDBFileName(),"","",{sqlite_use_immediate_transaction => 1,PrintError=>1, PrintWarn=>1}); 
                         
    };
    if ($@)
    {
    	print "\n ERROR: addURLData: Can not connect to DB ", $self->spiderDBFileName(); 
    	return FALSE;
    }
    
    
    #Check URL already avilable?
    
    
    eval
    {
	    #Select 
	    $stHandle = $dbHandle->prepare( qq{
	                                       SELECT id FROM SPIDERDATA WHERE SPIDERDATA.url = ?
	                                      } ) or die "\n ERROR: Can not prepare SELECT $url for isURLAlreadyAvilable , ", $dbHandle->errstr();
	    
	    $dbRow = $dbHandle->selectrow_arrayref($stHandle,undef,$url) ;
	        
	    #0th element is ID. It should be > 0 if exists
	    if (defined ($dbRow->[0]) && $dbRow->[0] > 0)
	    {
	        #URL is already in DB , SO increase its reputation.
	        #print "\n *** UPDATE: $url";
	        $upHandle = $dbHandle->prepare( qq{
	                                           UPDATE SPIDERDATA SET urlrepu=(urlrepu+1) WHERE id=?
	                                          } ) or die "\n ERROR: Can not prepare UPDATE $url for isURLAlreadyAvilable ,", $dbHandle->errstr();
	                                              
	        $dbHandle->do('BEGIN EXCLUSIVE TRANSACTION') or die "\n ERROR: Can not BEGIN EXCLUSIVE transaction ", $dbHandle->errstr();
	    
	        $upHandle->execute($dbRow->[0]) or 
	             die "\n ERROR: Can not EXECUTE UPDATE $dbRow->[0],  ", $upHandle->errstr();
	    
	        $dbHandle->do('COMMIT TRANSACTION')  or die "\n ERROR: Can not COMMIT EXCLUSIVE transaction ", $dbHandle->errstr();
        
	     }
	    else #URL is not avilable , So Add it into DB
	    {
		     #print "\n *** ADD: $url";           
		    $stHandle = $dbHandle->prepare( qq{
		                                       INSERT INTO SPIDERDATA ( id , url , urlrepu , urlposttid , urlprocesstid , foundsearchterm ) VALUES (NULL , ? , ? , ? , ? , 0 )
		                                      } ) or die "\n ERROR: Can not prepare INSERT $url into DB ", $dbHandle->errstr();
		    
		    $dbHandle->do('BEGIN EXCLUSIVE TRANSACTION') or die "\n ERROR: Can not BEGIN EXCLUSIVE transaction ", $dbHandle->errstr();
		    
		    $stHandle->execute($url,$urlrepu,$urlposttid,$urlprocesstid) or 
		                   die "\n ERROR: Can not EXECUTE INSERT $url ", $stHandle->errstr();
		    
		    $dbHandle->do('COMMIT TRANSACTION')  or die "\n ERROR: Can not COMMIT EXCLUSIVE transaction ", $dbHandle->errstr();
		}
    };
    
    if ($@)
    {
    	print "\n $urlposttid : ERROR: $@ , DB ERROR: ", $dbHandle->errstr() , " \n ";
    }
    
    #close and return    
    $dbHandle->disconnect();
    undef $dbHandle;    

    return TRUE;	
}

#CReate Spider Database with following Schema
#
# 0. id              - INTEGER PRIMARY KEY
# 1. url             - VARCHAR(100) NOT NULL
# 2. urlrepu         - BIGINT
# 3. urlposttid      - TEXT
# 4. urlprocesstid   - TEXT
# 5. foundsearchterm - INTEGER (Boolean , 1 or 0)
# Constraint - UNIQUE(url)

sub createDB
{
	my $self = shift @_;
	my $dbHandle;
	#Remove the DB if it already exists.
	unlink ($self->spiderDBFileName()) if (-e $self->spiderDBFileName());
	sleep (1);
	print "\n ERROR: DB ",$self->spiderDBFileName()," already exists and can not delete." if (-e $self->spiderDBFileName());
	
	#Create sqlite DB & Inital table
	$dbHandle = DBI->connect("dbi:SQLite:dbname=".$self->spiderDBFileName(),"","",{AutoCommit=>1, PrintError=>1, PrintWarn=>1}) or 
	                     do {print "\n ERROR: createDB: Can not connect to DB ", $self->spiderDBFileName(); return FALSE;};

    #Create Table
    $dbHandle->do( qq{ 
    	                 CREATE TABLE SPIDERDATA ( id INTEGER PRIMARY KEY , url VARCHAR(100) NOT NULL , urlrepu BIGINT , urlposttid TEXT , urlprocesstid TEXT , foundsearchterm INTEGER , UNIQUE(url) )
                     }) or print "\n ERROR: Can not create table ", $dbHandle->errstr();
    
    #Create Index                 
    $dbHandle->do( qq{ 
                         CREATE  INDEX  spiderdata_urlprocesstid_idx  ON SPIDERDATA(urlprocesstid  DESC)   
                     }) or print "\n ERROR: Can not create index urlprocesstid_idx", $dbHandle->errstr();
                     
                     
    #Create Index                 
    $dbHandle->do( qq{ 
                         CREATE  INDEX  spiderdata_urlrepu_idx  ON SPIDERDATA(urlrepu  DESC)   
                     }) or print "\n ERROR: Can not create index urlrepu_idx", $dbHandle->errstr();
                     
    #Close Connection
    $dbHandle->disconnect();
    undef $dbHandle;
    
	return TRUE;
}

#Do it for all classes so Moose will create fast object creation, so application runs faster
__PACKAGE__->meta->make_immutable(inline_constructor => 0); #Since this is a Singleton class , i.e its own new function. 
#To avoid warning use inline_constructor => 0
no Moose;
TRUE;