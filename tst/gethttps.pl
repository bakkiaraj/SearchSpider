use Crypt::SSLeay;
use Net::SSL;
use WWW::Mechanize;

$ENV{'PERL_NET_HTTPS_SSL_SOCKET_CLASS'} = "Net::SSL";
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'}=0;
    




my $mech = WWW::Mechanize->new();

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





my $url = 'https://chart.googleapis.com/chart?cht=p3&chd=t:60,40&chs=250x100&chl=Hello|World';

                $mech->get($url);
    
        if(!$mech->success()) 
        {
            #$self->printInGui(" THREAD$tid ::: ERROR ::: $safeURL ::: ".$mech->status(),"rawq");
            print "\n err2";  
        }
        else
        {
            print $mech->content();        	
        }


