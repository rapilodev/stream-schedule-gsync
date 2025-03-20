package GoogleCalendarApi;

use strict;
use warnings;

use JSON;
use JSON::WebToken;
use LWP::UserAgent;
use HTML::Entities;
use URI::Escape;
use Data::Dumper;
use DateTime;

use StreamSchedule::Log qw(printInfo printExit);

sub new {
    my ($class, $params) = @_;
    my $self = {};
    for my $attr ( 'calendarId', 'verbose' ) {
        $self->{$attr} = $params->{$attr} if defined $params->{$attr};
    }

    my $instance = bless $self, $class;
    if (   ( defined $params->{serviceAccount} )
        && ( defined $params->{privateKey} ) )
    {
        $instance->login( $params->{serviceAccount}, $params->{privateKey} );
    }
    return $instance;
}

sub setCalendar {
    my ($self, $calendarId) = @_;
    $self->{calendarId} = $calendarId;
}

sub getBasicUrl {
    my $self = shift;
    return 'https://www.googleapis.com/calendar/v3/calendars/' . encode_entities( $self->{calendarId} );
}

#https://developers.google.com/google-apps/calendar/v3/reference/events/list

#returns {
#          'timeZone' => 'Europe/Berlin',
#          'description' => "Radioprogramm von Pi Radio",
#          'defaultReminders' => [],
#          'accessRole' => 'owner',
#          'etag' => '"1415821582086000"',
#          'kind' => 'calendar#events',
#          'summary' => 'Pi Radio (Programm)',
#          'updated' => '2014-11-12T19:46:22.086Z',
#          'items' => [...]
# }
sub getEvents {
    my $self   = shift;
    my $params = shift;

    my $url = '/events?';
    for my $param (
        'iCalUID',                'alwaysIncludeEmail', 'maxAttendees',            'maxResults',
        'orderBy',                'pageToken',          'privateExtendedProperty', 'q',
        'sharedExtendedProperty', 'showDeleted',        'showHiddenInvitations',   'singleEvents',
        'syncToken',              'timeZone'
    ) {
        $url .= '&' . $param . '=' . uri_escape( $params->{$param} )
          if defined $params->{$param};
    }
    
    for my $param ( 'timeMin', 'timeMax', 'updatedMin' ) {
        $url .= '&' . $param . '=' . uri_escape( $self->formatDateTime( $params->{$param} ) )
          if defined $params->{$param};
    }
    printInfo("GET: $url") if ( defined $self->{verbose} ) && ( $self->{verbose} > 0 );
    my $result = $self->httpRequest( 'GET', $url );
    return $result;
}

#https://developers.google.com/google-apps/calendar/v3/reference/events/delete
sub deleteEvent {
    my ($self, $eventId) = @_;
    my $url     = '/events/' . $eventId;

    #DELETE https://www.googleapis.com/calendar/v3/calendars/calendarId/events/eventId
    my $result = $self->httpRequest( 'DELETE', $url );
    return $result;
}

#https://developers.google.com/google-apps/calendar/v3/reference/events/insert
sub insertEvent {
    my ($self, $params) = @_;
    my $event = {
        start => { dateTime => $self->formatDateTime( $params->{start} ) },
        end   => { dateTime => $self->formatDateTime( $params->{end} ) },
        summary     => $params->{summary}     || '',
        description => $params->{description} || '',
        location    => $params->{location}    || '',
        status      => $params->{confirmed}   || 'confirmed'
    };
    $event = encode_json $event;

    #POST https://www.googleapis.com/calendar/v3/calendars/calendarId/events
    my $url = '/events';
    my $result = $self->httpRequest( 'POST', $url, $event );
    return $result;
}

# send a HTTP request
sub httpRequest {
    my ($self, $method, $url, $content) = @_;
    printInfo( "$method " . $url ) if $self->{verbose};

    die("missing url")        unless defined $url;
    die("calendarId not set") unless defined $self->{calendarId};
    die("not logged in ")     unless defined $self->{api};

    #prepend basic url including calendar id
    $url = $self->getBasicUrl() . $url;
    printInfo( "$method " . $url ) if $self->{verbose};

    my $response = undef;
    if ( $method eq 'GET' ) {
        $response = $self->{api}->get($url);
    } elsif ( ( $method eq 'POST' ) || ( $method eq 'PUT' ) ) {
        printInfo($content) if $self->{verbose};
        my $request = HTTP::Request->new( $method, $url );
        $request->header( 'Content-Type' => 'application/json' );
        $request->content($content);
        $response = $self->{api}->request($request);
    } elsif ( $method eq 'DELETE' ) {
        $response = $self->{api}->delete($url);
    }

    if ( $response->is_success ) {
        my $content = $response->content;
        return {} if $content eq '';
        return decode_json($content);
    } else {
        printExit(
            "Code:    " . $response->code . "\n" .
            "Message: " . $response->message . "\n" . 
            $response->content . "\n"
        );
    }
}

# write datetime object to string
sub formatDateTime {
    my ($self, $dt) = @_;
    my $datetime = $dt->format_cldr("yyyy-MM-ddTHH:mm:ssZZZZZ");
    return $datetime;
}

# parse datetime from string to object
# same as in time, copied to prevent dependency
sub getDateTime {
    my ($self, $dt) = @_;
    my ($self, $datetime, $timezone) = @_;
    return unless $datetime;
    my @l = split /[\-\;T\s\:\+\.]/, $datetime;

    $datetime = DateTime->new(
        year      => $l[0],
        month     => $l[1],
        day       => $l[2],
        hour      => $l[3],
        minute    => $l[4],
        second    => $l[5],
        time_zone => $timezone
    );
    return $datetime;
}

# login with serviceAccount and webToken (from privateKey)
sub login {
    my ($self, $serviceAccount, $privateKey) = @_;
    # https://developers.google.com/accounts/docs/OAuth2ServiceAccount
    my $time = time;

    #create JSON Web Token
    my $jwt = JSON::WebToken->encode(
        {
            iss   => $serviceAccount,
            scope => 'https://www.googleapis.com/auth/calendar',
            aud   => 'https://accounts.google.com/o/oauth2/token',
            exp   => $time + 3600,
            iat   => $time,
        },
        $privateKey,
        'RS256',
        { typ => 'JWT' }
    );

    #send JSON web token to authentication service
    $self->{auth} = LWP::UserAgent->new();
    my $response = $self->{auth}->post(
        'https://accounts.google.com/o/oauth2/token',
        {
            grant_type => encode_entities('urn:ietf:params:oauth:grant-type:jwt-bearer'),
            assertion  => $jwt
        }
    );

    die( $response->code, "\n", $response->content, "\n" )
      unless $response->is_success();
    my $data = decode_json( $response->content );

    #create a new user agent and set token to bearer
    $self->{api} = LWP::UserAgent->new();
    $self->{api}->default_header( Authorization => 'Bearer ' . $data->{access_token} );

    printInfo("login successful") if $self->{verbose};
    return $data;
}

1;
