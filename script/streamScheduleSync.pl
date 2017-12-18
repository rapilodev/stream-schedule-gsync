#!/usr/bin/perl

use strict;
use warnings;
$| = 1;

BEGIN {
    $ENV{LANG} = "en_US.UTF-8";
}

use Data::Dumper;
use Getopt::Long;
use Config::General;
use DateTime;
use DateTime::Duration;

use StreamSchedule::Log qw(printInfo printError printWarning printExit);
use StreamSchedule::Time;
use StreamSchedule::GoogleCalendarImport;
use StreamSchedule::SchedulerExport;

my $updateStart = undef;
my $configFile  = '/etc/stream-schedule/gsync/gsync.conf';

main();
exit 0;

sub main {
    my $options = {};
    $options->{config} = $configFile if defined $configFile;

    GetOptions(
        "config=s"  => \$options->{config},
        "from=s"    => \$options->{from},
        "till=s"    => \$options->{till},
        "output=s"  => \$options->{output},
        "verbose=i" => \$options->{verbose},
        "h|help"    => \$options->{help},
    );

    if ( $options->{help} ) {
        print STDERR usage();
        exit 0;
    }

    #source and taget settings are loaded from config files

    printExit("missing parameters --from DATE! see --help for details")
      unless defined $options->{from};
    printExit("missing parameters --till DATE! see --help for details")
      unless defined $options->{till};

    my $settings = init($options);
    sync( $options, $settings );

    printInfo("$0 done.");
}

#sync all events, splitting multi-day-requests into multiple 1-day-requests to avoid large result sets
sub sync {
    my $options  = shift;
    my $settings = shift;

    #prepare target
    printInfo( "last update: " . getLastUpdateTime() );

    my $startMin = $options->{from};
    my $startMax = $options->{till};
    my $timeZone = StreamSchedule::GoogleCalendarImport::getTimeZone();

    my $dates = StreamSchedule::GoogleCalendarImport::splitRequest( $startMin, $startMax, $timeZone );

    if ( defined $dates ) {
        for my $date (@$dates) {
            $startMin = $date->{startMin};
            $startMax = $date->{startMax};
            syncTimeSpan( $startMin, $startMax );
        }
    } else {

        #update without time span (e.g. --modified)
        syncTimeSpan( $startMin, $startMax );
    }

    printInfo("export result...");
    StreamSchedule::SchedulerExport::getResult( $options->{from}, $options->{till}, $options->{output} );

    printInfo( "set last-update time:" . getUpdateStart() );
    setLastUpdateTime( getUpdateStart() );
}

sub getUpdateStart {
    return $updateStart;
}

sub setUpdateStart {
    $updateStart = StreamSchedule::Time::epochToDatetime( time() );
}

#sync all events inside given time span
sub syncTimeSpan {
    my $start = shift;
    my $end   = shift;

    printInfo("syncTimeSpan start:$start end:$end");

    my $events = StreamSchedule::GoogleCalendarImport::getEvents( $start, $end );

    my @dates = ( keys %$events );

    if ( @dates == 0 ) {
        my $more = '';
        printInfo("no entries found.");
    } else {

        #sort lists of date and time (same time events should be preserved)
        for my $date ( sort { $a cmp $b } @dates ) {
            syncEvents( $events->{$date} );
        }
    }

}

#syncronize a list of source events to target events
sub syncEvents {
    my $sourceEvents = shift;

    my $c = 0;

    #order processing by start time
    for my $event ( sort { $a->{calcmsStart} cmp $b->{calcmsStart} } @$sourceEvents ) {
        $event = StreamSchedule::GoogleCalendarImport::getEventAttributes($event);

        printEvent( $c + 1, $event );

        if ( $event->{start} eq '' || $event->{end} eq '' ) {
            printWarning('Cannot read start or end of event');
        } else {
            StreamSchedule::SchedulerExport::insertEvent($event);
        }

        $event = undef;
        $c++;
    }
}

# read config from options and return settings
sub init {
    my $options  = shift;
    my $settings = {};

    binmode STDOUT, ":utf8";

    # parse config file
    my $configFile = $options->{config};
    printExit("missing parameter --config!") unless ( $configFile =~ /\S/ );
    printExit("config file '$configFile' does not exist")
      unless ( -e $configFile );
    printExit("cannot read config file: '$configFile'")
      unless ( -r $configFile );
    my $configuration = new Config::General($configFile);

    $settings->{source}                = $configuration->{DefaultConfig}->{source};
    $settings->{target}                = $configuration->{DefaultConfig}->{target};
    $settings->{source}->{lastUpdate} = getLastUpdateTime();

    # set start time if missing
    if ( $options->{from} =~ /^\d\d\d\d\-\d\d\-\d\d$/ ) {
        $options->{from} .= 'T00:00';
    }

    # set end time if missing
    if ( $options->{till} =~ /^\d\d\d\d\-\d\d\-\d\d$/ ) {
        $options->{till} .= 'T23:59';
    }

    # add given days to today (from)
    if ( $options->{from} =~ /^([-+]?\d+$)/ ) {
        my $days = $1;
        my $duration = new DateTime::Duration( days => $days );
        $options->{from} = DateTime->today->add_duration($duration);
        printInfo("from:$options->{from}");
    }

    # add given days to today (till)
    if ( $options->{till} =~ /^([-+]?\d+$)/ ) {
        my $days = $1 + 1;
        my $duration = new DateTime::Duration( days => $days );
        $options->{till} = DateTime->today->add_duration($duration);
        printInfo("till:$options->{till}");

    }

    setUpdateStart();

    StreamSchedule::GoogleCalendarImport::init( $settings->{source} );
    StreamSchedule::SchedulerExport::init( $settings->{target} );

    printInfo("$0 inited");

    return $settings;
}

# print date/time, title and excerpt of an calendar event
sub printEvent {
    my $count = shift;
    my $event = shift;
    printInfo( "[$count] found: " . $event->{start} . " " . $event->{end} . " " . $event->{title} );
}

#load last update time out of sync.data
sub getLastUpdateTime {
    my $date = undef;
    my $file = "sync.data";
    return "could not read last update time from '$file'" unless ( -r $file );
    my @stats      = stat($file);
    my $modifiedAt = $stats[9];
    return StreamSchedule::Time::epochToDatetime($modifiedAt);
}

#save last update time to sync.data
sub setLastUpdateTime {
    my $date = shift;

    my $filename = "sync.data";
    open my $file, ">:utf8", $filename || die('cannot write update timestamp');
    print $file $date;
    close $file;
}

#output usage on error or --help parameter
sub usage {
    return qq{
get a list of events from Google Calendar

USAGE: $0 OPTIONS+ 
	
OPTION
	--config FILE   source configuration file, default is /etc/stream-schedule/gsync/gsync.conf
	--from          start of date range: datetime (YYYY-MM-DDTHH:MM::SS) or days from today (e.g. -1 for yesterday, +1 for tomorrow)
	--till          end of date range: datetime (YYYY-MM-DDTHH:MM::SS) or days from today (e.g. -1 for yesterday, +1 for tomorrow)

    --verbose LEVEL verbose level
    --help

EXAMPLE 
  update all
	perl $0
  update a given time range by absolute date
	perl $0 --from=2009-09-01T00:00:00 --till=2009-11-22T23:59:59
  update from last 2 days until next 3 days
	perl $0 --from=-2 --till=+3
};

}

