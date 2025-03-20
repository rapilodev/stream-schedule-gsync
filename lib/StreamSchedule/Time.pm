package StreamSchedule::Time;

use strict;
use warnings "all";

use Data::Dumper;
use Time::Local;
use DateTime;

require Exporter;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(epochToDatetime getDatetime);
our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

sub epochToDatetime {
    my ($s, $m, $h, $d, $M, $y) = localtime(shift // time);
    sprintf "%04d-%02d-%02d %02d:%02d:%02d", $y+1900, $M+1, $d, $h, $m, $s;
}

sub getDatetime {
    my ($datetime, $timezone) = @_;
    return unless $datetime;
    my $l = datetimeToArray($datetime);
    $datetime = DateTime->new(
        year      => $l->[0],
        month     => $l->[1],
        day       => $l->[2],
        hour      => $l->[3],
        minute    => $l->[4],
        second    => $l->[5],
        time_zone => $timezone
    );
    return $datetime;
}

sub datetimeToArray {
	$_[0] =~ /(\d{4})-(\d+)-(\d+)[T\s]+(\d+):(\d+)(?::(\d+))?/ 
        ? [$1, $2, $3, $4 // 0, $5 // 0, $6 // 0] : undef;
}

#do not delete last line!
1;

