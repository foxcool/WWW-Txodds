#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Txodds' ) || print "Bail out!\n";
}

diag( "Testing Txodds $Txodds::VERSION, Perl $], $^X" );
