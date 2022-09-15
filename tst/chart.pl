use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Queue;

use Glib qw/TRUE FALSE/;
use Gtk2 -init;

use Data::Dumper;
use Gtk2::Ex::Graph::GD;
use GD::Graph;
use GD::Graph::Data;

my @xlegend = (1..10);

$|=1;
my $gui;
my $table;

sub on_window1_destroy
{
	my $widget = shift @_;
	#my $userData = shift @_;
	
		Gtk2->main_quit;
}

sub updateGraph
{
#print "\n called";
my @data1 = map(rand(100),(1..10));
my @graph_data = (\@xlegend,\@data1,);


my $data = GD::Graph::Data->new(\@graph_data) or die GD::Graph::Data->error;
my $graph = Gtk2::Ex::Graph::GD->new(500, 300, 'bars');
my $image = $graph->get_image($data);

$table->attach_defaults($image,1,2,1,2);


return TRUE;
}

#Main

Glib::Object->set_threadsafe (TRUE);

$gui = Gtk2::Builder->new();
$gui->add_from_file('chart.glade');
$gui->connect_signals(undef);

$table=$gui->get_object('table1');

&updateGraph();
Glib::Timeout->add (180,\&updateGraph);

Gtk2->main();

