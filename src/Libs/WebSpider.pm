package WebSpider;
########################################################################
#Author: Bakkiaraj M
#License: MIT License
########################################################################
use strict;
use warnings;
use Crypt::SSLeay;
use Net::SSL;
use WWW::Mechanize;
use LWP;
use LWP::RobotUA;
use HTML::TreeBuilder;
use URI;
use Time::HiRes qw(usleep);
use SpiderConst;
use SpiderDB;
use Moose;
use threads;
use threads::shared;
use Thread::Queue;
#use Data::Dumper;

#Needed attributes while creating object
has 'searchText',is=>'rw',isa=>'Str',required=>1;
has 'searchTextType',is=>'rw',isa=>'Int',required=>1;
has 'restrictToDomain', is=>'rw',isa=>'Str',required=>1;
has 'isRestrictToDomain', is=>'rw', isa=>'Int';

has 'seedURL',is=>'rw',required=>1;
has 'noProxy',is=>'rw',required=>1;

has 'searchTextRegex',is=>'rw';
has 'restrictToDomainRegex', is=>'rw';
has 'userAgent',is=>'rw',isa=>'Str',default=>'Windows IE 6';

has 'continueSearch',is=>'rw',isa=>'Int',default=>1;
has 'pauseSearch',is=>'rw',isa=>'Int',default=>0;
has 'totSpiderThreads',is=>'rw',isa=>'Int';

has 'rawOutputQ',is=>'rw',isa=>'Thread::Queue';
has 'spiderOutputQ',is=>'rw',isa=>'Thread::Queue';
has 'searchResultsOutputQ',is=>'rw',isa=>'Thread::Queue';

has 'spiderBotName', is=>'ro',default=>'NPoint/'.SPIDERVERSION;
has 'spiderBotMail', is=>'ro',default=>'sam.bakki@gmail.com';
has 'gImgBrowser',  is=>'rw', isa=>'WWW::Mechanize';

#Class Methods

#Moose calls BUILD immediately after object construction (ie new() method)
#Use BUILD to initialise GtkSpiderGui object with 

sub BUILD
{
    my $self = shift @_;
    my $constArgsHashRef = shift @_; # Hash ref of arguments passed to constructor at the time of object creation
	
    $ENV{'PERL_NET_HTTPS_SSL_SOCKET_CLASS'} = "Net::SSL";
    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

    
    if ($self->searchTextType() == 1) #Normal text search
    {
       $self->searchTextRegex(quotemeta($self->searchText()));  
    }
    elsif ($self->searchTextType() == 2) #Perl regex search 
    {
        $self->searchTextRegex($self->searchText());    
    }
    
    #Restrict to Domain
    if ($self->restrictToDomain() eq '')
    {
    	$self->isRestrictToDomain(0);
    }
    else
    {
    	$self->isRestrictToDomain(1);
    	
    	if ($self->searchTextType() == 1) #Normal text search
        {
            $self->restrictToDomainRegex(quotemeta($self->restrictToDomain()));  
        }
        elsif ($self->searchTextType() == 2) #Perl regex search 
        {
            $self->restrictToDomainRegex($self->restrictToDomain());    
        }
    
    }
    
    return TRUE;
}

sub setOutputQs
{
	my $self = shift @_;
	
	my $rawOutputQ = shift @_;
	my $spiderOutputQ = shift @_;
	my $searchResultsOutputQ = shift @_;
	
	$self->rawOutputQ($rawOutputQ);
	$self->spiderOutputQ($spiderOutputQ);
	$self->searchResultsOutputQ($searchResultsOutputQ);
	
	return TRUE;
	
}

sub startSpiders
{
	my $self = shift @_;
    
    $self->printInGui("SPIDERSTART ::: searchText=".$self->searchTextRegex()." ::: seedURL=".$self->seedURL()." ::: noProxy=".$self->noProxy()."::: userAgent=".$self->userAgent()."::: totSpiderThreads=".$self->totSpiderThreads()." ::: searchTextType=".$self->searchTextType(),'rawq');
    
    #CReate Spider Database to store spider serach results
    
    #In DB, We should place only safe urls (i.e urls that is ready to process), so getSafeURL and add
    my $safeURL = $self->getSafeURL($self->seedURL());
    my $spiderDBObj = SpiderDB->new();
    $spiderDBObj->createDB();
    
    $spiderDBObj->addURLData($safeURL);
    
    #Start Spiders, totSpiderThreads will be set by GtkSpiderGui
	for my $tid(1..$self->totSpiderThreads())
	{
		
	   $self->printInGui("SPIDERTHREAD ::: START Thread ID= STh.$tid",'rawq');
	   #$self , $tid goes as args to searchInHTTPURL2
	   
	   threads->new('searchInURL',$self);

	   # Dummy search threads, ONly in Debug
	   #$spiderThreadObj=threads->new('searchInDummy',$self);
	}

	return TRUE;
}

sub pauseSpiders
{
	my $self = shift @_;
	
	$self->printInGui("SPIDERPAUSE :: "."Spider Threads will be Paused","rawq");
	$self->pauseSearch(TRUE);
	
	return TRUE;
}

sub resumeSpiders
{
    my $self=shift @_;
    
    $self->printInGui("SPIDERRESUME :: "."Spider Threads will be Resumed","rawq");
    $self->pauseSearch(FALSE);
    
    return TRUE;
}

sub stopSpiders
{
    my $self=shift @_;
    my $tid;
    $self->pauseSearch(FALSE);
    $self->continueSearch(FALSE);
    $self->printInGui("SPIDEREND ::: "."Wait for all Spider Threads to die","rawq");

    #Wait for all threads to complete
    for  $tid (threads->list(threads::running))
    {
        $tid->join();
        $self->printInGui("SPIDERTHREAD ::: KILLED Thread ID  =STh.".$tid->tid(),'rawq');
    }
    
    $self->printInGui("SPIDEREND ::: "."All Spider threads are Dead","rawq");;  
    $self->printInGui("SPIDEREND ::: ".$self->searchTextRegex()." ::: searchTextType=".$self->searchTextType()." ::: ".$self->seedURL(),"rawq");
    return TRUE;
}


# Use WWW::Mechanize to get the PNG chart image, WWW::Mechanize can be easily configured for proxy
sub getGChartImg
{
	my $self = shift @_;
	my $imgURL = shift @_;

	my $gImgBrowser = WWW::Mechanize->new(agent=>$self->userAgent(),noproxy=>$self->noProxy());
    
    #Set HTTPS protocol proxy. It should be set after creating LWP user agent object
    #http proxy with authentication
#    if ($ENV{'http_proxy'} =~ m/http:\/\/(.*)\:(.*)\@(.*)/)
#    {
#        
#        $ENV{'HTTPS_PROXY_USERNAME'} = $1;
#        $ENV{'HTTPS_PROXY_PASSWORD'} = $2;
#        $ENV{'HTTPS_PROXY'} = 'http://'.$3;
#    }
#    else
#    {
#        $ENV{'HTTPS_PROXY'} = $ENV{'http_proxy'};
#    }
    
	$self->printInGui(" getGChartImg ::: Get $imgURL :::","rawq");

    $gImgBrowser->get($imgURL);

    if(!$gImgBrowser->success()) 
    {
        $self->printInGui(" getGChartImg ::: ERROR :: While getting $imgURL ::: ".$gImgBrowser->status(),"rawq");
    }
      
    return $gImgBrowser->content();
}

sub getSafeURL
{
	my $self = shift @_;
	my $url = shift @_;
	my $uriObj;
    my $safeURL = "";
    
    $uriObj = URI->new($url);
    $safeURL = $uriObj->as_string;
            
    if (! defined ($uriObj->scheme))
    {
        $safeURL='http://'.$url;
        return $safeURL; 
    }
    elsif ($uriObj->scheme!~m/^http/i)
    {
        return ;
    }
    else
    {
    	return $safeURL;
    } 
            
}

#HTTP Web contents will be downloaded using LWP::RobotUA with adhere robot.txt rules
# More like a formal web spider
sub searchInURL
{
    my $self = shift @_;
    my $tid = threads->tid(); #Obtain own thread ID
    my $safeURL = "";
    my $txtContent = "";
    my $outgoingURL;
    my %outgoingURLs;
    my @pageLinks;
    my $link;
    my $response = 0;
    my $content = "";
    my $htmlTree;
    
    my $spiderDBObj = SpiderDB->new(); #This obj is singletone and all threads will use the same obj. Obj wont change and it needs not be shared. 
    
    my $browser = LWP::RobotUA->new($self->spiderBotName(),$self->spiderBotMail());
     
    $browser->default_header('Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    $browser->default_header('Accept-Charset'=>'iso-8859-1, utf-8, utf-16, *;q=0.3');
    $browser->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
   
    $browser->delay(0.01);
    
    if ($self->noProxy() == 0)
    {
    	$browser->env_proxy();

        #Set HTTPS protocol proxy. It should be set after creating LWP user agent object
		#http proxy with authentication
		if ($ENV{'http_proxy'} =~ m/http:\/\/(.*)\:(.*)\@(.*)/)
		{
		    $ENV{'HTTPS_PROXY_USERNAME'} = $1;
		    $ENV{'HTTPS_PROXY_PASSWORD'} = $2;
		    $ENV{'HTTPS_PROXY'} = 'http://'.$3;
		}
		else
		{
		    $ENV{'HTTPS_PROXY'} = $ENV{'http_proxy'};
		}
    }
    
    my $searchRegex = $self->searchTextRegex();
    my $restrictToDomainRegex = $self->restrictToDomainRegex();
    
    $self->printInGui(" THREAD STh.$tid ::: BORN :::","rawq");
    
    while($self->continueSearch())
    {
    	#If Spiders are in pause state, Do not search
    	if (!$self->pauseSearch())
    	{
	        #Clear link from Q
	        $safeURL = $spiderDBObj->getURLToProcess($tid);
	        if (! defined ($safeURL ))
	        {
	        	#Time to donate some CPU to others
                threads->yield();
                usleep(5); # Sleep 5 micro seconds
                next;
	        }
	        
	        #Process the URL and search for the search term
	       
	        # Check for Domain restrictions
	        if ($self->isRestrictToDomain())
	        {
	        	next if ($safeURL !~m/$restrictToDomainRegex/ogi);
	        }	
	                    
            #process the URL	        
	        $self->printInGui(" THREAD STh.$tid ::: PROCESS ::: $safeURL","rawq");
	        	        
	        eval
	        {
	        	$response = $browser->get($safeURL);
	        };
	        if($@)
	        {
	             $self->printInGui(" THREAD STh.$tid ::: ERROR ::: $safeURL ::: $@","rawq");
	             next;
	        }
	    
	        if(!$response->is_success()) #Search 
	        {
	            $self->printInGui(" THREAD STh.$tid ::: ERROR ::: ".$response->status_line,"rawq");
	            next;  
	        }
	
	        # Decode the contents
	        $content=$response->decoded_content(); #If it can't decode , it will return  undef
	        $content=$response->content() if (! defined $content);
	        
	        #Build HTML tree for find links & words
	        $htmlTree = HTML::TreeBuilder->new_from_content($content);
	        $htmlTree->elementify(); # just for safety
	        
	        $txtContent = $htmlTree->as_text();
	        
	        #Seach Search Term in plain text contents                 
	        if($txtContent=~m/$searchRegex/ogi)
	        {
	            # Update URL as Found URL
	            $spiderDBObj->foundSearchTermInURL($safeURL);
	            $self->printInGui(" $safeURL ::: ".scalar localtime(),"searchq");  
	            $self->printInGui(" THREAD STh.$tid ::: FOUND ::: $safeURL","rawq");     
	        }
	        
	        #Find all outgoing links in this URL
	        @pageLinks = $htmlTree->look_down( _tag => 'a' );
	    
	        # Go through all the tags in the HTML document  
	        foreach $link (@pageLinks) 
	        {
	            # Skip it if it's not a link
	            next if (!$link->attr('href'));
	                   
	            # Make sure it's an absolute URL
	            $outgoingURL = URI->new_abs($link->attr('href'),$response->base());
	            
	            #Remove last / , it is not needed. Usefull to put $url in DB
	            $outgoingURL =~s#/$##g;

	            # next if , if it is mailto or not HTTP
	            next if ($outgoingURL =~ /mailto\:/);
	            next if ($outgoingURL!~m/^http/i);
	            
	            # Check for Domain restrictions
                if ($self->isRestrictToDomain())
                {
                	#print "\n RES: ",$self->isRestrictToDomain() , $restrictToDomainRegex;
                	#print "\n next if: $outgoingURL";
                    next if ($outgoingURL !~m/$restrictToDomainRegex/ogi);
                }   
            
	            #Add it to %$outgoingURLs to avoid duplicates
	            $outgoingURLs{$outgoingURL}=1 if (!exists $outgoingURLs{$outgoingURL});       
	        }
	        
	        #Push URLs from HASH to Q
	        foreach $outgoingURL (keys %outgoingURLs)
	        {
	        	#In DB, We should place only safe urls (i.e urls that is ready to process), so getSafeURL and add
	        	$safeURL = $self->getSafeURL($outgoingURL);
	        	next if (!defined ($safeURL));
	        	
	        	# Add outgoing URL in to DB for further processing.
	        	#print "\n\n *** TH:$tid , Locked";
	        	my $criticalSecLock :shared;
	        	{
	        		lock($criticalSecLock);
	        	    #print "\n -----ADD: $safeURL , TH: $tid";
	        	
	        	    $spiderDBObj->addURLData($safeURL,1,$tid,'NULL');
	        	}
	        	
	        	#print "\n *** TH:$tid , UnLocked";
	        	
	            $self->printInGui(" $safeURL",'spiderq');
	            $self->printInGui(" THREAD$tid ::: OUTGO ::: $safeURL ::: ",'rawq');
	        }
	
	        #Time for clean up         
	        $htmlTree->delete();
   	
    	}#If 

        #Time to donate some CPU to others
        threads->yield();
        usleep(5); # Sleep 5 micro seconds
        
    } #While loop
    $self->printInGui(" THREAD STh.$tid ::: DEAD ::: ","rawq");
    
    return TRUE;
}

sub printInGui
{
	my $self = shift @_;
	my $what = shift @_;
	my $where = shift @_ || 'console';
	if ($where eq 'rawq')
	{
		$self->rawOutputQ()->enqueue(" $what\n");
	}
	elsif ($where eq 'spiderq')
    {
        $self->spiderOutputQ()->enqueue(" $what\n");
    }
    elsif ($where eq 'searchq')
    {
    	$self->searchResultsOutputQ()->enqueue(" $what\n");
    }
	else
	{
		print " $what\n";
	}
}

# Why to have shared object?
#We need to have shared object to work with threads else
# $self->continueSearch() will be always 1, even if we set to 0
# Running threads wont see the change beacuse continueSearch is a 
# Moose attribute which is not shared.
# Instead of trying to share each and every attribute in this class
# Just make the whole object as shared
# So any changes after threads started will be visible to other threads.
sub getSharedObj
{
    my $self= shift @_;
    my $shared_self : shared = shared_clone($self);
    return $shared_self;
}

#Dummy thread to find memory leak
sub searchInDummy
{
    my $self = shift @_;
    my $tid = threads->self()->tid(); #Obtain own thread ID
          
    while($self->continueSearch())
    {
        
        print "\n TH$tid , DUMMY OUT";
        
        
        threads->yield();
        usleep(5); # Sleep 5 micro seconds
        
    }

    print "\n DIE: $tid ";
    return 1;
}
##Moose destructor
#sub DEMOLISH
#{
#	my $self= shift @_;
#	print "\n Webspider demolish";
#}
#Do it for all classes so Moose will create fast object creation, so application runs faster
__PACKAGE__->meta->make_immutable();
no Moose;
TRUE;
