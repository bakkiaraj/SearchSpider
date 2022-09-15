#!/usr/bin/perl
use strict;
use warnings;
use Glib qw(TRUE FALSE);
use Gtk2 -init;

my $window = Gtk2::Window -> new();
$window -> signal_connect(
    delete_event => sub {
  Gtk2 -> main_quit;
  return FALSE;
    });
$window -> set_title("MyBrowser");
$window -> set_default_size(600, 400);

$window -> show_all();
my $op = Gtk2::PrintOperation->new;

$op->signal_connect(
    status_changed => sub{
  print "status changÃ© en " . $op->get_status . "\n";
  if ($op->is_finished ){
      print "PDF Done\n";
  }
    });
Gtk2 -> main;