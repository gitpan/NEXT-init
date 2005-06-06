use ExtUtils::MakeMaker;

WriteMakefile
(
	NAME            => 'NEXT::init',
	VERSION         => '1.04.1',
	ABSTRACT		=> <<'END',

DWIM data inheritence for hashes and arrays for 
simple object or ones with mutiple base classes.
Handles sanity checks between class data types,
default construct and init.

END

	PREREQ_PM =>
	{
		# standard distro, particular versions 
		# are unlikely to cause pain.

		strict          => 0,
		warnings        => 0,
		NEXT            => 0,
        Scalar::Util    => 0,
	},
);
