require 5.008;
use threads (); # just to force breakage if threads are not available
use ExtUtils::MakeMaker;

WriteMakefile (
 NAME		=> "Thread::Running",
 AUTHOR		=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
 ABSTRACT	=> 'provide non-blocking check whether threads are running',
 VERSION_FROM	=> 'lib/Thread/Running.pm',
 PREREQ_PM	=> {
		   Thread::Exit => '0.05',
                   },
);
