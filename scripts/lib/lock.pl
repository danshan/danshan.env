#!/usr/bin/perl

use strict;
use warnings;

use Errno qw(EAGAIN EWOULDBLOCK);
use Fcntl qw(LOCK_EX LOCK_NB);

sub abort_lock {
    my ($message) = @_;
    print STDERR "Lock helper failed: ${message}\n";
    exit 2;
}

@ARGV == 1 or abort_lock('expected one file descriptor');
my $descriptor = $ARGV[0];
$descriptor =~ /\A[0-9]+\z/ or abort_lock('invalid file descriptor');

open(my $lock, ">&=${descriptor}")
    or abort_lock("cannot open file descriptor ${descriptor}: $!");

if (!flock($lock, LOCK_EX | LOCK_NB)) {
    my $error = 0 + $!;
    exit 1 if $error == EWOULDBLOCK || $error == EAGAIN;
    abort_lock("cannot acquire file descriptor ${descriptor}: $!");
}

exit 0;
