use strict;
use warnings;
use Text::Reform;

my $FH;
my $line;

my @values;
open ($FH,'<','E:/temp/aaa.txt');
    

    #Fetch Data using DB iterator
    print '#'x119 , "\n";
    print form
    "#]]]]]] # [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[# ]]]] # [[[[[[[[[[[# [[[[[[[[[# ]]]#",
    'ID','URL','Repu','Post.Th','Proc.Th','Got';
    print '#'x119 , "\n";
    while ($line = <$FH>)
    {
    	chomp ($line);
        @values = split (/,/,$line);
        
        #print $FH $dbRowRef->[0],',',$dbRowRef->[1],',',$dbRowRef->[2],',',$dbRowRef->[3],',',$dbRowRef->[4],',',$dbRowRef->[5],"\n";
        print form
        "#]]]]]] | [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[| ]]]] | [[[[[[[[[[[| [[[[[[[[[| ]] #",
        
        $values[0],$values[1],$values[2],$values[3],$values[4],$values[5];

       
    }
    print '#'x119 , "\n";
close ($FH);
    