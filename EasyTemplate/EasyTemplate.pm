#! perl -w
package EasyTemplate;

use HTML::TokeParser;
use Cwd;
use strict;

=head1 TITLE

TemplateEasy

=head2 VERSION

Version 0.91

=cut

our $VERSION = 0.9;

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

=head1 METHODS

=head2 Constructor &new

Accepts references to the new object's class,
and a scalar representing the path at which the source
of the new template is to be found.

=cut

sub new { my ($class, $filepath) = (shift,shift);
	my $self = {};
	local *IN;

	# Instance variables
	$self->{SOURCEPATH}		= $filepath;	# Path to the template to load
	$self->{ARTICLE_PATH}	= "";			# Path to the article created from the template instance
	$self->{ARTICLE_URL}	= "";			# URL  of the article created from the template instance
	$self->{FULL_TEMPLATE}	= "";			# Contents of template once replacements have been made
	$self->{TEMPLATEITEMS}	= {};			# Hash of template-item names and contents;
	$self->{HTMLTITLE}		= "";			# The text to insert in the HTML HEAD TITLE element
	# Try to load template
	if (not -e $self->{SOURCEPATH}) {
		print "Template file \"$self->{SOURCEPATH}\" not found!  ";
		die;
	}
	bless $self,$class;
	return $self;
}





=head2 &save

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

This method should set and return C<$self>'s C<ARTICLE_PATH>;

DEVELOPMENT NOTE: it may be an idea to bear in mind
temporary renaming of files: as C<File::Copy> says:

	"The newer version of File::Copy exports a move() function."

=cut

sub save { my ($self, $save_dir, $file_name) = (shift,shift,shift);
	print "Template::save requires a directory to in save as its second parameter, at least use '.'."
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

	open OUTPUT, ">$self->{ARTICLE_PATH}" or print "Template::save could not open $self->{ARTICLE_PATH} for writing." and die $!;
		print OUTPUT $self->{FULL_TEMPLATE};
	close OUTPUT;

	$self -> set_article_url;
	return $self->{ARTICLE_PATH};
}





=head2 &process

Fill a template or take variables from a template.

Accepts, in this order:

=over 4

=item 1.

reference to Template object;

=item 2.

method of operation: 'C<fill>' or 'C<collect>'.

=item 3.

if method argument above is set to 'C<fill>', a reference to a hash.

=back

If the second argument is set to 'C<collect>', the values of all C<TEMPLATEITEM>
elements will be collected into the instance variable C<%TEMPLATEITEMS>, with
the C<name> attribute of the element forms the key of the hash.

If the second argument is set to 'C<fill>', the template will be filled with values
stored in the hash refered to in the third argument.

The third parameter, if present, should refer to a hash whose keys
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
	print "Usage: \$self->process(\$method,\$ref_to_hash)" and die if defined $usrvals and ref $usrvals ne 'HASH';
	print "Useage: \$self->process(\$method,\$ref_to_hash)." and die if not defined $method;
	my %usrvals = %$usrvals;
	my $name = "";			# The 'name' attribute from TEMPLATEITEM elements, cf. $usrvals{$name}
	my $substitute = 0;		# Flag set when ignoring elements nested within a TEMPLATEITEM element
	my $p = HTML::TokeParser->new( $self->{SOURCEPATH} ) or print "Can't create TokeParser object!\n $!" and die;
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
			$self->{FULL_TEMPLATE}	.= @$token[1] if $method eq "fill";	# Replace the template tag
			$self->{HTMLTITLE}		.= @$token[1] if $method eq 'collect';
		}

		# Found the start of a template item?
		elsif ( (@$token[1] eq 'templateitem') and (@$token[0] eq 'S') and exists @$token[2]->{name}) {
			$substitute = 1;				# set flag for this loop to ignore elements
			$name = "";						# Reset this var incase the TEMPLATEITEM illegally misses it's req. attribute
			$name = @$token[2]->{name};		# Get the 'name' attribute in either case, into $name
			if ($method eq 'fill'){							# If completing a template:
				$self->{FULL_TEMPLATE} .= @$token[4];		# Replace the full template tag
				$self->{FULL_TEMPLATE} .= "\n$usrvals{$name}" if exists $usrvals{$name};	# Insert into template
			}
		}

		# End of a template time
		elsif ( (@$token[1] eq 'templateitem') and (@$token[0] eq 'E') ) {
			$self->{FULL_TEMPLATE} .= "</TEMPLATEITEM>" if $method eq "fill";	# Replace the template tag
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
		elsif ($substitute) {
			my $literal = "";
			if    (@$token[0] eq 'S') { $literal = @$token[4]; }
			elsif (@$token[0] eq 'E') { $literal = @$token[2]; }
			else                      { $literal = @$token[1]; }
			if ($method eq 'collect'){
				$self->{TEMPLATEITEMS}->{$name} .= $literal;# Store the template's element name and default value
			}
			elsif ($method eq 'fill'){
				$self->{FULL_TEMPLATE} .= $literal;
			}
		}

		# End if
	} # Whend
} # End sub fill





=head2 &set_article_path

Accepts and returns one scalar, the path to use for the object's C<ARTICLE_PATH> slot.

=cut

sub set_article_path { my ($self, $path) = (shift,shift);
	return $self->{ARTICLE_PATH} = $path;
}


=head2 &set_article_url

Acceptsand returns one scalar, C<ARTICLE_URL> slot.

=cut

sub set_article_url { my ($self, $path) = (shift,shift);
	if (not $path and $self->{ARTICLE_PATH}){
		$path = $self->{ARTICLE_PATH};
	}
	$path =~ /^($main::ARTICLE_ROOT)(.*)$/ if defined $main::ARTICLE_ROOT;
	if ($main::ARTICLE_ROOT){
		$self->{ARTICLE_URL} = $main::URL_ROOT.$2;
	} else {
		$self->{ARTICLE_URL} = $2;
	}
	return $self->{ARTICLE_URL};
}



1; # Return a true value for 'use'

=head1 AUTHOR

Lee Goddard (LGoddard@CPAN.org)

=head1 COPYRIGHT

Copyright 2000-2001 Lee Goddard.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

