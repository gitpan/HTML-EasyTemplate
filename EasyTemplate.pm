#! perl -w
package HTML::EasyTemplate;
use HTML::TokeParser;
use Cwd;
use strict;
use warnings;

=head1 NAME

EasyTemplate - simple tag-based HTML templating.

=head2 VERSION

Version 0.95 26/04/2001 14:59

=cut

our $VERSION = 0.95;

=head1 DESCRIPTION

This package impliments the manipulation of templates:
loading, saving, filling, and so on.

A template is a file parsable by C<HTML::TokeParser>,
that contains C<TEMPLATE> elements with one attribute,
C<name>, used to identitfy and/or order editable regions
in the template.

=head1 SYNOPSIS

Example tempalte:

	<HTML><HEAD><TITLE>Test Doc</TITLE></HEAD>
	<BODY>
	<H1><TEMPLATEITEM name="articleTitle"></TEMPLATEITEM></H1>
	<TEMPLATEITEM name="articleText">
		This text <I>can</I> be over-writen - see the <EM>POD</EM>.
	</TEMPLATEITEM>
	</BODY>
	</HTML>

Example of filling a template with content:

	use EasyTemplate;
	my %items = (
		'articleTitle'=> 'An Example Article',
		'articleText' => 'This is boring sample text: hello world...',
	);
	my $TEMPLATE = new EasyTemplate('test_template.html');
	$TEMPLATE->title("Latka Lover");
	$TEMPLATE -> process('fill',\%items);
	$TEMPLATE -> save( '.','new.html');
	print "Saved the new document as <$TEMPLATE->{ARTICLE_PATH}>\n";
	__END__

Example of collecting from a template with content:

	use EasyTemplate;
	my $TEMPLATE = new EasyTemplate('test_template.html');
	$TEMPLATE -> process('collect');
	my %template_items = %{$TEMPLATE->{TEMPLATEITEMS}};
	foreach (keys %template_items){
		print "NAME=$_\nCONTENT=$template_items{$_}\n\n";
	}
	print "HTML doc's title was: $TEMPLATE->title\n";
	__END__

=head1 DEPENDENCIES

	Cwd;
	HTML::TokeParser
	Strict;

=head1 TEMPLATE FORMAT

A template may be any document parsable by C<HTML::TokeParser>
that contains elements C<TEMPLATEITEM> with an attribute C<name>.
Beware that an empty element of XHTML form may not be readable
by HTML::TokeParser, and that all empty C<TEMPLATEITEM> elements
are ignored by this module - if you wish to draw attention to
them, make sure they contain at least a space character.

=head1 PUBLIC METHODS

=head2 CONSTRUCTOR METHOD (new)

Requires references to the new object's class,
and a scalar representing the path at which the source
of the new template is to be found, plus a hash or
reference to a hash that contains name/value pairs
as follows:

=over 4

=item C<$self->{NO_TAGS}>

if this slot evaluates to true, the template will not contain
C<TEMPLATEITEM> tags when saved.

=item C<$self->{HTML_TITLE}>

See the C<title> method below.

=item C<$self->{FULL_TEMPLATE}>

This slot will contain the filled template once the
C<process/fill> method has been called.  See the C<save> method.

=item ARTICLE_ROOT

The directory in which the site is B<rooted>.

The ARTICLE_ROOT is stripped from filepaths when creating HTML A href elements within your site, and is replaced with...

If this is not set by the user, it is sought in the C<main::> namespace.

=item URL_ROOT

This slot is used as the BASE for created hyperlinks to files, instead of the filesystems actual ARTICLE_ROOT, above.

If this is not set by the user, it is sought in the C<main::> namespace.

=back

=cut

sub new { my ($class, $filepath) = (shift,shift);
	my %args;
	my $self = {};
	bless $self,$class;
	# Take parameters and place in object slots/set as instance variables
	if (ref $_[0] eq 'HASH'){	%args = %{$_[0]} }
	elsif (not ref $_[0]){		%args = @_ }

	# Instance variables
	$self->{SOURCE_PATH}	= $filepath;	# Path to the template to load
	$self->{ARTICLE_PATH}	= '';			# Path to the article created from the template instance
	$self->{ARTICLE_URL}	= '';			# URL  of the article created from the template instance
	$self->{FULL_TEMPLATE}	= '';			# Contents of template once replacements have been made
	$self->{TEMPLATEITEMS}	= {};			# Hash of template-item names and contents;
	$self->{HTML_TITLE}		= '';			# The text to insert in the HTML HEAD TITLE element
	$self->{NO_TAGS}		= '';			# Set a value to keep the TEMPLATEITEM tags when filling template
	# Try to load template
	if (not -e $self->{SOURCE_PATH}) {
		print "Template file \"$self->{SOURCE_PATH}\" not found!  ";
		die;
	}
	# Set these if not set by user
	$self->{ARTICLE_ROOT}	= $main::ARTICLE_ROOT if defined $main::ARTICLE_ROOT and not exists $self->{ARTICLE_ROOT};
	$self->{URL_ROOT}	= $main::URL_ROOT if defined $main::URL_ROOT and not exists $self->{URL_ROOT};

	return $self;
}



=head2 METHOD title

Sets C<$TEMPLATE->{HTML_TITLE}>, which is
the HTML title to be substituted in the template.

Accepts: scalar.
Returns: nothing.

=cut

sub title { my ($self,$title) = (shift,shift);
	$self->{HTML_TITLE} = $title if $title;
}



=head2 METHOD save

Save the file.  If a path is specified, use it; otherwise or make one up.

Accepts:

=over 4

=item 1.

reference to Template object;

=item 2.

directory in which to save article in;

=item 3.

optionally a filename to save as.

=back

Returns: file path of saved file.

This method incidently returns a reset C<$self>'s C<ARTICLE_PATH>;

DEVELOPMENT NOTE: it may be an idea to bear in mind
temporary renaming of files: as C<File::Copy> says:

	"The newer version of File::Copy exports a move() function."

=cut

sub save { my ($self, $save_dir, $file_name) = (shift,shift,shift);
	print "EasyTemplate::save requires a directory to in save as its second parameter, at least use '.'."
		and die if not defined $save_dir;
	print  "Specified dir <$save_dir> does not exist."
		and die if not -e $save_dir;

	local *OUTPUT;

	if ($file_name eq ""){
		$file_name = time.".html";
		$self->set_article_path($save_dir."/".$file_name);
	} else {
		$self->set_article_path($save_dir.'/'.$file_name);
	}

	open OUTPUT, ">$self->{ARTICLE_PATH}" or print "EasyTemplate::save could not open $self->{ARTICLE_PATH} for writing." and die $!;
		print OUTPUT $self->{FULL_TEMPLATE};
	close OUTPUT;

	$self -> set_article_url( "$save_dir/$file_name");
	return $self->{ARTICLE_PATH};
}





=head2 METHOD process

Fill a template or take variables from a template.

Accepts, in this order:

=over 4

=item 1.

method of operation: 'C<fill>' or 'C<collect>'.

=item 2.

if method argument above is set to 'C<fill>', a reference to a hash.

=back

If the first argument is set to 'C<collect>', the values of all C<TEMPLATEITEM>
elements will be collected into the instance variable C<%TEMPLATEITEMS>, with
the C<name> attribute of the element forms the key of the hash.

If the first argument is set to 'C<fill>', the template will be filled with values
stored in the hash refered to in the third argument.

The second parameter, if present, should refer to a hash whose keys
are C<TEMPLATEITEM> element C<name> attributes, and values are the element's contents.

Uses C<HTML::TokeParser> to iterate through template,replacing all text tagged with
C<TEMPLATEITEM name="x"> with the value of I<x> being the keys of the third argument.
So if that parser module can't read it, neither can this module.

=cut

# On finding a template item; the 'name' attribute of this TEMPLATEITEM element
# acts as the value to the C<%usrvals> key.
# Ignore *everything* until the end of the element, replacing it with
# the contents of $usrvals{$name}, where $name is specified in TEMPLATEITEM name="x".
# It may be worth checking for invalidly nested TEMPLATEITEM elements.

sub process { my ($self, $method, $usrvals) = (shift,shift,shift);
	print "User-values not a hash reference!\n Usage: \$self->process(\$method,\$ref_to_hash)" and die if defined $usrvals and ref $usrvals ne 'HASH';
	print "No 'method' supplied!\n Usage: \$self->process(\$method,\$ref_to_hash)." and die if not defined $method;
	my %usrvals; %usrvals = %$usrvals if defined $usrvals;
	my $name = "";			# The 'name' attribute from TEMPLATEITEM elements, cf. $usrvals{$name}
	my $substitute = 0;		# Flag set when ignoring elements nested within a TEMPLATEITEM element
	my $p = HTML::TokeParser->new( $self->{SOURCE_PATH} ) or print "Can't create TokeParser object!\n $!" and die;
	my $htmltitle = 0;		# Flags when inside HTML TITLE element

	# Cycle through all tokens in the HTML template file
	while (my $token = $p->get_token) {
		# Insert an HTML TITLE
		if ( @$token[0] eq 'S' and @$token[1] eq 'title' ){
			$htmltitle = 1;
			$self->{FULL_TEMPLATE}	.= "<TITLE>" if $method eq "fill";
		}
		elsif ( @$token[0] eq 'E' and @$token[1] eq 'title' ){
			$htmltitle = 0;
			$self->{FULL_TEMPLATE}	.= "</TITLE>" if $method eq "fill";
		}
		elsif ( @$token[0] eq 'T' and $htmltitle>0 ){
			if ($method eq 'collect'){
				$self->{HTML_TITLE} .= @$token[1];
			} elsif ($method eq 'fill' and not exists $self->{HTML_TITLE}) {
				$self->{FULL_TEMPLATE} .= @$token[1];						# Retain the text from HTML TITLE element
			} elsif ($method eq 'fill' and exists $self->{HTML_TITLE} and $self->{HTML_TITLE} ne '') {
				$self->{FULL_TEMPLATE} .= $self->{HTML_TITLE} 				# Substitute our text
					if $self->{FULL_TEMPLATE} !~ /$self->{HTML_TITLE}$/;	# if not already done so
			} elsif ($method eq 'fill' and exists $usrvals{HTML_TITLE}) {
				$self->{FULL_TEMPLATE} .= $usrvals{HTML_TITLE} 				# Substitute our text
					if $self->{FULL_TEMPLATE} !~ /$usrvals{HTML_TITLE}$/;	# if not already done so
			}
		}

		# Found the start of a template item?
		elsif ( (@$token[1] eq 'templateitem') and (@$token[0] eq 'S') and exists @$token[2]->{name}) {
			$substitute = 1;				# set flag for this loop to ignore elements
			$name = "";						# Reset this var incase the TEMPLATEITEM illegally misses it's req. attribute
			$name = @$token[2]->{name};		# Get the 'name' attribute in either case, into $name
			if ($method eq 'fill'){							# If completing a template:
				$self->{FULL_TEMPLATE} .= @$token[4]		# Replace the full template tag
					if $self->{NO_TAGS};					# if we're asked to
				# Add the content at this point
				$self->{FULL_TEMPLATE} .= "\n$usrvals{$name}" if exists $usrvals{$name};	# Insert into template
			}
		}

		# End of a template time
		elsif ( (@$token[1] eq 'templateitem') and (@$token[0] eq 'E') ) {
			$self->{FULL_TEMPLATE} .= "</TEMPLATEITEM>"
				if $method eq "fill" 						# Replace the template tag
				and $self->{NO_TAGS};						# if we're asked to
			$substitute = 0;		# Reset flag for this loop to stop ignoring elements
		}

		# Work over non-TEMPLATEITEM tokens - copy accross to FULL_TEMPLATE isntance variable
		elsif ($method eq 'fill' and not $substitute) {		# Add the original element
			my $literal="";
			if    (@$token[0] eq 'S') { $literal = @$token[4]; }
			elsif (@$token[0] eq 'E') { $literal = @$token[2]; }
			else                      { $literal = @$token[1]; }
			$self->{FULL_TEMPLATE} .= $literal;	# Complete the template
		}

		# Substitution of TEMEPLATEITEM contents or not
		elsif ($method eq 'collect' and $substitute){
		# Remember filling of templateitem node is done on encountering opening of tempalteitem element, above
			my $literal = "";
			if    (@$token[0] eq 'S') { $literal = @$token[4]; }
			elsif (@$token[0] eq 'E') { $literal = @$token[2]; }
			else                      { $literal = @$token[1]; }
			$self->{TEMPLATEITEMS}->{$name} .= $literal;# Store the template's element name and default value
		}


		# End if
	} # Whend
} # End sub fill





=head2 METHOD set_article_path

Accepts and returns one scalar, the path to use for the object's C<ARTICLE_PATH> slot.

=cut

sub set_article_path { my ($self, $path) = (shift,shift);
	return $self->{ARTICLE_PATH} = $path;
}


=head2 METHOD set_article_url

Acceptsand returns one scalar, the C<ARTICLE_URL> slot.

If C<ARTICLE_ROOT> is set, strips this from the
path supplied,.

If C<URL_ROOT> is set, prepends this to the
path supplied.

Mainly for the author's private use in other packages
that may later appear on CPAN.

=cut

sub set_article_url { my ($self, $path) = (shift,shift);
	if (not $path and $self->{ARTICLE_PATH}){
		$path = $self->{ARTICLE_PATH};
	}
	$path =~ s/^($self->{ARTICLE_ROOT})// if exists $self->{ARTICLE_ROOT};
	if (exists $self->{ARTICLE_ROOT}){
		$self->{ARTICLE_URL} = $self->{URL_ROOT}.$path if exists $self->{URL_ROOT};
	} else {
		$self->{ARTICLE_URL} = $path;
	}
	return $self->{ARTICLE_URL};
}



1; # Return a true value for 'use'

=head1

See also HTML::EasyTemplate::DirMenu

=head1 AUTHOR

Lee Goddard (LGoddard@CPAN.org)

=head1 COPYRIGHT

Copyright 2000-2001 Lee Goddard.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

