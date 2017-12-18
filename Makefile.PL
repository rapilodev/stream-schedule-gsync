#!/usr/bin/env perl
use strict;
use warnings;
use inc::Module::Install;

name     'StreamSchedule';
all_from 'lib/StreamSchedule/SchedulerExport.pm';
all_from 'lib/StreamSchedule/GoogleCalendarApi.pm';
all_from 'lib/StreamSchedule/GoogleCalendarImport.pm';
all_from 'lib/StreamSchedule/Log.pm';
all_from 'lib/StreamSchedule/Time.pm';

requires 'Config::General' => '0.00';
requires 'Cwd' => '0.00';
requires 'Data::Dumper' => '0.00';
requires 'DateTime' => '0.00';
requires 'DateTime::Duration' => '0.00';
requires 'DateTime::Format::ISO8601' => '0.00';
requires 'Fcntl' => '0.00';
requires 'File::Find' => '0.00';
requires 'File::Path' => '0.00';
requires 'File::Spec' => '0.00';
requires 'Getopt::Long' => '0.00';
requires 'HTML::Entities' => '0.00';
requires 'JSON' => '0.00';
requires 'LWP::Authen::Digest' => '0.00';
requires 'LWP::Simple' => '0.00';
requires 'LWP::UserAgent' => '0.00';
requires 'POSIX' => '0.00';
requires 'Storable' => '0.00';
requires 'Term::ANSIColor' => '0.00';
requires 'Time::HiRes' => '0.00';
requires 'Time::Local' => '0.00';
requires 'URI::Escape' => '0.00';
requires 'JSON::WebToken' => '0.00';

version '0.01_009';
license 'gpl3';
perl_version '5.8.8';

install_script 'streamScheduleSync.pl';

author  'Milan Chrobok <mc@radiopiloten.de>';

postamble <<'END_OF_MAKEFILE';
install:: extra_install
pure_install:: extra_install
install_vendor:: extra_install

extra_install:
	
	install -d $(DESTDIR)/etc/
	install -m 775 -d $(DESTDIR)/etc/stream-schedule/
	install -m 775 -d $(DESTDIR)/etc/stream-schedule/gsync
	install -m 644 etc/stream-schedule/gsync/gsync.conf  $(DESTDIR)/etc/stream-schedule/gsync/gsync.conf
	install -m 644 etc/stream-schedule/gsync/serviceAccount.key  $(DESTDIR)/etc/stream-schedule/gsync/serviceAccount.key	

END_OF_MAKEFILE

WriteAll;

