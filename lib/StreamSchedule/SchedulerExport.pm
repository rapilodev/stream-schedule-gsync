package StreamSchedule::SchedulerExport;

$VERSION = '0.01_0009';

=head1 NAME

stream-schedule-gsync - get streaming events from google calendar

=head1 DESCRIPTION

schedule audio streams using liquidsoap and google calendar.
Each google calendar event has to contain the source stream URL or an alias at the title.

Run syncStreamSchedule.pl to get a list of streams in a csv file.
The result can be used by stream-schedule to play streams from given URLs from calendar title at given time.

Configuration is to be done at /etc/stream-schedule/gsync/gsync.conf

source section: 

googleCalendarUrl            URI of your google calendar id
googleServiceAccount         URI of your google service account
googleServiceAccountKeyPath  path to your google service account key file
timeZone                     timezone of your google calendar
verbose                      verbose level (1..5) 

target section:

outputFile       path to output file, or use --output 
timeZone         Leap seconds and winter/summer time changeover are supported for the selected time zone, default is Germany/Berlin.
defaultName      name of default entry, "default" by default
verbose          verbose level (1..5)

=head1 VERSION

Version 0.0.1_0009

=head1 AUTHOR

Milan Chrobok <mc@radiopiloten.de>

=head1 LICENSE AND COPYRIGHT

Copyright 2009-2016 Milan Chrobok.

GPL-3+

=cut

use strict;
use warnings;

use Data::Dumper;

use StreamSchedule::Log qw(printInfo printExit);
use StreamSchedule::Time;

my $settings = {};
my $events   = undef;
my $verbose  = 0;

sub init {
    $settings = shift;
    $verbose = $settings->{verbose} if defined $settings->{verbose};

    # init results
    $events = [];
    printExit("missing 'timeZone' at target configuration")
      unless defined getTimeZone();
    printExit("missing 'defaultName' at target configuration")
      unless defined getDefaultName();
}

sub getOutputFile {
    return $settings->{outputFile} || undef;
}

sub getTimeZone {
    return $settings->{timeZone};
}

sub getDefaultName {
    return $settings->{defaultName};
}

# insert a new event
sub insertEvent {
    my $event = shift;

    my $title    = $event->{title};
    my $timeZone = getTimeZone();
    printInfo("insertEvent start:$event->{start}, timeZone:$timeZone");
    my $start = StreamSchedule::Time::getDatetime( $event->{start}, $timeZone );
    printInfo("insertEvent end:$event->{end}, timeZone:$timeZone");
    my $end = StreamSchedule::Time::getDatetime( $event->{end}, $timeZone );

    return if $start eq '';
    return if $end   eq '';

    print "\n" if ( $verbose eq '1' );
    main::printInfo("insert event") if ( $verbose eq '1' );

    push @$events,
      {
        start => $start,
        end   => $end,
        title => $title
      };
}

sub getResult {
    my $from       = shift;
    my $till       = shift;
    my $outputFile = shift;

    my $content = '';
    my @cal = sort { $a->{start} cmp $b->{start} } @$events;

    my @results = ();

    #fill in default
    my $default = getDefaultName();
    if ( defined $default ) {

        if ( @cal == 0 ) {

            #set default unless entries are defined
            push @cal,
              {
                start => $from,
                end   => $till,
                title => $default
              };
        } else {

            #insert default at start until start of first event
            if ( $cal[0]->{start} gt $from ) {
                unshift @cal,
                  {
                    start => $from,
                    end   => $cal[0]->{start},
                    title => $default
                  };
            }

            #insert default after end of last event
            printInfo("$cal[-1]->{end} lt $till ?");
            if ( $cal[-1]->{end} lt $till ) {
                push @cal,
                  {
                    start => $cal[-1]->{end},
                    end   => $till,
                    title => $default
                  };
            }
        }

        my $oldEvent = {
            start => '',
            title => '',
            end   => $from
        };

        for my $event (@cal) {
            next unless defined $event->{start};
            next unless defined $event->{end};
            next unless defined $event->{title};

            # replace if same as event before
            if (   ( $event->{start} eq $oldEvent->{start} )
                && ( $event->{end}   eq $oldEvent->{end} )
                && ( $event->{title} eq $oldEvent->{title} ) )
            {
                $results[-1] = $event;
                $oldEvent = $event;
                next;
            }

            # insert default if next event starts after end of last
            if ( $event->{start} gt $oldEvent->{end} ) {
                push @results,
                  {
                    start => $oldEvent->{end},
                    end   => $event->{start},
                    title => $default
                  };
            }

            # save event
            push @results, $event;
            $oldEvent = $event;

        }
    }

    for my $event (@results) {
        next unless defined $event->{start};
        next unless defined $event->{title};
        $content .= $event->{start} . ";\t" . $event->{title} . ";\n";
    }

    $outputFile = getOutputFile() unless defined $outputFile;
    if ( defined $outputFile ) {
        printInfo("save result to '$outputFile'");
        saveFile( $outputFile, $content );

    } else {
        print $content. "\n";
    }
}

sub saveFile {
    my $filename = shift;
    my $content  = shift;
    open my $file, '>', $filename;
    print $file $content;
    close $file;
}

1;

