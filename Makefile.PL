use ExtUtils::MakeMaker;

WriteMakefile
(
	NAME            => 'NEXT::init',
	VERSION         => '1.03',
	ABSTRACT		=> <<'END',

DWIM data inheritence for hashes and arrays.

END

	PREREQ_PM =>
	{
		# standard distro, particular versions 
		# are unlikely to cause pain.

		strict    => 0,
		warnings  => 0,
		NEXT      => 0,
	},
);
