package StreamSchedule::Log;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(printInfo printWarning printError printExit) ;
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

sub printInfo{
    my ($message) = @_;
    chomp $message;
    print STDERR "INFO: $message\n";
}

sub printWarning{
    my ($message) = @_;
    chomp $message;
    print STDERR "WARNING: $message\n";
}

sub printError{
    my ($message) = @_;
    chomp $message;
    print STDERR "ERROR: $message\n" ;
}

sub printExit{
    my ($message) = @_;
    chomp $message;
    print STDERR "FATAL: $message\n" ;
    exit 1;
}


