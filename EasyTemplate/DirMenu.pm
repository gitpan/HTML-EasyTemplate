package HTML::EasyTemplate::DirMenu;
use HTML::EasyTemplate;
use strict;
use Cwd;

our $VERSION = 0.02;	# 24/04/2001

=pod

=head1 TITLE

HTML::EasyTemplate::DirMenu

=head1 DESCRIPTION

Provide an easy means of creating from a directory (and/or tree) a representative block of HTML suitable for use as an substitution item in an HTML::Easytemplate item.

=head1 SYNOPSIS

Print a simple index of HTML files in current working directory:

	use HTML::EasyTemplate::DirMenu;
	my $m = new HTML::EasyTemplate::DirMenu (
		'START'		=> 'E:/www/emc2.vhn.net/live',
		'URL_ROOT'	=> 'http://desk',
		'EXTENSIONS'=> '.*',
		'RECURSE'	=> 'true',
		'DIRNAMES'	=> 'true',
		'HTMLTOP'	=> '<OL>',
		'HTMLBOT'	=> '</OL>',
		'ITEMOPEN'	=> '<LI>',
		'ITEMCLOSE'	=> '</LI>',
		'DIROPEN'	=> '<BIG>',
		'DIRCLOSE'	=> '</BIG>',
	);
	print $m->{HTML};

Add the following lines to the above for a menu to an EasyTemplate, as C<TEMPLATEITEM name='menu1'>, based on the example provided in C<HTML::EasyTemplate>:

	use HTML::EasyTemplate;
	my $m = new HTML::EasyTemplate::DirMenu (
		'START'		=> 'E:/www/emc2.vhn.net/live',
		'URL_ROOT'	=> 'http://desk',
		'EXTENSIONS'=> '.*',
		'RECURSE'	=> 'true',
		'DIRNAMES'	=> 'true',
		'HTMLTOP'	=> '<OL>',
		'HTMLBOT'	=> '</OL>',
		'ITEMOPEN'	=> '<LI>',
		'ITEMCLOSE'	=> '</LI>',
		'DIROPEN'	=> '<BIG>',
		'DIRCLOSE'	=> '</BIG>',
	);

	my %items = (
		'articleTitle'=> 'An Example Article',
		'articleText' => 'This is boring sample text: hello world...',
		'menu1'		  => $m->{HTML},
	);
	my $TEMPLATE = new EasyTemplate('test_template.html');
	$TEMPLATE->title("Latka Lover");
	$TEMPLATE -> process('fill',\%items);
	$TEMPLATE -> save( '.','new.html');
	print "Saved the new document as <$TEMPLATE->{ARTICLE_PATH}>\n";
	__END__


=head1 DEPENDENCIES and PRAGMA

	EasyTemplate;
	cwd;
	strict;

=head1 Constructor method (new)

The method expects a package/class referemnce as it's first parameter.  Following that, arguments should be passed in the form of an anonymous hash or as name/value pairs:

	my $m = new HTML::EasyTemplate::DirMenu (
			'arg1'=>'val1','arg2'=>'val2',
	);

or:

	my $m = new HTML::EasyTemplate::DirMenu (
			{'arg1'=>'val1','arg2'=>'val2',}
	);

=head2 Arguments

=item RECURSE

If not set, indexes are only of documents in the START directory specified elsewhere in the parameter list (default is the current working directory).

If it is set, causes indexes to be as if not set, with the addition that they include references to the contents of directories and children of the START directory specified elsewhere in the parameter list.

=item START

The directory to index, or at which to start indexing.

=item EXTENSIONS

Filter - a regular expression fragment applied to the filenames within a directory.  The regular expression fragment is insensitive to case, is bracketed, and matches after a dot and before the end:

	m/\.($HERE)$/i

Deafults to C<.*\.html?$>.

=item HTMLTOP, HTMLBOT

HTML to put at the top and bottom of the menu output.

=item ITEMOPEN, ITEMCLOSE

HTML to put at before and after each menu item.

=item HTMLDEFAULT

HTML to use when no files are found in a directory. Defaults to C<[No content]>.

=item DIRNAMES

Set if the directory names shoudld be included. Defaults to C<'true'>.

=item PRINTEXTENSIONS

Request that filename extensions, defined in the object's C<EXTENSIONS> slot above, be included in the printing of a filename.

=item ARTICLE_ROOT

The directory in which to begin work; defaults to the same value as the START slot detailed above.

The ARTICLE_ROOT is stripped from filepaths when creating HTML A href elements, and replaced with...

=item URL_ROOT

This slot is used as the BASE for created hyperlinks to files, instead of ARTICLE_ROOT, above.

=item URL_ROOT


=cut


sub new { my ($class) = (shift);
	my %args;
	my $self = {};
	bless $self, $class;
	# Take parameters and place in object slots/set as instance variables
	if (ref $_[0] eq 'HASH'){	%args = %{$_[0]} }
	elsif (not ref $_[0]){		%args = @_ }

	# Set default values for public slots
	$self->{START} = cwd;
	$self->{URL_ROOT} = 'http://localhost/';
	$self->{EXTENSIONS}	= '.*\.html?$';
	$self->{HTMLTOP}	= '';
	$self->{HTMLBOT}	= '';
	$self->{ITEMOPEN}	= '';
	$self->{ITEMCLOSE}	=> '';
	$self->{DIROPEN}	=> '<BIG>',
	$self->{DIRCLOSE}	=> '</BIG>',
	$self->{HTMLDEFAULT}= '[No content]';
	$self->{DIRNAMES}	= 'true';


	# Set/overwrite public slots with user's values
	foreach (keys %args) {	$self->{uc $_} = $args{$_} }

	# Force these to match
	$self->{ARTICLE_ROOT} = $self->{START} if exists $self->{START};
	$self->{START} = $self->{ARTICLE_ROOT} if exists $self->{ARTICLE_ROOT} and not exists $self->{ARTICLE_ROOT};
	warn "Please supply either the 'START' or 'ARTICLE_ROOT' parameter." if not exists $self->{START};

	# Private slots
	$self->{HTML}		= '';
	$self->{FILES}		= {};	# key = dirname; value = [file1 .. fileN]

	# Get the file paths
	$self->collect_this_dir ( $self->{START} );
	# Create HTML page
	$self->create_html;

	return $self;
}



=head1 METHOD collect_this_dir

Sets the THIS_DIR slot of the calling object with an HTML index page of the directory specified in the calling object's START_DIR slot.

If the calling object has a slot set named ARTICLE_ROOT, or there exists C<$main::ARITLCLE_ROOT>, then this is removed from the begining of every filename, and replaced with the value in either the calling object's URL_ROOT, or C<$main::URL_ROOT>.

Incidentally returns the HTML added to the THIS_DIR slot.

=cut

sub collect_this_dir { my ($self,$dir)= (shift,shift);
	warn "Usage: \$self->collect_this_dir (\$dir_to_look_in)" and return undef if not $dir;
	warn "Dir supplied does not exist: $!" if not chdir $dir;
	local *DIR;
	opendir DIR, $dir
						or warn "Passed dir <$dir> can't be opened: does it exist?"
						and return undef;
	my $dir_mod = $dir;
	if (exists $self->{ARTICLE_ROOT}){
		$dir_mod =~ s/^($self->{ARTICLE_ROOT})// if defined $self->{ARTICLE_ROOT};
	} elsif (defined $main::ARTICLE_ROOT) {
		$dir_mod =~ s/^($main::ARTICLE_ROOT)// if defined $main::ARTICLE_ROOT;
	}
	if (exists $self->{URL_ROOT}) {
		$dir_mod = $self->{URL_ROOT}.$dir_mod;
	} elsif (defined $main::ARTICLE_ROOT){
		$dir_mod = $main::URL_ROOT.$dir_mod if $main::URI_ROOT;
	} else {
		$dir_mod = $main::ARTICLE_ROOT . $dir_mod;
	}

	foreach my $fn (grep {!-d and /\.($self->{EXTENSIONS})$/} readdir DIR){
		push @{$self->{FILES}->{$dir_mod}},$fn;
	}
	closedir DIR;

	opendir DIR, $dir;
	if ($self->{RECURSE}){
		foreach my $dn (grep {-d and !/^\.{1,2}$/} readdir DIR){
			$self->collect_this_dir( $dir.'/'.$dn );
		}
	}
	return $self->{HTML};
}






=head1 METHOD create_html

Composes HTML from object slots detailed in the constructor method's documentation.

Incidentaly returns that HTML.
=cut

sub create_html { my $self = shift;
	$self->{HTML} = "\n<!-- HTMLTOP follows -->\n" . $self->{HTMLTOP} . "\n\n";
	if ($self->{FILES} ne {}) {			# Create the menu if files were found
		foreach my $dir (keys %{$self->{FILES}} ){
			$self->{HTML} .= "\n<!-- Dir $dir -->\n";
			$self->{HTML} .= "\t$self->{DIROPEN}" if exists $self->{DIROPEN} and exists $self->{DIRNAMES};

			my $dir_mod = $dir;
			if (exists $self->{URL_ROOT}){
				$dir_mod =~ s/^($self->{URL_ROOT})// if defined $self->{ARTICLE_ROOT};
			} elsif (defined $main::ARTICLE_ROOT) {
				$dir_mod =~ s/^($main::URL_ROOT)// if defined $main::ARTICLE_ROOT;
			}
			$dir_mod = '/' if $dir_mod eq '';

			my $root;
			my $seg;
			if ($root=$self->{URL_ROOT}){$root=$main::URL_ROOT}
			foreach (split '/',$dir_mod){
				next if $_ eq '';
				$root .= '/'.$_;
				$seg .= "/<A href='$root'>$_</A>";
			}

			$self->{HTML} .= "\t$seg\t" if exists $self->{DIRNAMES};
			$self->{HTML} .= "\t$self->{DIRCLOSE}\n" if exists $self->{DIRCLOSE} and exists $self->{DIRNAMES};
			foreach (@{$self->{FILES}->{$dir}}){
				$self->{HTML} .= "\t$self->{ITEMOPEN}\n";
				$self->{HTML} .= "\t\t<A href='$dir/$_'>";
				if (exists $self->{PRINTEXTENSIONS}) {
					$self->{HTML} .= "$dir/$_";
				} else {
					s/\.($self->{EXTENSIONS})$//gi;
					$self->{HTML} .= $_;
				}
				$self->{HTML} .= "</A>\n";
				$self->{HTML} .= "\t$self->{ITEMCLOSE}\n";
			}
		} # Next dir
	} else {
		$self->{HTML} .= "\t$self->{ITEMOPEN}\n\t\t$self->{HTMLDEFAULT}\n\t$self->{ITEMCLOSE}\n\n";
	}
	$self->{HTML} .= "\n<!-- HTMLBOT follows -->\n" . $self->{HTMLBOT} ."\n\n";
	return $self->{HTML};
}



1; # Return a true value for 'use'

=head1

See also HTML::EasyTemplate

=head1 AUTHOR

Lee Goddard (LGoddard@CPAN.org)

=head1 COPYRIGHT

Copyright 2000-2001 Lee Goddard.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

