#!/opt/bin/perl 
########################################################################
# test for NEXT::init.
# generates hashes and arrays w/ and w/o inherited values, check that
# the order of inheritence leaves arrays with most-ancesteral data at
# the end.
########################################################################

########################################################################
# housekeeping
########################################################################

$" = ' ';
$\ = "\n";

use strict;
use warnings;

use Test::Simple qw( tests 33 );

my $verbose = grep { /verbose/i } @ARGV;

use Data::Dumper;
	$Data::Dumper::Purity           = 1;
	$Data::Dumper::Terse            = 1;
	$Data::Dumper::Indent           = 1;
	$Data::Dumper::Sortkeys			= 1;
	$Data::Dumper::Deepcopy         = 0;
	$Data::Dumper::Quotekeys        = 0;

use FindBin::libs;

use NEXT::init qw( :verbose=1 :debug=0 );

my %baseline_hash = 
(
	verbose => 2,
	debug => 1,
);

my @db1 = 
(
	'dbi:Oracle:host=somehost;sid=somesid',
	'user1',
	'pass1',
	{
		RaiseError => 1,
		AutoCommit => 0,
	}
);

my @db2 =
(
	'dbi:Oracle:host=anotherhost;sid=anothersid',
	'user2',
	'pass2',
	{
		RaiseError => 1,
		AutoCommit => 0,
	},
);

# note: passing a reference as \%meta will update the
# %meta in this package directly, which may cause 
# problems if multiple copies are instantiated and
# any of the init methods use internal values. otherwise,
# passing the referent is more effectient.

my $obj0 = foo->construct( %baseline_hash );
my $obj1 = bar->construct( %baseline_hash, dbi_connect => \@db1 );
my $obj2 = foo_plus->construct( %baseline_hash, dbi_connect => \@db2 );
my $obj3 = foo_plus_bar->construct( \%baseline_hash );

print
	"\n\nHash objects:",
	map { "\n\n" . Dumper $_ }
	( $obj0, $obj1, $obj2, $obj3 )
	if $verbose
;

ok $obj0->can($_), "obj0 can $_"
	for qw( init construct );

ok $obj0->{foo},              'obj0 has foo entry';
ok $obj0->{package} eq 'foo', 'obj0 package is foo';

ok $obj1->{bar},              'obj1 has bar entry';
ok $obj1->{package} eq 'bar', 'obj1 package is bar';

ok $obj2->{foo},              'obj2 has foo entry';
ok $obj2->{foo_plus},         'obj2 has foo_plus entry'; 
ok $obj2->{package} eq 'foo_plus',
	                          'obj2 package is foo_plus';

ok $obj3->{foo},              'obj3 has foo entry';
ok $obj3->{bar},              'obj3 has bar entry';
ok $obj3->{foo_plus},         'obj3 has foo_plus entry'; 
ok $obj3->{package} eq 'foo_plus',
	                          'obj2 package is foo_plus';

ok $obj1->{dbi_connect}[1] eq 'user1', 'obj1 uses user1';
ok $obj2->{dbi_connect}[1] eq 'user2', 'obj2 uses user2';

# sanity: baseline wasn't passed by reference, it shouldn't values
# have inherited any values in the process.

ok ! exists $baseline_hash{dbi_connect}, 'baseline_hash lacks dbi_connect';

# now check the array objects...

my $obj4 = MyArray->construct();
my $obj5 = MyArray->construct( qw( e f g h ) );
my $obj6 = MyArray->construct( [ qw( e f g h ) ] );
my $obj7 = MyArray->construct( { qw( e f g h ) } );

print
	"\n\nArray objects:",
	map { "\n\n" . Dumper $_ }
	( $obj4, $obj5, $obj6, $obj7 )
	if $verbose
;

ok @$obj4  == 3,      '@$obj4 == 3';
ok $obj4->[0] eq 'a', '$obj4->[0] eq a';

ok @$obj5  == 7,        '@$obj5 == 7';
ok $obj5->[0] eq 'e',  '$obj5->[0] eq e';
ok $obj5->[-1] eq 'c', '$obj5->[-1] eq c'; 

ok @$obj6  == 4,        '@$obj6 == 4';
ok ref $obj6->[0] eq 'ARRAY',  '$obj6->[0] is an array';
ok $obj6->[-1] eq 'c', '$obj6->[-1] eq c'; 

ok @$obj7  == 4,        '@$obj7 == 4';
ok ref $obj7->[0] eq 'HASH',  '$obj7->[0] is a hash';
ok $obj7->[-1] eq 'c', '$obj7->[-1] eq c'; 

my $obj8 = Queue->construct( qw( queue ) );

my $obj9 = Stack->construct( qw( stack ) );

print
	"\n\nQueue vs. Stack:",
	map { "\n\n" . Dumper $_ }
	( $obj8, $obj9 )
	if $verbose
;

ok @$obj8 == 7,           '@$obj8 == 7';
ok $obj8->[0] eq 'queue', '$obj8 is a queue';
ok $obj8->[-1] eq 'c',    '$obj8->[-1] eq c';

ok @$obj9 == 7,           '@$obj9 == 7';
ok $obj9->[-1] eq 'stack','$obj9 is a stack';
ok $obj9->[0] eq 'a',     '$obj9->[0] eq a';

exit 0;

package foo;

use NEXT::init
{
	package => __PACKAGE__,
	foo => 1,
};

package bar;

use NEXT::init
{
	package => __PACKAGE__,
	bar => 1,
};

package foo_plus;

use base qw( foo );

use NEXT::init
(
	package => __PACKAGE__,
	foo_plus => 1,
);

package foo_plus_bar;

use base qw( foo_plus bar );

package MyArray;

use NEXT::init [ qw( a b c ) ];

package Queue;

use base qw( MyArray );

use NEXT::init qw( :type=queue d e f );

package Stack;

use base qw( MyArray );

use NEXT::init qw( :type=stack d e f );

__END__
