package StreamSchedule::GoogleCalendarImport;

use strict;
use warnings;

use DateTime;

use Data::Dumper;
use DateTime::Format::ISO8601;
use StreamSchedule::Log qw(printInfo printExit);
use StreamSchedule::Time qw(getDatetime);
use StreamSchedule::GoogleCalendarApi;

my $verbose = 0;

# fields
# start_min : start of search
# start_max : stop of search
my $settings = {};

#update settings with external parameters
sub init {
    $settings = shift;
}

sub getStartMin {
    return $settings->{startMin};
}

sub getStartMax {
    return $settings->{startMax};
}

sub getTimeZone() {
    return $settings->{timeZone};
}


# split large requests into requests with no more than 7 days
# return a list of hashs containing start_min, start_max.
sub splitRequest {
    my $startMin = shift;
    my $startMax = shift;
    my $timeZone = shift;

    return undef unless defined $startMin;
    return undef if $startMin eq '';
    return undef unless defined $startMax;
    return undef if $startMax eq '';

    printInfo("split request from $startMin to $startMax");

    my $start = getDatetime( $startMin, $timeZone );
    my $end   = getDatetime( $startMax, $timeZone );
    my $date  = $start;

    #build a list of dates
    my @dates = ();
    while ( $date < $end ) {
        push @dates, $date;
        $date = $date->clone->add( days => 7 );
    }

    my $duration = $end - $date;
    if ( $duration->delta_seconds <= 0 ) {
        push @dates, $end->clone;
    }

    #build a list of parameters from dates
    $start = shift @dates;

    my $results = [];
    for my $end (@dates) {
        push @$results,
          {
            startMin => $start,
            startMax => $end
          };
        $start = $end;
    }
    return $results;
}

#get a hash with per-day-lists days of a google calendar, given by its url defined at $calendar_name
sub getEvents {
    my $start = shift;
    my $end   = shift;
    printInfo("getEvents from $start to $end");

    # 1. create service account at https://console.developers.google.com/
    # 2. enable Calendar API
    # 3. share calendar with service account for update permissions
    # see http://search.cpan.org/~shigeta/Google-API-Client-0.13/lib/Google/API/Client.pm

    my $timeZone = getTimeZone();

    my $privateKeyFile = $settings->{googleServiceAccountKeyPath};
    printInfo("load key from '$privateKeyFile'");
    my $privateKey = loadFile($privateKeyFile);

    my $calendar = new GoogleCalendarApi(
        {
            'calendarId'     => $settings->{googleCalendarUrl},
            'serviceAccount' => $settings->{googleServiceAccount},
            'privateKey'     => $privateKey,
            'verbose'        => $settings->{verbose}
        }
    );

    my $parameters = {
        maxResults   => 50,
        singleEvents => 'true',
        orderBy      => 'startTime'
    };

    #set start min (not using UTC)
    if (   ( defined $start )
        && ( $start ne '' ) )
    {
        my $datetime = $start;
        $datetime = getDatetime( $start, getTimeZone() )
          if ( ref($datetime) eq '' );
        $parameters->{"timeMin"} = $calendar->getDateTime( $datetime->datetime, $timeZone );
    }

    #set start max (not using UTC)
    if (   ( defined $end )
        && ( $end ne '' ) )
    {
        my $datetime = $end;
        $datetime = getDatetime( $datetime, getTimeZone() )
          if ( ref($datetime) eq '' );
        $parameters->{"timeMax"} = $calendar->getDateTime( $datetime->datetime, $timeZone );
    }

    printInfo( "search target for events from " . $start . " to " . $end )
      if ( $verbose eq '1' );

    my $events = $calendar->getEvents($parameters);

    for my $event ( @{ $events->{items} } ) {
        printInfo( "\t$event->{start}->{dateTime}\t" . $event->{summary} )
          if ( $verbose eq '1' );
        my $start = $event->{start}->{dateTime};
        my $end   = $event->{end}->{dateTime};
        $start = DateTime::Format::ISO8601->parse_datetime($start);
        $end   = DateTime::Format::ISO8601->parse_datetime($end);

        $event->{calcmsStart} = $start;
        $event->{calcmsEnd}   = $end;
        printInfo( "getEvents: start:" . $event->{calcmsStart}->datetime . " end:" . $event->{calcmsEnd}->datetime );
    }

    #return events by date
    my $eventsByDate = {};
    for my $event ( @{ $events->{items} } ) {
        my $key = substr( $event->{calcmsStart}, 0, 10 );
        push @{ $eventsByDate->{$key} }, $event;
    }
    return $eventsByDate;
}

sub getEventAttributes {
    my $source = shift;

    #create an hash with calendar event settings
    my $event = {
        start        => $source->{calcmsStart},
        end          => $source->{calcmsEnd},
        status       => $source->{status},
        reference    => $source->{id},
        title        => $source->{summary},
        content      => $source->{description},
        authorName   => $source->{creator}->{name},
        authorEmail  => $source->{creator}->{email},
        transparency => $source->{transparency},
        visibility   => $source->{visibility},
        location     => $source->{location},
    };

    return $event;
}

sub loadFile {
    my $filename = shift;

    my $content = '';
    printInfo("open '$filename'");
    open my $file, '<' . $filename || printExit("cannot read $filename");
    while (<$file>) {
        $content .= $_;
    }
    close $file;
    return $content;
}

# do not remove last line
1;
