use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::EasyTemplate',
    'VERSION_FROM'	=> 'EasyTemplate.pm', # finds $VERSION
    'PREREQ_PM'		=> {
		HTML::TokeParser=>2.19,
    	Fcntl=>0.1,
	},
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'EasyTemplate.pm',
       AUTHOR     => 'Lee Goddard <lgoddard@cpan.com>') : ()),
);
