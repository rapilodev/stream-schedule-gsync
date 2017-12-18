package StreamSchedule::Log;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(printInfo printWarning printError printExit) ;
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

sub printInfo{
    my $message=shift;
    chomp $message;
    #my ($package, $filename, $line, $subroutine) = caller(1);
    #$message="$filename, line $line, $package::$subroutine: ".$message;
    print STDERR "INFO: $message\n";
}

sub printWarning{
    my $message=shift;
    chomp $message;
    #my ($package, $filename, $line, $subroutine) = caller(1);
    #$message="$filename, line $line, $package::$subroutine: ".$message;
    print STDERR "WARNING: $message\n";
}

sub printError{
	my $message=shift;
	chomp $message;
    #my ($package, $filename, $line, $subroutine) = caller(1);
    #$message="$filename, line $line, $package::$subroutine: ".$message;
	print STDERR "ERROR: $message\n" ;
}

sub printExit{
    my $message=shift;
    chomp $message;
    #my ($package, $filename, $line, $subroutine) = caller(1);
    #$message="$filename, line $line, $package::$subroutine: ".$message;
    print STDERR "FATAL: $message\n" ;
    exit 1;
}


