use ExtUtils::MakeMaker;

WriteMakefile
(
	NAME            => 'NEXT::init',
	VERSION         => '1.01',
	ABSTRACT		=> <<'END',

Automate inherited initialization of array and hash data
via $obj->EVERY::LAST::init. Generates and installs an 
'init' method (via closure) and metadata from its arguments
in the calling class.

END

	PREREQ_PM =>
	{
		# standard distro, particular versions 
		# are unlikely to cause pain.

		strict    => 0,
		warnings  => 0,
	},
);
