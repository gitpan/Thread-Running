BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Test::More tests => 14;
use strict;
use warnings;

use_ok( 'Thread::Running', qw(exited running tojoin) );
can_ok( 'main',qw(
 running
 tojoin
 exited
) );

my $sleep = 3;
my $threads = 5;

my $thread = threads->new( sub { sleep $sleep } );
my $tid = $thread->tid;
is( scalar running( $thread ),"1", "check running by thread" );
is( scalar running( $tid ),"1", "check running by tid" );

sleep $sleep+1+1;   # allow for a little margin

is( scalar exited( $thread ),"1", "check exited by thread" );
is( scalar exited( $tid ),"1", "check exited by tid" );

is( scalar tojoin( $thread ),"1", "check tojoin by thread" );
is( scalar tojoin( $tid ),"1", "check tojoin by tid" );

$thread->join;

my @thread;
foreach (1..$threads) {
    push @thread,threads->new( sub { sleep $sleep } );
}

my @tid = map { $_->tid } @thread;
is( "@{[running( @thread )]}","@tid", "check running by threads" );
is( "@{[running( @tid )]}","@tid", "check running by tids" );

sleep $sleep+$threads+1;   # allow for a little margin

is( "@{[exited( @thread )]}","@tid", "check exited by threads" );
is( "@{[exited( @tid )]}","@tid", "check exited by tids" );

is( "@{[map {$_->tid} tojoin( @thread )]}","@tid", "check tojoin by threads" );
is( "@{[map {$_->tid} tojoin( @tid )]}","@tid", "check tojoin by tids" );

$_->join foreach @thread;
