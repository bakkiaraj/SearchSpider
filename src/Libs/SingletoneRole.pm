package SingletoneRole;
########################################################################
#Author: Bakkiaraj M
#License: MIT License
########################################################################
use strict;
use warnings;
use SpiderConst;
use Moose::Role;

#Use hash because if you use scalar, Role can not be applied to multiple classes.
# Every classes see the same scalar because around function creates closure with scalar var.

my %_instances;

#Modify default new provided by Moose.
around 'new' => sub 
{
    my $orig = shift @_; #orginal function name
    my $class = shift @_;
    
    if (! defined $_instances{$class} )
    {
        $_instances{$class} = $class->$orig(@_);
    }
    return $_instances{$class};
};


TRUE;