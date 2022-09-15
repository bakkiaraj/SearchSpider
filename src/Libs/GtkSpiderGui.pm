package GtkSpiderGui;
########################################################################
#Author: Bakkiaraj M
#License: MIT License
########################################################################
use strict;
use warnings;
use Moose;
use threads;
use threads::shared;
use Thread::Queue;
use WebUtils;
use WebSpider;
use SpiderConst;
use DataExporter;
use Glib;
#Do not enable -threads-init, in Windows XP GTK, Linux active perl 5.12 it causes GUI update problem
use Gtk2 qw/-init/;
#use Data::Dumper;
use Time::HiRes qw(usleep sleep);
use feature qw/switch/;

#Class Attibutes
# Add class attribute type as well as as "isa" item , So it is very easy to understand its type in future

# Note: Do not add GTK Widgets as a Moose members like below
#       has 'infoLabel', is=>'rw', isa=>'Gtk2::Label';
# This approach leaks memory in muti threads (After one round of thread execution completes.)
# So always refer the GTK widgets via absolute refer from glade object
# Ex: $self->spiderGuiGlade()->get_object('saveasDataBut')->set_sensitive(FALSE);
#     

has 'spiderGuiGlade', is => 'rw', isa => 'Gtk2::Builder';
has 'spiderMainWin', is => 'rw', isa => 'Gtk2::Window';
has 'InfoWin', is => 'rw', isa => 'Gtk2::Window';
has 'infoLabel', is => 'rw', isa => 'Gtk2::Label';
has 'searchTextEnt', is => 'rw', isa => 'Gtk2::Entry';
has 'restrictDomainTextEnt', is => 'rw', isa => 'Gtk2::Entry';
has 'isRegexSearchCheckBut', is => 'rw', isa => 'Gtk2::CheckButton';
has 'searchTextType', is => 'rw', isa => 'Int', default => 1;
has 'seedSiteTextEnt', is => 'rw', isa => 'Gtk2::Entry';
has 'searchResultsTextView', is => 'rw', isa => 'Gtk2::TextView';
has 'spiderQTextView', is => 'rw', isa => 'Gtk2::TextView';
has 'rawSpiderTextView', is => 'rw', isa => 'Gtk2::TextView';
has 'useProxyCheckBut', is => 'rw', isa => 'Gtk2::CheckButton';
has 'proxyHostTextEnt', is => 'rw', isa => 'Gtk2::Entry';
has 'rawSpiderTextViewBuffer', is => 'rw', isa => 'Gtk2::TextBuffer';
has 'spiderQTextViewBuffer', is => 'rw', isa => 'Gtk2::TextBuffer';
has 'searchResultsTextViewBuffer', is => 'rw', isa => 'Gtk2::TextBuffer';
has 'option2HButBox', is => 'rw', isa => 'Gtk2::HButtonBox';
has 'infoProgressBar', is => 'rw', isa => 'Gtk2::ProgressBar';
has 'updateInfoProgressTimeOutTag', is => 'rw', isa => 'Int', default => 0;
has 'updateEventsTimeOutTag', is => 'rw', isa => 'Int', default => 0;
has 'pauseBut', is => 'rw', isa => 'Gtk2::ToggleButton';
has 'chrtImage', is => 'rw', isa => 'Gtk2::Image';
has 'workingAniGtkImage', is => 'rw', isa => 'Gtk2::Image';
has 'gchartCounter', is => 'rw', isa => 'HashRef', auto_deref => 1, default => sub {{ 'RESULTS' => 0, 'OUTURL' => 0 };};
has 'gchartSearchHealth', is => 'rw', isa => 'ArrayRef', default => sub {[];};
has 'gchartBucketSize', is => 'rw', isa => 'Int', default => 100;
has 'updateGChartCheckBut', is => 'rw', isa => 'Gtk2::CheckButton';

#Dynamic GTK components, Below are the components will not be in Glade file
# instead, it will be created dynamically and added to the relevent place holder in glade file
has 'spiderThreadsComboEnt', is => 'rw', isa => 'Gtk2::ComboBoxEntry';

has 'WebSpiderObj', is => 'rw', isa => 'WebSpider';

has 'webUtilsObj', is => 'rw', isa => 'WebUtils';

has 'rawOutputQ', is => 'rw', isa => 'Thread::Queue';
has 'spiderOutputQ', is => 'rw', isa => 'Thread::Queue';
has 'searchResultsOutputQ', is => 'rw', isa => 'Thread::Queue';

has 'noProxy', is => 'rw', isa => 'Int';
has 'maxSpiderThreads', is => 'ro', isa => 'Int', default => '8'; #Set max number of Spider Threads. 8 is stable now.
has 'totSpiderThreads', is => 'rw', isa => 'Int', default => '2';
has 'spidersRunning', is => 'rw', isa => 'Int', default => '0';

has 'LibDir', is => 'rw', isa => 'Str', required => 1;


#Moose calls BUILD immediately after object construction (ie new() method)
#Use BUILD to initialise GtkSpiderGui object with 

sub BUILD {
    my $self = shift @_;

    my $constArgsHashRef = shift @_; # Hash ref of arguments passed to constructor at the time of object creation

    my $gladeGUIFile = "";
    my $infoWorkingWinAniFile = "";

    $| = 1;

    Glib::Object->set_threadsafe(TRUE);

    my $spiderGuiBuilder = Gtk2::Builder->new();

    #Look for GUI file
    if (defined $PerlApp::VERSION) {
        #Running from perlapp created exe
        $gladeGUIFile = PerlApp::extract_bound_file('spiderGui.glade');
        $infoWorkingWinAniFile = PerlApp::extract_bound_file('infoworking.gif');
    }
    else {
        #For normal perl run
        $gladeGUIFile = $self->LibDir() . '/spiderGui.glade';
        $infoWorkingWinAniFile = $self->LibDir() . '/infoworking.gif';
    }

    #Check File avilability
    if (-s $gladeGUIFile) {
        $spiderGuiBuilder->add_from_file($gladeGUIFile);
    }
    else {
        my $dialog = Gtk2::MessageDialog->new(undef, 'modal', 'error', 'ok', "Error in Loading...\nGui file spiderGui.glade is not found under \n" . $gladeGUIFile . "
    	                                       \n NPoint Search Spider can not run. \n\n Download the sources again from
    	                                       \n http://code.google.com/p/saaral-soft-search-spider/");
        $dialog->set_title('NPoint Search Spider - Error');
        $dialog->run;
        $dialog->destroy;
        exit -1;
    }

    #Connect signals
    $spiderGuiBuilder->connect_signals(undef, $self);

    #Add gui controls here
    $self->spiderMainWin($spiderGuiBuilder->get_object('MainWin'));
    #Hide until we finish our construction
    $self->spiderMainWin()->hide();

    #Construct InfoWindow
    $self->InfoWin($spiderGuiBuilder->get_object('InfoWin'));
    $self->InfoWin()->hide(); #Hide it initially
    $self->infoLabel($spiderGuiBuilder->get_object('infoLabel'));
    $self->workingAniGtkImage($spiderGuiBuilder->get_object('workingAniGtkImage'));

    #Load GIF animation in InfoWindow
    $self->workingAniGtkImage()->set_from_animation(Gtk2::Gdk::PixbufAnimation->new_from_file($infoWorkingWinAniFile));

    $self->showStatus(" Loading Search Spider... ", MSG_INFO);

    #Construct GUI
    $self->spiderGuiGlade($spiderGuiBuilder);
    $self->searchTextEnt($spiderGuiBuilder->get_object('searchTextEnt'));
    $self->seedSiteTextEnt($spiderGuiBuilder->get_object('seedSiteTextEnt'));
    $self->restrictDomainTextEnt($spiderGuiBuilder->get_object('restrictDomainTextEnt'));
    $self->isRegexSearchCheckBut($spiderGuiBuilder->get_object('isRegexSearchCheckBut'));
    $self->searchResultsTextView($spiderGuiBuilder->get_object('searchResultsTextView'));
    $self->spiderQTextView($spiderGuiBuilder->get_object('spiderQTextView'));
    $self->rawSpiderTextView($spiderGuiBuilder->get_object('rawSpiderTextView'));
    $self->useProxyCheckBut($spiderGuiBuilder->get_object('useProxyCheckBut'));
    $self->proxyHostTextEnt($spiderGuiBuilder->get_object('proxyHostTextEnt'));
    $self->option2HButBox($spiderGuiBuilder->get_object('option2HButBox'));
    $self->infoProgressBar($spiderGuiBuilder->get_object('infoProgressBar'));

    #Note Looks like having GTK2 (Gtk2::Button) buttons as a Moose Member leaks memory in muti thread environment.
    # So always refer the buttons as a absolute reference through glade Object. Do not store in Moose
    # Member and use it

    $self->pauseBut($spiderGuiBuilder->get_object('pauseBut'));

    $self->chrtImage($spiderGuiBuilder->get_object('chrtImage'));

    $self->updateGChartCheckBut($spiderGuiBuilder->get_object('updateGChartCheckBut'));

    $self->infoProgressBar()->hide();

    $self->updateGChartCheckBut()->set_active(TRUE);

    $self->pauseBut()->set_sensitive(FALSE); #Gray out pause button @ startup

    $self->spiderGuiGlade()->get_object('stopBut')->set_sensitive(FALSE);
    $self->spiderGuiGlade()->get_object('saveasDataBut')->set_sensitive(FALSE);

    #Dynamic controls creation
    my $spiderThreadsComboEnt = Gtk2::ComboBoxEntry->new_text();
    for my $i (1 .. $self->maxSpiderThreads()) {
        $spiderThreadsComboEnt->append_text($i);
    }
    $spiderThreadsComboEnt->set_active(TRUE);
    $spiderThreadsComboEnt->show();
    $self->spiderThreadsComboEnt($spiderThreadsComboEnt);

    #Add the dynamic controls to Glade UI file
    #pack_start($button, $expand, $fill, $padding)
    $self->option2HButBox()->pack_start($spiderThreadsComboEnt, FALSE, FALSE, 0);
    $self->option2HButBox()->reorder_child($spiderThreadsComboEnt, 1);

    my $rawSpiderTextViewBuffer = $self->rawSpiderTextView()->get_buffer();
    $rawSpiderTextViewBuffer->set_text("");
    $self->rawSpiderTextViewBuffer($rawSpiderTextViewBuffer);
    my $spiderQTextViewBuffer = $self->spiderQTextView()->get_buffer();
    $spiderQTextViewBuffer->set_text("");
    $self->spiderQTextViewBuffer($spiderQTextViewBuffer);
    my $searchResultsTextViewBuffer = $self->searchResultsTextView()->get_buffer();
    $searchResultsTextViewBuffer->set_text("");
    $self->searchResultsTextViewBuffer($searchResultsTextViewBuffer);

    #Create Text Tag
    $self->rawSpiderTextViewBuffer()->create_tag('info', 'foreground-gdk' => Gtk2::Gdk::Color->new(18 * 256, 0, 217 * 256));
    $self->spiderQTextViewBuffer()->create_tag('info', 'foreground-gdk' => Gtk2::Gdk::Color->new(217 * 256, 141 * 256, 0));
    $self->searchResultsTextViewBuffer()->create_tag('info', 'foreground-gdk' => Gtk2::Gdk::Color->new(5 * 256, 181 * 256, 58 * 256));

    my $rawOutputQ = Thread::Queue->new();
    $self->rawOutputQ($rawOutputQ);
    my $spiderOutputQ = Thread::Queue->new();
    $self->spiderOutputQ($spiderOutputQ);
    my $searchResultsOutputQ = Thread::Queue->new();
    $self->searchResultsOutputQ($searchResultsOutputQ);

    #Show main window now
    $self->spiderMainWin()->show();

    $self->showStatus(" Detecting Internet Connectivity...", MSG_INFO);


    #Determine HTTP Proxy
    my $webUtilsObj = WebUtils->new();

    $self->webUtilsObj($webUtilsObj);

    my $internetConnStatus = $self->webUtilsObj()->checkInternetConnection();

    if ($internetConnStatus == INET_DIRECT_CONN) {
        $self->showStatus("Direct Internet connection is avilable. :)", MSG_INFO, 30);
        $self->useProxyCheckBut()->set_active(FALSE);
        $self->noProxy(1);
    }
    elsif ($internetConnStatus == INET_PROXY_CONN) {
        $self->showStatus("Internet connection is avilable via http_proxy environment variable.", MSG_INFO, 30);
        $self->useProxyCheckBut()->set_active(TRUE);
        $self->noProxy(0);
    }
    else {
        if ($^O eq 'MSWin32') {
            $self->showStatus("Direct internet connection is NOT avilable. Trying to get configuration from IE.");
            my $internetProxyStatus = $self->webUtilsObj()->getWinHTTPProxy();
            if ($internetProxyStatus == INET_PROXY_SET) {
                $self->showStatus("Internet connection is avilable via $ENV{'http_proxy'}", MSG_INFO);
                $self->useProxyCheckBut()->set_active(TRUE);
                $self->noProxy(0);
            }
            elsif ($internetProxyStatus == INET_PROXY_SET_NOTWORKING) {
                $self->showStatus("http_proxy found but not working. You may need to set http_proxy env variable with username, password", MSG_ERR, 70);
                $self->useProxyCheckBut()->set_active(TRUE);
                $self->noProxy(0);
                $self->useProxyCheckBut()->set_active(FALSE);
                $self->noProxy(1);
            }
        }
        else {
            $self->showStatus("Direct internet connection is NOT avilable. You may need to set http_proxy env variable with username, password", MSG_ERR, 70);
        }
    }

    $self->hideStatus();

    return TRUE;
}

sub InfoWinWait {
    my $self = shift @_;
    my $waitTime = shift @_ || 10; #In micro seconds
    my $opacity = 0.3;
    my $opacityStep = (1.0 - $opacity) / $waitTime;

    $self->InfoWin()->set_opacity($opacity);

    for (my $i = 0; $i < $waitTime; $i++) {
        if ($opacity <= 0.7) {
            #Slowly increase window opacity until 80%
            $opacity += $opacityStep;
        }
        else {
            #Remaining 20% of the time it should be visible 100%
            $opacity = 1.0;
        }
        $self->InfoWin()->set_opacity($opacity);
        Gtk2->main_iteration();
        usleep(1);
        Gtk2->main_iteration();
    }

    $self->InfoWin()->set_opacity($opacity);

    return TRUE;
}

sub showStatus {
    my $self = shift @_;
    my $msg = shift @_;
    my $type = shift @_ || MSG_INFO;
    my $waitTime = shift @_ || -1;

    #Start events update
    $self->updateEventsTimeOutTag(Glib::Timeout->add_seconds(1, \&updateEvents, $self));

    $self->InfoWin()->resize(1, 1);
    $self->spiderMainWin()->set_opacity(0.60);
    $msg = "\n\n\t$msg\t\t\n\n";
    #Refer: http://html-color-codes.com/ for color codes
    if ($type == MSG_ERR) {
        $msg = '<span foreground="#CC0033" size="large">' . $msg . '</span>';
        $waitTime = 45 if ($waitTime == -1);
    }
    elsif ($type == MSG_WAR) {
        $msg = '<span foreground="#FF6633" size="large">' . $msg . '</span>';
        $waitTime = 30 if ($waitTime == -1);
    }
    elsif ($type == MSG_INFO) {
        $msg = '<b><span foreground="#006600" size="large">' . $msg . '</span></b>';
        $waitTime = 25 if ($waitTime == -1);
    }

    #Set info label
    $self->infoLabel()->set_markup($msg);

    $self->InfoWin()->show();

    #Wait for Info GUI
    if ($type == MSG_ERR) {
        $self->InfoWinWait($waitTime);
    }
    elsif ($type == MSG_WAR) {
        $self->InfoWinWait($waitTime);
    }
    elsif ($type == MSG_INFO) {
        $self->InfoWinWait($waitTime);
    }

    return TRUE;
}

sub hideStatus {
    my $self = shift @_;

    $self->spiderMainWin()->set_opacity(1);

    print $self->InfoWin()->hide();

    Glib::Source->remove($self->updateEventsTimeOutTag());

    return TRUE;
}


sub showSpiderGui {
    my $self = shift @_;

    #Ideal func for update GUI from spiders
    Glib::Idle->add(\&updateSpiderResults, $self);

    #Finally GTK main , Nothing else
    #Gtk2 is nothing but Gtk2::main
    #GUI screen appears after control enters into Gtk2 Main loop
    Gtk2->main();

    return TRUE;
}


sub updateSpiderResults {
    my $self = shift @_;

    #Immediately return if Spiders are not running
    return TRUE if (!$self->spidersRunning());

    my $line;
    my $iter;

    $line = $self->rawOutputQ()->dequeue_nb();
    if (defined($line)) {
        $iter = $self->rawSpiderTextViewBuffer()->get_end_iter();
        $self->rawSpiderTextViewBuffer()->insert_with_tags_by_name($iter, $line, 'info');
        $iter = $self->rawSpiderTextViewBuffer()->get_end_iter();
        $self->rawSpiderTextView()->scroll_to_iter($iter, 0.0, FALSE, 0.0, 0.0);
    }
    $line = $self->spiderOutputQ()->dequeue_nb();
    if (defined($line)) {
        $iter = $self->spiderQTextViewBuffer()->get_end_iter();
        $self->spiderQTextViewBuffer()->insert_with_tags_by_name($iter, $line, 'info');
        $iter = $self->spiderQTextViewBuffer()->get_end_iter();
        $self->spiderQTextView()->scroll_to_iter($iter, 0.0, FALSE, 0.0, 0.0);

        $self->gchartCounter()->{'OUTURL'}++;
    }
    $line = $self->searchResultsOutputQ()->dequeue_nb();
    if (defined($line)) {
        $iter = $self->searchResultsTextViewBuffer()->get_end_iter();
        $self->searchResultsTextViewBuffer()->insert_with_tags_by_name($iter, $line, 'info');
        $iter = $self->searchResultsTextViewBuffer()->get_end_iter();
        $self->searchResultsTextView()->scroll_to_iter($iter, 0.0, FALSE, 0.0, 0.0);

        $self->gchartCounter()->{'RESULTS'}++;
    }

    #Gchart Data calulation
    #For every 100 outgoing urls , find the percentage of how many results, it is like calculating for every 100 ton of soil, how much gold you get
    if ($self->gchartCounter()->{'OUTURL'} >= $self->gchartBucketSize()) {

        #Put the calculated values into gchartSearchHealth
        # print ("\n count: ", $self->gchartCounter()->{'RESULTS'});
        # print ("\n total: ",$self->gchartCounter()->{'OUTURL'});
        # print ("\n met: ", (($self->gchartCounter()->{'RESULTS'} / $self->gchartCounter()->{'OUTURL'}) * 100));
        # print ("\n");
        push(@{$self->gchartSearchHealth()}, (($self->gchartCounter()->{'RESULTS'} / $self->gchartCounter()->{'OUTURL'}) * 100));

        #Keep only last 30 sets
        if ($#{$self->gchartSearchHealth()} >= 30) {
            shift(@{$self->gchartSearchHealth()});
        }

        # Re use $line var itself to save memory. Every new scalar takes memory

        $line = 'https://quickchart.io/chart?w=500&h=200&c={type:"line",data:{labels:[' .
            "'.'," x @{$self->gchartSearchHealth()} . '],datasets:[{label:"Search Health Yield",data:[' .
            join(',', @{$self->gchartSearchHealth()}) . ']}]}}';
        #load the google chart

        $self->updateGChart($line);

        #Reset
        $self->gchartCounter()->{'OUTURL'} = 0;
        $self->gchartCounter()->{'RESULTS'} = 0;
    }

    return TRUE;
}

#Since we can not have tight while loop for updating GTK events within any other events (Like button click etc..)
# Do it as a timed events. 
sub updateEvents {
    #my $self = shift @_;
    Gtk2->main_iteration();
    return TRUE;
}
sub updateInfoProgress {
    my $self = shift @_;

    return TRUE if ($self->pauseBut()->get_active()); #If Pause button is active, Dont update progressbar

    $self->infoProgressBar()->pulse();

    return TRUE;
}

sub updateGChart {
    my $self = shift @_;
    my $gChartUrl = shift @_;

    my $imgContent;
    my $pixBufloader;

    #Just make sure nothing gets blocks while getting image from google
    # Gtk2->main_iteration while ( Gtk2->events_pending );

    if ($self->updateGChartCheckBut()->get_active() == FALSE) #If not checked, don't update
    {
        return TRUE;
    }
    #Get the chart from google servers
    $imgContent = $self->WebSpiderObj()->getGChartImg($gChartUrl);

    #Load it to Gtk2 Image via pixbufferloader
    if (defined $imgContent) {
        $pixBufloader = Gtk2::Gdk::PixbufLoader->new();
        $pixBufloader->write($imgContent);
        $pixBufloader->close;

        #Update Image 
        $self->chrtImage()->set_from_pixbuf($pixBufloader->get_pixbuf());
    }
    else {
        $self->chrtImage()->set_from_stock('gtk-dialog-error', 'GTK_ICON_SIZE_DIALOG');
    }

    return TRUE;
}


sub on_executeBut_clicked {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    my $WebSpiderObj;

    $self->showStatus(" Starting Spiders...", MSG_INFO, 5);
    #Start progress bar 
    $self->infoProgressBar()->show();
    #$self->isRegexSearchCheckBut()->set_state('insensitive'); 
    $self->infoProgressBar()->set_text("Working...");
    $self->updateInfoProgressTimeOutTag(Glib::Timeout->add_seconds(1, \&updateInfoProgress, $self));

    $self->searchResultsTextViewBuffer()->set_text("");
    $self->spiderQTextViewBuffer()->set_text("");
    $self->rawSpiderTextViewBuffer()->set_text("");

    $self->gchartCounter()->{'OUTURL'} = 0;
    $self->gchartCounter()->{'RESULTS'} = 0;

    my @emptyarr = ();
    $self->gchartSearchHealth(\@emptyarr);

    if ($self->noProxy() == 0) {
        $ENV{'http_proxy'} = $self->proxyHostTextEnt()->get_text();
        #HTTPS_PROXY should be set after create LWP UserAgent object
    }
    else {
        delete $ENV{'http_proxy'} if exists $ENV{'http_proxy'};
        delete $ENV{'HTTP_PROXY'} if exists $ENV{'HTTP_PROXY'};
        delete $ENV{'https_proxy'} if exists $ENV{'https_proxy'};
        delete $ENV{'HTTPS_PROXY'} if exists $ENV{'HTTPS_PROXY'};

    }

    $self->totSpiderThreads($self->spiderThreadsComboEnt()->get_active_text());

    $WebSpiderObj = WebSpider->new(searchText => $self->searchTextEnt()->get_text(), seedURL => $self->seedSiteTextEnt()->get_text(), noProxy => $self->noProxy(),
        totSpiderThreads                      => $self->totSpiderThreads(), searchTextType => $self->searchTextType(), restrictToDomain => $self->restrictDomainTextEnt->get_text());

    $WebSpiderObj = $WebSpiderObj->getSharedObj();
    $self->WebSpiderObj($WebSpiderObj);

    $WebSpiderObj->setOutputQs($self->rawOutputQ(), $self->spiderOutputQ(), $self->searchResultsOutputQ());

    $self->WebSpiderObj()->startSpiders();

    $self->spidersRunning(1);

    $self->spiderGuiGlade()->get_object('saveasDataBut')->set_sensitive(FALSE);
    $self->pauseBut()->set_sensitive(TRUE); #Activate pause button
    $self->spiderGuiGlade()->get_object('stopBut')->set_sensitive(TRUE);
    $widget->set_sensitive(FALSE); #set this button to False

    #Get the stockids from Gtk2::Stock's POD
    $self->chrtImage()->set_from_stock('gtk-yes', 'GTK_ICON_SIZE_DIALOG');

    $self->hideStatus();

    return TRUE;

}

sub on_pauseBut_toggled {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    if ($widget->get_active()) #If pause pressed
    {
        $self->infoProgressBar()->set_text("Paused...");
        $widget->set_label("_Resume");
        $self->WebSpiderObj()->pauseSpiders();
        $self->spiderGuiGlade()->get_object('saveasDataBut')->set_sensitive(TRUE);
    }
    else {
        $self->infoProgressBar()->set_text("Resumed...");
        $widget->set_label("_Pause");
        $self->WebSpiderObj()->resumeSpiders();
        $self->infoProgressBar()->set_text("Working...");
        $self->spiderGuiGlade()->get_object('saveasDataBut')->set_sensitive(FALSE);
    }

    return TRUE;
}


sub on_saveasDataBut_clicked {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    my $selectedFileName = "";
    my $selectedFileExtn = "";
    my $fileFilter = "";
    my $fileFilterName = "";
    my $fileDia = "";

    my $dataExporter = "";

    #In Gtk2::FileChooserDialog, gtk-cancel -> Gtk Stock ID , cancel -> Gtk Action
    # Gtk2::FileChooserDialog(title, parent, action, buttons, backend)
    # Refer Gtk2::FileChooser for more details, $fileDia is Gtk2::FileChooser

    $fileDia = Gtk2::FileChooserDialog->new("Select File to export Search Data...", undef,
        'save', 'gtk-save' => 'ok', 'gtk-cancel' => 'cancel');
    $fileDia->set_default_response('ok');
    $fileDia->set_do_overwrite_confirmation(TRUE);


    #Add file filter to avoid unsupported files
    $fileFilter = Gtk2::FileFilter->new();
    $fileFilter->set_name('HTML');
    $fileFilter->add_pattern('*.htm');
    $fileDia->add_filter($fileFilter);

    $fileFilter = Gtk2::FileFilter->new();
    $fileFilter->set_name('Excel Sheet');
    $fileFilter->add_pattern('*.csv');
    $fileDia->add_filter($fileFilter);

    $fileFilter = Gtk2::FileFilter->new();
    $fileFilter->set_name('SQLite DB');
    $fileFilter->add_pattern('*.sqlite');
    $fileDia->add_filter($fileFilter);

    $fileFilter = Gtk2::FileFilter->new();
    $fileFilter->set_name('Plain Text');
    $fileFilter->add_pattern('*.txt');
    $fileDia->add_filter($fileFilter);

    if ('ok' eq $fileDia->run()) {

        #Based on user chose filer name, Assign the file extn
        $fileFilterName = $fileDia->get_filter()->get_name();

        if ($fileFilterName eq 'HTML') {$selectedFileExtn = '.htm';}
        if ($fileFilterName eq 'Excel Sheet') {$selectedFileExtn = '.csv';}
        if ($fileFilterName eq 'SQLite DB') {$selectedFileExtn = '.sqlite';}
        if ($fileFilterName eq 'Plain Text') {$selectedFileExtn = '.txt';}


        #Get file name
        $selectedFileName = $fileDia->get_filename();

        $selectedFileName =~ s/\.\w+$//gi; #Remove any extentins

        #Add Extn based on Filters
        $selectedFileName .= $selectedFileExtn;
    }

    $fileDia->destroy();

    $self->showStatus(" Exporting Search Results... ", MSG_INFO, 30);

    $dataExporter = DataExporter->new();
    $dataExporter->exportSearchResults($selectedFileName, $selectedFileExtn);

    $self->hideStatus();

    return TRUE;
}

sub on_stopBut_clicked {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    $self->showStatus(" Stopping Spiders...", MSG_INFO, 5);

    $self->WebSpiderObj()->stopSpiders();

    $self->infoProgressBar()->set_text("Stopping...");
    # Flush remaining text from the outputQs 
    Gtk2->main_iteration() while ($self->rawOutputQ()->pending() || $self->spiderOutputQ()->pending() || $self->searchResultsOutputQ()->pending());
    $self->spidersRunning(0);
    #Clean up some memory
    my $rawOutputQ = Thread::Queue->new();
    $self->rawOutputQ($rawOutputQ);
    my $spiderOutputQ = Thread::Queue->new();
    $self->spiderOutputQ($spiderOutputQ);
    my $searchResultsOutputQ = Thread::Queue->new();
    $self->searchResultsOutputQ($searchResultsOutputQ);

    #Stop Progress Bar and hide
    $self->infoProgressBar()->hide();
    #Glib::Source->remove($self->updateInfoProgressTimeOutTag());

    $self->spiderGuiGlade()->get_object('stopBut')->set_sensitive(FALSE);

    $self->spiderGuiGlade()->get_object('executeBut')->set_sensitive(TRUE);
    $self->pauseBut()->set_active(FALSE);
    $self->spiderGuiGlade()->get_object('saveasDataBut')->set_sensitive(TRUE);
    #Get the stockids from Gtk2::Stock's POD
    $self->chrtImage()->set_from_stock('gtk-stop', 'GTK_ICON_SIZE_DIALOG');

    $self->isRegexSearchCheckBut()->set_state('normal');

    $self->hideStatus();

    return TRUE;

}

sub on_quitMenuItem_activate {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    $self->on_spiderMainWin_destroy();

    return TRUE;
}

sub on_quitBut_clicked {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    $self->on_spiderMainWin_destroy();

    return TRUE;

}

#Final GTK method, GTK quits here
sub on_spiderMainWin_destroy {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_;

    #Stop Spiders and GUIs
    if (defined($self->WebSpiderObj())) {
        $self->on_stopBut_clicked();
    }

    Gtk2->main_quit();

    return TRUE;
}

sub on_isRegexSearchCheckBut_toggled {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    if ($self->isRegexSearchCheckBut()->get_active() == TRUE) #If checked
    {
        $self->searchTextType(2); # 2 == RegEx search
    }
    else {
        $self->searchTextType(1); # 1 == Normal text search
    }
    return TRUE;
}

sub on_useProxyCheckBut_toggled {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    if ($self->useProxyCheckBut()->get_active() == TRUE) #If checked
    {
        $self->noProxy(0);
        if (exists $ENV{'HTTP_PROXY'}) {
            $self->proxyHostTextEnt()->set_text($ENV{'HTTP_PROXY'});
        }
        elsif (exists $ENV{'http_proxy'}) {
            $self->proxyHostTextEnt()->set_text($ENV{'http_proxy'});
        }
    }
    else {
        $self->noProxy(1);
        $self->proxyHostTextEnt()->set_text("");
    }

    return TRUE;
}

sub on_aboutMenuItem_activate {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    $self->on_abtBut_clicked();

    return TRUE;
}

sub on_abtBut_clicked {
    my $self = shift @_;
    my $widget = shift @_;
    my $userData = shift @_; #Passed by Gtk2::Builder connect_signals() function

    #Get Gtk version
    my ($ma, $min, $pa) = Gtk2->GET_VERSION_INFO();
    my $abtInfo .= 'OS: ' . $^O . "\n";
    $abtInfo .= 'Gtk: ' . $ma . '.' . $min . '.' . $pa . "\n";
    $abtInfo .= 'Perl: ' . $^V . "\n";

    my $logo;

    if (defined $PerlApp::VERSION) {
        #Running from perlapp created exe
        $logo = PerlApp::extract_bound_file('logo_big.png');
    }
    else {
        $logo = $self->LibDir() . '/logo_big.png';
    }

    Gtk2->show_about_dialog($self->spiderMainWin(),
        program_name => 'NPoint Solutions - Search Spider',
        version      => SPIDERVERSION,
        comments     => $abtInfo,
        license      => 'GPLV3 , http://www.gnu.org/licenses/gpl.html',
        #'website-label' => 'Saaral Search Spider Web Page',
        website      => 'http://code.google.com/p/saaral-soft-search-spider/',
        authors      => 'Bakkiaraj Murugesan',
        logo         => Gtk2::Gdk::Pixbuf->new_from_file($logo),
        copyright    => 'This program is free software: Licensed under GNU GPLv3');

    return TRUE;
}

#sub on_infoLabel_button_press_event
#{
#	
#}
#sub DEMOLISH
#{
#	my $self = shift @_;
#	print "\n GUI Demolish";
#}
#Do it for all classes so Moose will create fast object creation, so application runs faster
__PACKAGE__->meta->make_immutable();
no Moose;
1;
