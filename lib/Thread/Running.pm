package Thread::Running;

# Make sure we have version info for this module
# Make sure we do everything by the book from now on

$VERSION = '0.01';
use strict;

# Make sure we can do threads
# Make sure we can do shared variables

use threads ();
use threads::shared ();

# Shared hash for keeping exited threads
#  undef = thread started
#  0     = thread detached
#  1     = undetached thread exited
#  2     = thread joined or detached thread exited

my %exited : shared;

# Enable Thread::Exit with thread marking stuff

use Thread::Exit

# Mark the thread as started 

    begin => sub { $exited{threads->tid} = undef },

# Obtain the thread ID
# Set to joined if marked as detached, else as undetached exited

    end => sub {
        my $tid = threads->tid;
        $exited{$tid} = 1 + defined $exited{$tid};
    },
;

# Thread local reference to original threads::detach (set in BEGIN)
# Thread local reference to original threads::join (set in BEGIN)

my $detach;
my $join;

# Make sure we do this before anything else
#  Allow for dirty tricks
#  Keep reference to current detach routine
#  Hijack the thread detach routine with a sub that unsets the flag
#  Keep reference to current join routine
#  Hijack the thread join routine with a sub that unsets the flag

BEGIN {
    no strict 'refs'; no warnings 'redefine';
    $detach = \&threads::detach;
    *threads::detach = sub { $exited{$_[0]->tid} = 0; goto &$detach };
    $join = \&threads::join;
    *threads::join = sub { $exited{$_[0]->tid} = 2; goto &$join };
} #BEGIN

# Satisfy -require-

1;

#---------------------------------------------------------------------------

# Class methods

#---------------------------------------------------------------------------
#  IN: 1 class
#      2..N subroutines to export

sub import {

# Lose the class
# Obtain the namespace
# Set the defaults if nothing specified
# Allow for evil stuff
# Export whatever needs to be exported

    shift;
    my $namespace = (scalar caller() ).'::';
    @_ = qw(exited running tojoin) unless @_;
    no strict 'refs';
    *{$namespace.$_} = \&$_ foreach @_;
} #import

#---------------------------------------------------------------------------

# Special stuff that we can't AUTOLOAD because it's in another package

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
#      2..N thread ID's that should be checked
# OUT: 1..N thread ID's that are still running

sub threads::running { shift; goto &running } #threads::running

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
#      2..N thread ID's that should be checked
# OUT: 1..N thread ID's that can be join()ed

sub threads::tojoin { shift; goto &tojoin } #threads::tojoin

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
#      2..N thread ID's that should be checked
# OUT: 1..N thread ID's that have exited

sub threads::exited { shift; goto &exited } #threads::exited

#---------------------------------------------------------------------------
#  IN: 1..N thread (ID's) that should be checked
# OUT: 1..N thread ID's that are still running

sub running {

# For all of the threads specified
#  Make sure we have a thread ID
#  Reloop if we haven't seen this thread start or it has exited already
#  Return with succes now if in scalar context
#  Add thread ID to list
# Return list of thread ID's that have exited

    my @tid;
    foreach (@_) {
        my $tid = ref( $_ ) ? $_->tid : $_;
        next if !exists $exited{$tid} or $exited{$tid};
        return 1 unless wantarray;
        push @tid,$tid;
    }
    @tid;
} #running

#---------------------------------------------------------------------------
#  IN: 1..N thread (ID's) that should be checked
# OUT: 1..N threads that can be joined

sub tojoin {

# For all of the threads specified
#  Reloop if this thread is not ready to be joined
#  Return with succes now if in scalar context
#  Add thread ID to list if exited
# Return now if nothing found

    my @tid;
    foreach (@_) {
        my $tid = ref( $_ ) ? $_->tid : $_;
        next unless $exited{$tid} == 1;
        return 1 unless wantarray;
        push @tid,$tid;
    }
    return () unless @tid;

# Create hash of thread objects keyed to thread ID's
# Return list of thread objects that can be joined

    my %thread = map { $_->tid => $_ } threads->list;
    @thread{@tid};
} #tojoin

#---------------------------------------------------------------------------
#  IN: 1..N thread ID's that should be checked
# OUT: 1..N threads that exited

sub exited {

# For all of the threads specified
#  Reloop if this thread hasn't exit
#  Return with succes now if in scalar context
#  Add thread ID to list if exited
# Return list of thread ID's that have exited

    my @tid;
    foreach (@_) {
        my $tid = ref( $_ ) ? $_->tid : $_;
        next unless $exited{$tid};
        return 1 unless wantarray;
        push @tid,$tid;
    }
    @tid;
} #exited

#---------------------------------------------------------------------------

__END__

=head1 NAME

Thread::Running - provide non-blocking check whether threads are running

=head1 SYNOPSIS

    use Thread::Running;      # exports running(), exited() and tojoin()
    use Thread::Running qw(running);   # only exports running()
    use Thread::Running ();   # threads class methods only

    my $thread = threads->new( sub { whatever } );
    while (threads->running( $thread )) {
    # do your stuff
    }

    $_->join foreach threads->tojoin;

    until (threads->exited( $tid )) {
    # do your stuff
    }

=head1 DESCRIPTION

                  *** A note of CAUTION ***

 This module only functions on Perl versions 5.8.0 and later.
 And then only when threads are enabled with -Dusethreads.  It
 is of no use with any version of Perl before 5.8.0 or without
 threads enabled.

                  *************************

This module adds three features to threads that are sorely missed by some:
you can check whether a thread is running, whether it can be joined or whether
it has exited without waiting for that thread to be finished (non-blocking).

=head1 CLASS METHODS

These are the class methods.

=head2 running

 @running = threads->running( @thread );  # list of threads still running

 while (threads->running( @tid )) {  # while at least 1 is still running
 # do your stuff
 }

The "running" class method allows you to check whether one or more threads
are still running.  It accepts one or more thread objects or thread ID's (as
obtained by the C<threads::tid()> method).  It returns the thread ID's of the
threads that are still running (in list context).  In scalar context, it just
returns 1 or 0 to indicate whether any of the indicated threads is still
running.

=head2 tojoin

 warn "Come on and join!\n" if threads->tojoin( $thread );

 $_->join foreach threads->tojoin( @tid ); # join all joinable threads

The "tojoin" class method allows you to check whether one or more threads
can be joined.  It accepts one or more thread objects or thread ID's (as
obtained by the C<threads::tid()> method).  It returns the thread B<objects>
of the threads that have exited and which can be join()ed (if called in list
context).  In scalar context, it just returns 1 or 0 to indicate whether any
of the indicated threads can be joined.

=head2 exited

 @exited = threads->exited( @tid ); # list of threads that have exited

 until (threads->exited( @tid )) { # until at least 1 has exited
 # do your stuff
 }

The "exited" class method allows you to check whether one or more threads
have stopped running.  It accepts one or more thread ID's (as obtained by the
C<threads::tid()> method).  It returns the thread ID's of the threads that
have exited (in list context).  In scalar context, it just returns 1 or 0
to indicate whether any of the indicated threads has exited.

=head1 CAVEATS

This module is dependent on the L<Thread::Exit> module, with all of its
CAVEATS applicable.

=head1 TODO

Examples should be added.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2003 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<threads>, L<Thread::Exit>.

=cut
