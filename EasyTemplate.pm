#! perl -w
#------------------------------------------------------------------------------	This line doesn't wrap (tab is always 4	---------------
package HTML::EasyTemplate;
use HTML::TokeParser;
use Cwd;
use strict;
use warnings;

=head1 NAME

EasyTemplate - simple tag-based HTML templates, guestbooks and 'latest news' pages.

=head2 VERSION

Version 0.97 11/05/2001 13:51

=cut

our $VERSION = 0.97;

=head1 SYNOPSIS

Example tempalte:

	<HTML><HEAD><TITLE>Test Doc</TITLE></HEAD>
	<BODY>
	<H1><TEMPLATEITEM id="articleTitle"></TEMPLATEITEM></H1>
	<TEMPLATEITEM id="articleText">
		This text <I>can</I> be over-writen - see the <EM>POD</EM>.
	</TEMPLATEITEM>
	</BODY>
	</HTML>

Example of filling a template with content:

	use EasyTemplate;
	my $TEMPLATE = new HTML::EasyTemplate($page) or die "Couldn't make template!";
	$TEMPLATE -> process('fill', {
		'menu'=>$m->{HTML},
	} );
	$TEMPLATE -> save( $page );
	warn "Saved the new document as <$TEMPLATE->{ARTICLE_PATH}>\n";
	__END__

Example of collecting from a template with content:

	use EasyTemplate;
	my $TEMPLATE = new EasyTemplate('test_template.html');
	$TEMPLATE -> process('collect');
	my %template_items = %{$TEMPLATE->{TEMPLATEITEMS}};
	foreach (keys %template_items){
		print "ID=$_\nCONTENT=$template_items{$_}\n\n";
	}
	print "Template doc's title was: $TEMPLATE->title\n";
	__END__

=head1 DEPENDENCIES

	Cwd;
	HTML::TokeParser;
	strict;
	warnings;

=head1 DESCRIPTION

This package impliments the manipulation of templates: loading, saving, filling, and so on.  It makes it easy to produce guestbooks, 'latest news' pages and simple websites.

A template is an HTML file (or other  file parsable by C<HTML::TokeParser>) that contains C<TEMPLATEITEM> elements with one attribute, C<name> or C<id>, used to identitfy and/or order editable regions in the template.

A template may also include C<TEMPLATEBLOCK> elements.  Any elements, including C<TEMPLATEITEM>s, within a C<TEMPLATEBLOCK> element  will be replicated either above or below the existing C<TEMPLATEBLOCK>, depending on the value of the element's C<valign> attribute, which may be either C<above> or C<below>.

=head1 TEMPLATE ELEMENT REFERENCE

	Element name    Attributes   Function
	------------------------------------------------------------------------------------------------
	TEMPLATE_ITEM                Editable region - all contents may be easily collected/replaced.
	                id           Unique identifier.
	                name         An alternative id.
	------------------------------------------------------------------------------------------------
	TEMPLATEBLOCK               All contents will be replicated before the original block is filled.
	                id           Unique identifier.
	                name         An alternative id.
                    valign       Maybe 'C<above>' or 'C<below>' to indicate
                                 where the repliacted block should appear
                                 in relation to the original.
	------------------------------------------------------------------------------------------------

=head1 PUBLIC METHODS

=head2 CONSTRUCTOR METHOD (new)

Besides a references to the new object's class, the constructor requires a scalar representing the path at which the source of the template is to be found, plus a hash or reference to a hash that contains paramters of name/value pairs as follows:

=over 4

=item C<ARTICLE_ROOT>

The directory in which the site is B<rooted>.

The C<ARTICLE_ROOT> is stripped from filepaths when creating HTML A href elements within your site, and is replaced with...

If this is not set by the user, it is sought in the C<main::> namespace.

=item C<URL_ROOT>

This parameter  is used as the BASE for created hyperlinks to files, instead of the filesystems actual ARTICLE_ROOT, above.

If this is not set by the user, it is sought in the C<main::> namespace.

=item C<NO_TAGS>

If this item evaluates to true, the template will not contain C<TEMPLATEITEM> tags when saved.  Defaults is to leave them in, so that the page may again function as an C<EasyTemplate>.

=item C<FULL_TEMPLATE>

This slot will contain the filled template once the C<process/fill> method has been called.  See also the C<save> method.

=item C<HTML_TITLE>

See the C<title> method below.

=back

=cut

sub new { my ($class, $filepath) = (shift,shift);
	# Lets HTML::TokeParser handle the input file/string checks:-
	warn "HTML::EasyTemplate::new called without a class ref?" and return undef unless defined $class;
	warn "Useage: new $class (\$path_to_template)" and return undef if not defined $filepath;
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

	# Set/overwrite public slots with user's values
	foreach (keys %args) {	$self->{uc $_} = $args{$_} }

	# Set these if not set by user
	$self->{ARTICLE_ROOT}	= $main::ARTICLE_ROOT if defined $main::ARTICLE_ROOT and not exists $self->{ARTICLE_ROOT};
	$self->{URL_ROOT}		= $main::URL_ROOT if defined $main::URL_ROOT and not exists $self->{URL_ROOT};

	return $self;
}



=head2 METHOD title

Sets C<$TEMPLATE->{HTML_TITLE}>, which is
the HTML title to be substituted in the template.

Accepts: scalar.
Returns: the value set.

=cut

sub title { $_[0]->{HTML_TITLE} = $_[1] }



=head2 METHOD save

Save the file to the supplied path, or in the supplied directory with a new name.

Accepts:

=over 4

=item *

directory in which to save article in, or full path to save article as;

=item *

optionally a filename to save as.

=back

If no filename is suppiled in either argument, one is created without significance.

Returns: file path of saved file.

This method incidently returns a reset C<$self>'s C<ARTICLE_PATH>;

DEVELOPMENT NOTE: it may be an idea to bear in mind temporary renaming of files: as C<File::Copy> says:

	"The newer version of File::Copy exports a move() function."

=cut

sub save { my ($self, $save_dir, $file_name) = (shift,shift,shift);
	warn "Method EasyTemplate::save requires at least a directory or filepath as a parameter."
		and return undef unless defined $save_dir;
	warn "Method EasyTemplate::save found nothing at <$save_dir>."
		and return undef unless -e $save_dir;
	warn "Method EasyTemplate::save received two file paths!"
		and return undef if defined $file_name and -f $save_dir;

	local *OUTPUT;

	if (defined $file_name eq "" and not -f $save_dir){
		$file_name = time.".html";
		$self->set_article_path($save_dir."/".$file_name);
	} elsif (-f $save_dir){
		$self->set_article_path($save_dir);
	} else {
		$self->set_article_path($save_dir.'/'.$file_name);
	}

	open OUTPUT, ">$self->{ARTICLE_PATH}" or warn "EasyTemplate::save could not open $self->{ARTICLE_PATH} for writing:\nperl said '$!'" and return undef;
		print OUTPUT $self->{FULL_TEMPLATE};
	close OUTPUT;

	if (defined $file_name){
		$self -> set_article_url( "$save_dir/$file_name")
	} else {
		$self -> set_article_url( "$save_dir")
	}
	return $self->{ARTICLE_PATH};
}





=head2 METHOD process

Fill a template or take variables from a template.

Uses C<HTML::TokeParser> to iterate through template,replacing all text tagged with C<TEMPLATEITEM id="x"> with the value of I<x> being the keys of the third argument. So if that parser module can't read it, neither can this module.

Accepts, in this order:

=over 4

=item 1.

method of operation: 'C<fill>' or 'C<collect>'.

=item 2.

if method argument above is set to 'C<fill>', a reference to a hash.

=back

If the first argument is set to 'C<collect>', the values of all C<TEMPLATEITEM> elements will be collected into the instance variable C<%TEMPLATEITEMS>, with the C<name> or C<id> attribute of the element forms the key of the hash.

If the first argument is set to 'C<fill>', the template will be filled with values stored in the hash refered to in the third argument.

The second parameter, if present, should refer to a hash whose keys are C<TEMPLATEITEM> element C<name> or C<id> attributes, and values are the element's contents.

Returns either C<$self->{FULL_TEMPLATE}> or C<$self->{TEMPLATEITEMS}>, depending on the calling parameter.

=cut

# On finding a template item; the 'name' or 'id'  attribute of this TEMPLATEITEM element
# acts as the value to the C<%usrvals> key.
# Ignore *everything* until the end of the element, replacing it with
# the contents of $usrvals{$name}, where $name is specified in TEMPLATEITEM name="x" or id="x".
# It may be worth checking for invalidly nested TEMPLATEITEM elements.

sub process { my ($self, $method, $usrvals) = (shift,shift,shift);
	warn "Template values not a hash reference!\n Usage: \$self->process(\$method,\$ref_to_hash)" and return undef if defined $usrvals and ref $usrvals ne 'HASH';
	warn "No 'method' supplied!\n Usage: \$self->process(\$method,\$ref_to_hash)." and return undef if not defined $method;
	my $p = HTML::TokeParser->new( $self->{SOURCE_PATH} ) or warn "Can't create TokeParser object!\n $!" and return undef;
	my %usrvals; %usrvals = %$usrvals if defined $usrvals;
	my ($tbname,$name) = "";	# The 'name' or 'id'  attributes from TEMPLATEITEM/TEMPLATEBLOCK elements, cf. $usrvals{$name}
	my $substitute = 0;		# Flag set when ignoring elements nested within a TEMPLATEITEM element
	my $tbopen;				# Flag
	my $htmltitle = 0;		# Flags when inside HTML TITLE element
	my $tbblock;			# Store of tokens in a TEMPLATEBLOCK element
	my $tbvalign;			# The veritcal alignment of TEMPLATEBLOCK - above|below.
	my %tbblocks;			# Store blocks for insertion in second parse

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
			} elsif ($method eq 'fill' and exists $usrvals{HTML_TITLE} and $usrvals{HTML_TITLE} ne '') {
				$self->{FULL_TEMPLATE} .= $usrvals{HTML_TITLE} 				# Substitute our text
					if $self->{FULL_TEMPLATE} !~ /$usrvals{HTML_TITLE}$/;	# if not already done so
			}
		}

		# A TEMPLATEBLOCK
		elsif (@$token[1] eq 'templateblock' and @$token[0] eq 'S' and $method eq 'fill'){
			$tbopen = 1;
			if (exists @$token[2]->{name}) { $tbname=@$token[2]->{name} }
			elsif (exists @$token[2]->{id}){ $tbname=@$token[2]->{id} }
			else  {$tbname++}

			if (exists @$token[2]->{valign}) {
				if (@$token[2]->{valign} !~ /^\s*(above|below)\s*$/i){
					warn "TEMPLATEBLOCK '$tbname' value '@$token[2]->{valign}' is illegal - defaulting to 'above'.\n";
					$tbvalign = "above";
				} else { $tbvalign = lc @$token[2]->{valign}; }
			} else {
				$tbvalign = "above";
				warn "TEMPLATEBLOCK '$tbname' has no 'valign' attribute - defaulting to 'above'.\n";
			}

			$self->{FULL_TEMPLATE} .= @$token[4];
			$tbblock = @$token[4];
		# End of a TEMPLATEBLOCK

		} elsif (@$token[1] eq 'templateblock' and @$token[0] eq 'E' and defined $tbblock){
			$tbblock .= @$token[2];
			$self->{FULL_TEMPLATE} .= @$token[2];
			$tbblocks{$tbname} = $tbblock,
			undef $tbblock;
			undef $tbopen;
			undef $tbvalign;
			# Dont' undef $tbname as it's used as a id in error msg later
		}

		# Found the start of a template item?
		elsif ( @$token[1] eq 'templateitem' and @$token[0] eq 'S'
			and (exists @$token[2]->{name} or exists @$token[2]->{id})
		) {
			$substitute = 1;								# set flag for this loop to ignore elements
			$name = "";										# Reset this var incase TEMPLATEITEM illegally misses req. attribute
			if (exists @$token[2]->{name}){$name=@$token[2]->{name} }else{ $name=@$token[2]->{id} }

			# If in a replicate block when completing a template
			if (defined $tbblock){ $tbblock .= @$token[4] }
			# If completing a template:
			if ($method eq 'fill'){
				$self->{FULL_TEMPLATE} .= @$token[4]		# Replace the full template tag
					if not exists $self->{NO_TAGS};			# if we're asked to
				# Add the content at this point
				$self->{FULL_TEMPLATE} .= "\n$usrvals{$name}" if exists $usrvals{$name};	# Insert into template
			}
		}

		# End of a template item
		elsif ( (@$token[1] eq 'templateitem') and (@$token[0] eq 'E') ) {
			$self->{FULL_TEMPLATE} .= "\n".@$token[2]		# Replace the template tag
				if $method eq "fill"
				and not exists $self->{NO_TAGS};			# if we're asked to
			$tbblock .= @$token[2];
			$substitute = 0;		# Reset flag for this loop to stop ignoring elements
			$name = '';
		}

		# Work over non-TEMPLATEITEM tokens - copy accross to FULL_TEMPLATE isntance variable
		elsif ($method eq 'fill' and not $substitute) {		# Add the original element
			my $literal="";
			if    (@$token[0] eq 'S') { $literal = @$token[4]; }
			elsif (@$token[0] eq 'E') { $literal = @$token[2]; }
			else                      { $literal = @$token[1]; }
			if (defined $tbblock){
				$tbblock .= $literal;	# Complete the template
			}
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
		}# End if
	} # Whend

	die "TEMPLATEITEM '$name' not closed!" if defined $name and $name ne '';
	die "TEMPLATEBLOCK '$tbname' not closed!" if defined $tbopen;

	# Second parse, this time of the FULL_TEMPLATE created above,  to insert TEMPLATEBLOCKs %tbblocks
	if ($method eq 'fill'){
		my $tempdoc		= "";
		my $tbname		= "";
		my $tbvalign	= "";

		$p = HTML::TokeParser->new( \$self->{FULL_TEMPLATE} )
			or warn "Can't create TokeParser object on second parse!\n $!" and return undef;

		# Cycle through all tokens in the HTML template file
		while (my $token = $p->get_token) {

			# Start of a templateblock: get attributes from the doc as above (make a sub of this repeated code?)
			if (@$token[1] eq 'templateblock' and @$token[0] eq 'S' and $method eq 'fill'){
				if (exists @$token[2]->{name}) { $tbname=@$token[2]->{name} }
				elsif (exists @$token[2]->{id}){ $tbname=@$token[2]->{id} }
				else  {$tbname++}
				if (exists @$token[2]->{valign}) {
					if (@$token[2]->{valign} !~ /^\s*(above|below)\s*$/i){
						$tbvalign = "above";
					} else { $tbvalign = lc @$token[2]->{valign}; }
				} else {
					$tbvalign = "above";
				}
				if ($tbvalign eq 'above'){ $tempdoc .= $tbblocks{ $tbname } }
			}

			my $literal="";
			if    (@$token[0] eq 'S') { $literal = @$token[4]; }
			elsif (@$token[0] eq 'E') { $literal = @$token[2]; }
			else                      { $literal = @$token[1]; }
			$tempdoc .= $literal;	# Complete the template

			# The end of a TEMPLATEBLOCK
			if (@$token[1] eq 'templateblock' and @$token[0] eq 'E' and $tbvalign ne 'above'){
				$tempdoc .= $tbblocks{ $tbname };
			}

		} # Whend

		$self->{FULL_TEMPLATE} = $tempdoc;

	} # End if fill

	$method eq 'fill' ? return $self->{FULL_TEMPLATE} : return $self->{TEMPLATEITEMS};
} # End sub fill





=head2 METHOD set_article_path

Accepts and returns one scalar, the path to use for the object's C<ARTICLE_PATH> slot.

=cut

sub set_article_path { $_[0]->{ARTICLE_PATH} = $_[1] }



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
	if (not defined $path and exists $self->{ARTICLE_PATH}){
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

=head1 SEE ALSO

	HTML::TokeParser
	HTML::EasyTemplate::DirMenu
	HTML::EasyTemplate::PageMenu

=head1 HISTORY

=item 0.96

Removed our checks on input file/string to allow HTML::TokeParser to sort it out;
reversed wrong C<NO_TAGS> behaviour; removed some limiting defaults.

=item 0.95

Allow use of C<id> in addition to C<name> as the C>TEMPLATEITEM> unique identifier attribute.

=head1 AUTHOR

Lee Goddard (LGoddard@CPAN.org)

=head1 COPYRIGHT

Copyright 2000-2001 Lee Goddard.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

