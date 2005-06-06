
########################################################################
# generic pass-through intializer generator.
# supplies "init" subroutine to merge metadata via EVERY::LAST call
# in constructor.
########################################################################

########################################################################
# housekeeping
########################################################################

package NEXT::init;

our $VERSION = '0.99.2';

use strict;
use warnings;
use Carp;

use Symbol;
use Scalar::Util qw( reftype );

# debug output

use Data::Dumper;

########################################################################
# package variables
########################################################################

########################################################################
# subroutines
########################################################################

########################################################################
# utility subs to handle data on @_.
# re-used in import and init.
#
# lexicals avoids unintended inheritence.

########################################################################
# package variables
########################################################################

# switches that get reset each time they are processed.
# using package variables makes it a bit easier to 
# debug some nasty situations from the caller.

our $verbose = 0;
our $debug   = 0;

my %defaultz =
qw(
	export	1
	type	0
	debug	0
	verbose	0
);

########################################################################
# utility subs to handle data on @_.
# re-used in import and init.

my $switches =
sub 
{
	$DB::single = 1 if $debug;

	# set the switches.
	# this purges them from @_, leaving only
	# the object's data on the stack.
	#
	# the check on $_[0] implies the switches
	# lead any data on the stack: trailing 
	# switches will be included as data.

	my %argz = ();

	while( @_ && $_[0] =~ /^:(\S+)$/ )
	{
		my ( $name, $value ) = split /=/, $1;

		$value = 1 unless defined $value;

		if( exists $defaultz{$name} )
		{
			$argz{$name} = $value 
		}
		else
		{
			carp "\nBogus argument: $name=$value\n";
		}

		shift;
	}

	$verbose = $argz{verbose} if defined $argz{verbose};
	$debug   = $argz{debug}   if defined $argz{debug};

	exists $argz{$_} or $argz{$_} = $defaultz{$_}
		for keys %defaultz;

	\%argz
};

# first time around it takes a bit more work to 
# determine the proper type for an object. after
# the metadata and init sub's have been installed
# this doesn't need to be done again.

my $objtype =
sub
{
	$DB::single = 1 if $debug;

	# if the arguments are a referent then figure out what
	# they are and use that as a default for the type if
	# one was not passed in via ":type=blah".
	#
	# caller gets back the object's data type: hash, queue,
	# or stack.
	#
	# eval's handle blessed referents.

	my $item = shift;

	my $class = ref $item || $item;

	my $basetype =  
	do
	{
		if( my $sub = $class->can('meta') )
		{
			# if this is derived from another N::i-based
            # class then whatever its metadata type is 
            # will be re-used here. $meta is extraneous
            # but reftype $sub->() seems likely to leave
            # anyone else crosseyed...

			my $meta = $sub->();

			reftype $meta;
		}
		elsif( my $type = reftype $_[0] )
		{
            # if the caller passed in referent for the 
            # first argument use its type if there isn't
            # a base class to get it from.

            $type
		}
        else
        {
            # passed a simple list: use whatever the list
            # defines for itself via the :type (i.e., no 
            # further sanity check on the basename).

            ''
        }
	};

    # now figure out the appropriate type for this new
    # class: either it has passed a ref in $_[0], which
    # means to use that type as the current metadata,
    # or a simple list has been passed, which requires
    # checking for :type argument or defaulting to HASH.

	my $type = 
	do
	{
		if( my $a = reftype $_[0] )
		{
			if( @_ == 1 )
			{
				# single argument: figure out what it is and
				# use that type for the object. catch is that
				# ref $item may return a blessed classname 
				# instead of the base type. simplest way around
				# this -- only done once per class anyway -- 
				# is to eval expanding the object various ways.

				if( $a =~ /^(HASH|ARRAY)$/ )
				{
					$1
				}
                else
				{
					die "\nUnusable referent: '$a' not hash or array.\n";
				}
			}
			else
			{
				# can't use ref's as keys, must be an array.

				'ARRAY'
			}
		}
		elsif( $basetype )
		{
			# nothing on the argument list for figuring it out,
			# punt to the base classes: one of them will have
			# some data already defined that can be used to 
			# determine a consistent value.

			$basetype
		}
		else
		{
			die<<'END'
Unable to determine base data type:
The data arguments are not a referent and this 
class is not derived from another type.
END
		}
	};

	$basetype ||= $type;

	if( $basetype ne $type )
	{
		# second issue: is this the same type as whatever
		# the base class defines? easier to deal with 
		# mismatches here than at runtime where it's harder
		# to figure out where things came from...

		croak<<'END'
Mismatched datatypes: $class is derived from $basetype
but the data provided seems to be $type. Probably best
to either use a simple list for derived types.
END
	}

	$type
};

########################################################################
# catch: you can't check for ref $x eq 'HASH' since the reference
# may be blessed already...
#
# fix: eval the expansion in various formats and then give up.
#
# note: this has to be called AFTER switches, above, so that
# the stack has real data on it...
#
# all this does is expand a referent into a flat list.
#
# caller gets back whatever the argument list expands to.

my $expandvaluz =
sub
{
	if( @_ == 1 )
	{
        my $type = reftype $_[0];

        if( 'HASH' eq $type )
        {
            %{ $_[0] }
        }
        elsif( 'ARRAY' eq $type )
        {
            @{ $_[0] }
        }
        else
        {
            die "Bogus data type: '$type' neither hash nor array";
        }
	}
	else
	{
		@_
	}
};

########################################################################
# three cases: hashes are layered via slice going up the 
# inheritence tree, queues are pushed going down, and 
# stacks are unshifted going up -- with stack being the
# default array type.
#
# queues are built by pushing the class data going down
# the inheritence tree; stacks push the data going up.
#
# queues start out with the arguments on the data; stacks
# push the arguments on last.
#
# queues shift off the most derived data, stacks pop it off.
#
# adding successive mungers => stack.
# overriding pre-emptive handler => queue.
#
# hash-based arguments have to be expanded if they are
# passed as a referent; placing referents onto an array
# is prefectly reasonable.

my %constructorz =
(
	hash =>
	sub
	{
		use NEXT;

		my $item = shift;

		my %argz = ref $_[0] ? &$expandvaluz : @_;

		my $obj = bless {}, ref $item || $item;

		$obj->EVERY::LAST::init;

		@{ $obj }{keys %argz} = values %argz;

		$obj
	},

	queue =>
	sub
	{
		use NEXT;

		my $item = shift;

		my $obj = bless [ @_ ], ref $item || $item;

		$obj->EVERY::init;

		$obj
	},

	stack =>
	sub
	{
		use NEXT;

		my $item = shift;

		my $obj = bless [], ref $item || $item;

		$obj->EVERY::LAST::init;

		push @$obj, @_;

		$obj
	},
);

###########################################################
# passed class meta-data as a list or referent. lists 
# become hashes; others are left as-is (only arrays and
# hashes are handled gracefully at this point).
#
# the metadata is installed into the package as %meta or 
# @meta, along with a closure as &init to merge the 
# metadata with an exsiting object's contents.
#
# note: mixing metdata types (e.g., arrays with hashes) is
# fatal.

sub import
{
	local $\ = "\n";
	local $, = ", ";

	# discard the current package name.

	shift;

	my $caller = caller;

	print STDERR "\nProcessing: $caller\n" . Dumper \@_
		if $verbose;

	# pass the caller to the switch processor, object
	# type handler. 
	#
	# there is no reason to export a meta referent into
	# the main namespace.

	unshift @_, ':export=0' if $caller eq 'main';

	my $argz = &$switches;

	$DB::single = 1 if $debug;

	# if things are getting exported to the caller class
	# (vs. simply a use base) then build the typeglobs
	# via symbol and populate them with ref's (data +
	# closures).

	if( $argz->{export} )
	{
		unshift @_, $caller;

		# basetype is ARRAY or HASH.  objtype is hash, queue,
		# or stack.  default array type is stack.

		my $basetype = &$objtype;

		$argz->{type} ||=
			$basetype eq 'HASH' ? 'hash' : 'queue';

		# at this point the base data type for the object
		# is known. next step is to manufacture an emtpy
		# item type, data to merge for the object, and a
		# closure to handle the job.

		my $data = $argz->{type} eq 'hash' ?
			{ &$expandvaluz } : [ &$expandvaluz ] ;

		# now to hack the caller's namespace...

		my $init  =   qualify_to_ref 'init',      $caller;
		my $meta  =   qualify_to_ref 'meta',      $caller;
		my $const =   qualify_to_ref 'construct', $caller;

		# caller can access %meta or @meta to mangle
		# the data after installing it. we use $class->meta
		# to access an un-blessed referent for checking the
		# base data type.

		*$meta = $data;

		*$meta = sub { $data };

		# the constructor is hard-wired for the
		# specific type. this is the only place
		# where array types really matter.

		*$const = $constructorz{ $argz->{type} }
			unless defined *{$const}{CODE};

		if( $argz->{type} eq 'hash' )
		{
			*$init =
			sub
			{
				$DB::single = 1 if $debug > 1;

				my $obj = shift;

				@{$obj}{ keys %{*$meta} } = values %{*$meta};

				$obj
			}
			unless defined *$init{CODE};
		}
		else
		{
			*$init = 
			sub
			{
				$DB::single = 1 if $debug > 1;

				my $obj = shift;

				push @$obj, @{*$meta};

				$obj
			}
			unless defined *$init{CODE};
		}

	}

	# someplace to hang a breakpoint

	$DB::single = 1 if $debug;

	1
}

# keep require happy 

1

__END__

=head1 NAME

NEXT::init

DWIM data inherited data initialization via NEXT.

=head1 SYNOPSIS

Data can be hash or array based.

Hashes use EVERY::LAST to assign slices (i.e., derived
classes override the base class' values, assign new keys).

Arrays use either EVERY::init (queue) or EVERY::LAST (stack)
to push each layer's data onto the object. 

=head2 Hash-based

Each level in the init does an array-slice assignment, 
overwriting values from less-derived classes as necessary.

Given:

	package Base_Hash;

	use NEXT::init
	{
		foo => 1,

		package => 'Base'
	};

	package Derived;

	use base qw( Base_Hash );

	use NEXT::init
	{
		bar => 1,

		package => 'Derived'
	};

=over 4

Base:

	{
		foo => 1,
		package => 'Base'
	}

Derived:

	{
		foo => 1,
		bar => 1,
		package => 'Derived'
	}

=back


=head2 Array-based

There are two flavors of array: queue  and stack. 

Both push successive class' data onto the object. The difference
is that queues use EVERY::init to push the data going down the 
inheritence tree; stacks use EVERY::LAST to push it going back
up. 

queues leave the arguments at the front of the list where shift
or for(@$obj) will find them first; stacks leave the argumnts
at the end where pop will get them.

For example, from test.pl:

Given a base class of "MyArray" and two derived classes,
one queue one stack:

	package MyArray;

	use NEXT::init [ qw( a b c ) ];

	package Queue;

	use base qw( MyArray );

	use NEXT::init qw( :type=queue d e f );

	package Stack;

	use base qw( MyArray );

	use NEXT::init qw( :type=stack d e f );


Calling the constructor as:

	my $obj8 = Queue->construct( qw( queue ) );

	my $obj9 = Stack->construct( qw( stack ) );


Yields a queue of:

	bless( [
	'queue',
	'd',
	'e',
	'f',
	'a',
	'b',
	'c'
	], 'Queue' )

and a stack of:

	bless( [
	'a',
	'b',
	'c',
	'd',
	'e',
	'f',
	'stack'
	], 'Stack' )


=head1 DESCRIPTION

This is a generic initializer class for objects that need
to inherit hash or array data. When use-ed the import module
installs "init" and "constructor" method which merge each 
level of inherited data and the arguments into the object.
A method for accessing the class data and the class data
itself are installed in *meta.

The resulting objects do not inherit anything from NEXT::init
(i.e., it is not a base class). The constructor uses whatever
classes the object is based on to locate "init" methods 
during object construction; NEXT::init only provides an
import sub to install the methods and validate the base data
types.

For effeciency the init handers are closures which handle
either hash or array data propery (i.e., no repeated if-
logic, changing the base data type of the object after
construction will likely break the associated init handlers).

The object's type (hash or array) is determined either by
the type of referent passed into init or an initial ":type=foo"
argument for arrays.

Classes used as bases for other classes should probably 
just pass the data in as a referent to begin with:

	use NEXT::init
	{
		key => value
	};

for hashes or

	use NEXT::init
	[
		array 
		data
	];

for arrays. 

Derived classes can then just pass in lists, which
will be formatted appropriately based on the ref type
of the base classses:

	use NEXT::init
	(
		simple
		list
		goes
		here
	);


=head1 Installed symbols

=head2 construct

Normal use of the classes will be via:

	ClassName->construct( runtime => 'arguments' );

The arguments will be converted to an approprpriate
type for the data.

=head2 init

This called from the constructor to add class data
to the object. This is where hashes are udpated via
hash slice and arrays via push.

There is no reason to call this externally.

=head2 %meta and @meta

The values passed into NEXT::init via use are installed
as *$class::meta = ref via the Symbol module. This allows
the class to inspect or modify its class data. A method
named 'meta' is installed which returns a reference to
the class metadata. One use for this is in NEXT::init's
import, where having an unblessed referent simplifies
determining the base type.

The value of $meta is built from Symbol, with the hash-or-array
data assigned via referent:

	my $meta  =   qualify_to_ref 'meta', $caller;

	*$meta = $data;

The initializers are closures which use the lexical $meta
glob to access the class data:

	@{$object}{ keys %{*$meta} } = values %{*$meta}

	push @$object, @{ *$meta };

The package can simply refer to %meta or @meta:

	use strict;

	use NEXT::init { qw( foo bar ) };

	scalar %meta

	__END__

works just fine (with %meta installed as a valid
package symbol before strict complains about %meta
being unknown).

=head1 Import arguments

=over 4

=item :type=hash

=item :type=queue

=item :type=stack

Given a hash or array referent as input these default to 
hash or queue respectively. The only real use for these
is passing in simple-list data (vs. a referent) for base
classes [i.e., artistic preference] or setting array types
to stack. 

Setting this to a value that does not match the base type
in a derived class (e.g., :type=hash with a base class of
queue or stack) is fatal.

Mixing and matching queue and stack types is allowed and
works pretty much as expected since both types push their
data at each stage.


=item :verbose

=item :verbose=1

Defaults to one if provided, use ":verbose=0" to turn it
off, prints a bit more information during the import cycle.

Main use is in #! code to control debugging of classes 
called from the main code:

	#!/opt/bin/perl

	use NEXT::init qw( :verbose=1 );

Will turn on verbose output for any subsequent classes.

=back

The remainder of these are really only intended for 
development.

=over 4

=item :debug

=item :debug=1

=item :debug=2

Defaults to zero normally, to one if provided. This is
used in the code as:

	$DB::single = 1 if $debug;

or 

	$DB::single = 1 if $debug > 1;

This is also mainly for use in #! code (see :verbose, above).

=item :export

=item :export=1

Controls whether the symbols are exported after the 
arguments are processed. Defaults to 0 if the calling
package is "main". This is mainly for internal use to
allow #! code's setting verbose and debug.

=back

=head1 AUTHOR

Steven Lembark (lembark@wrkhors.com)

=head2 To Do

- Deal with non-array/-hash referent types (suggestions
  welcome). CODE ref's might be executed in the proper
  order but that doesn't seem much like "inheritence".

=head1 COPYRIGHT

This code is released as-is under the same terms as Perl-5.8 (or
any later version of perl at the users preference).

=head1 SEE ALSO

NEXT perlreftut perlootut
