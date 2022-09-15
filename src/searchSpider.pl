#!/usr/bin/env perl
########################################################################
#Author: Bakkiaraj M
#License: MIT License
########################################################################
use strict;
use warnings;
use FindBin qw($RealBin); 
use lib "$RealBin/Libs";
use GtkSpiderGui;

my $spiderGuiObj=GtkSpiderGui->new(LibDir=>"$RealBin/Libs");
$spiderGuiObj->showSpiderGui();

exit(0);


