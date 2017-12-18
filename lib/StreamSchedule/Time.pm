package StreamSchedule::Time;

use strict;
use warnings "all";

use Data::Dumper;
use Time::Local;
use DateTime;
use POSIX qw(strftime);

require Exporter;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(epochToDatetime getDatetime);
our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

# convert epoch to datetime format
sub epochToDatetime {
    my $time = shift;
    $time = time() unless ( ( defined $time ) && ( $time ne '' ) );
    my ($year, $month, $day, $hour, $minute, $second) = localtime($time);
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $month+1, $day, $hour, $minute, $second);
}

# get datetime object for 
sub getDatetime {
    my $datetime = shift;
    my $timezone = shift;

    return if ( ( !defined $datetime ) or ( $datetime eq '' ) );
    my @l = @{ datetimeToArray($datetime) };
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

# parse datetime and return array of date/time values
sub datetimeToArray {
    my $datetime = $_[0] || '';
    if ( $datetime =~ /(\d\d\d\d)\-(\d+)\-(\d+)[T\s]+(\d+)\:(\d+)(\:(\d+))?/ ) {
        my $year   = $1;
        my $month  = $2;
        my $day    = $3;
        my $hour   = $4 || '00';
        my $minute = $5 || '00';
        my $second = $7 || '00';
        return [ $year, $month, $day, $hour, $minute, $second ];
    }
    return undef;
}

#do not delete last line!
1;
