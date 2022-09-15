package SpiderConst;
########################################################################
#Author: Bakkiaraj M
#License: MIT License
########################################################################
#Note: This is a normal module to export constants not a Moose class.
use strict;
use warnings;
use base 'Exporter';

#Constants
#Define constants

#Add constant Here
use constant
{
	#TRUE, FALSE is drived from Glib module. So it can be used for any GTK functions.
    TRUE  => 1,
    FALSE => 0, # can't use !TRUE at this point

	
    MSG_ERR => 40,
    MSG_WAR => 41,
    MSG_INFO => 42,
    
    INET_DIRECT_CONN => 31,
    INET_PROXY_CONN => 32,
    INET_NO_CONN =>33,
    
    INET_PROXY_SET => 35,
    INET_PROXY_SET_NOTWORKING => 36,
    INET_NO_IE_PROXY => 37,
    
    SPIDERVERSION => '1.7.0',
    
    SPIDER_DB_NAME=>'spiderDB.sqlite',
    
};

#Also in EXPORT LIST, so it will be imported automatically
our @EXPORT = qw(SPIDER_DB_NAME SPIDERVERSION TRUE FALSE MSG_ERR MSG_WAR INET_DIRECT_CONN INET_PROXY_CONN 
                 INET_NO_CONN INET_PROXY_SET INET_PROXY_SET_NOTWORKING INET_NO_IE_PROXY MSG_INFO);

TRUE;