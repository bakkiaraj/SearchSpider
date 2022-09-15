package WebUtils;
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
use URI;
use Moose;
#use Data::Dumper;
use SpiderConst;

has 'httpProxy', is=>'rw', isa=>'Str';

sub BUILD
{
	$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "Net::SSL";
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
	
	return 1;
}

sub findWinProxy
{
	return "" unless $^O eq 'MSWin32';
}

sub connectSite
{
	my $self = shift @_;
	my $noproxy = shift@_;
	
	my $response;
	my $errCount = 0;
	
	my $browser = WWW::Mechanize->new(autocheck =>1, noproxy=>$noproxy);
    $browser->agent_alias('Linux Mozilla');
    $browser->timeout(35);
    
    #Check connectivity
    eval
    {
       $response = $browser->get('http://www.google.com');
    };
    if ($@)
    {
        $errCount++;
    }
    if (! $browser->success())
    {
        $errCount++;
    }
    
    return $errCount; #return 2 for errors. 0 for no errors
}

sub getWinHTTPProxy 
{
    my $self = shift @_;
    
    #Load Win32::TieRegistry
    eval
    {
        require Win32::TieRegistry;
        import Win32::TieRegistry;
    };
    return 0 if ($@);
    
    my $proxyEnabled = 0;
    my $proxyServer = ""; #proxy server with port
        
    $proxyEnabled = $Win32::TieRegistry::Registry->{'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ProxyEnable'};
    
    if ($proxyEnabled =~/0x0+$/) #only 0s
    {
        $proxyEnabled = 0;
    }
    else
    {
        $proxyEnabled = 1;
    }
    
    if ($proxyEnabled)
    {
        $proxyServer = 'http://'.$Win32::TieRegistry::Registry->{'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ProxyServer'};
        $ENV{'http_proxy'} = $proxyServer;
        
        #Connect site with proxy
        if ($self->connectSite(0) == 0)
        {
        	return INET_PROXY_SET;
        }
        else
        {
        	return INET_PROXY_SET_NOTWORKING; #Proxy found but not working.
        }
    } 
    else
    {
    	#No proxy info set in IE
    	return INET_NO_IE_PROXY; 
    }
    
    return
}
sub checkInternetConnection
{
	my $self = shift @_;
	my $errCount = 0;
	
	#Try with noProxy
	$errCount = $self->connectSite(1);
	if ($errCount == 0)
	{
	   #print "\n INFO: User have Direct Internet Connection";
	   return INET_DIRECT_CONN;
	}
	
	##Try with http_proxy environment variable, User might have set it already
	$errCount = $self->connectSite(0);
	   
    if ($errCount == 0)
    {
       #print "\n INFO: User have Internet Connection Via HTTP_PROXY Var";
       return INET_PROXY_CONN;
    }
    
    #If not return until here, No net connection
    return INET_NO_CONN; #No internet connction
}

#Do it for all classes so Moose will create fast object creation, so application runs faster
__PACKAGE__->meta->make_immutable();
no Moose;
1;
