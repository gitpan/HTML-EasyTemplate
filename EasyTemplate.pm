#! perl -w
#------------------------------------------------------------------------------	This line doesn't wrap (tab is always 4	---------------

package HTML::EasyTemplate;
use HTML::TokeParser 2.19;
use strict;
use Fcntl ':flock'; # import LOCK_* constants
use warnings;

# use Data::Dumper;

=head1 NAME

HTML::EasyTemplate - tag-based HTML templates

=cut

our $VERSION = 0.986;	# Changed save method

=head2 VERSION

Version 0.986 (26/07/2001) Flocks and unflocks files.
	If your version of perl does't support C<flock>, you must not
	call the constructor with a C<FLOCK>  argument.
Version 0.985 (23/07/2001) cleans up API: constructor method
	 now takes SOURCE_PATH explicitly and not as arg outside of hash.
Version 0.984 (15/06/2001) adds option to hide template items.

=cut



=head1 SYNOPSIS

Example tempalte:

	<HTML><HEAD><TITLE>Latest News</TITLE></HEAD><BODY>
	<H1>Latest News</H1>
	<!--<TEMPLATEBLOCK valign="above">
		<H2><TEMPLATEITEM id="1.Headline">This is in a non-displayed template</TEMPLATEITEM></H2>
		<DIV><TEMPLATEITEM id="2.Story">This will not be shown, within templateitem tags, will be destroyed</TEMPLATEITEM></DIV>
	</TEMPLATEBLOCK>-->
	</BODY></HTML>


Example of filling and collecting:

	use HTML::EasyTemplate;

	my $TEMPLATE = new HTML::EasyTemplate(
		{	SOURCE_PATH => "test_template.html",
			NO_TAGS => 1,
			ARTICLE_ROOT => 'E:/www/leegoddard_com',
			URL_ROOT => 'http://localhost/leegoddard_com',
		});

	# Collect the values
	$TEMPLATE -> process('collect');

	# Do something with them
	my %template_items = %{$TEMPLATE->{TEMPLATEITEMS}};

	warn "** Template content was:\n";
	foreach (keys %template_items){ warn "ID=$_\nCONTENT=$template_items{$_}\n\n" }
	warn "** Template doc's title was: ",$TEMPLATE->title,"\n\n";

	# Make new values, for example:
	$template_items{'1.Headline'} 	= "News in paper";
	$template_items{'2.Story'}	= "Reports are coming in on ". scalar(localtime)." of a newspaper carrying a news item.";

	warn "\n** New template contents will be:\n";
	foreach (keys %template_items) {
		warn "$_ -> $template_items{$_}\n";
	}

	# Add them to the page
	$TEMPLATE -> process('fill', \%template_items );
	$TEMPLATE -> save;
	warn "\n** Document saved as (",$TEMPLATE->{ARTICLE_PATH},")\n";

	exit;

See also the I<EXAMPLE: NEWS PAGE / GUESTBOOK>, below.

=head1 DEPENDENCIES

	HTML::TokeParser;
	Fcntl;
	strict;
	warnings;

=head1 DESCRIPTION

This package impliments the most easy possible  manipulation of templates: loading, saving, filling, and so on.  It makes it easy to produce guestbooks, 'latest news' pages and simple websites.

A template is an area of an HTML page that this module can fill with data.

A template is a <!--commented out--> area of an HTML file (or other  file parsable by C<HTML::TokeParser>) that contains C<TEMPLATEBLOCK> elements with C<TEMPLATEITEM> elements within. Any elements, including C<TEMPLATEITEM>s, within a C<TEMPLATEBLOCK> element  will be replicated either above or below the existing C<TEMPLATEBLOCK>, depending on the value of the element's C<valign> attribute, which may be either C<above> or C<below>.

See the enclosed examples for further information.

=head1 TEMPLATE ELEMENT REFERENCE

	Element name    Attributes   Function
	------------------------------------------------------------------------------------------------
	TEMPLATE_ITEM                Editable region - all contents may be easily collected/replaced.
	                id           Unique identifier.
	                name         Synonymn for id.
	------------------------------------------------------------------------------------------------
	TEMPLATEBLOCK                All contents will be replicated before the original block is filled.
	                id           Unique identifier.
	                name         Synonymn for id.
                    valign       Either 'C<above>' or 'C<below>' to indicate where the repliacted
                                 block should appear in relation to the original.
	------------------------------------------------------------------------------------------------

=head1 PUBLIC METHODS

=head2 CONSTRUCTOR METHOD (new)

Besides a references to the new object's class, the constructor requires
a hash or reference to a hash that contains paramters of name/value pairs as follows:

=over 4

=item C<SOURCE_PATH>

Scalar representing the path at which the source of the template is to be found,

=item C<FLOCK>

If set, will do a C<FLOCK LOCK_EX> on any read file, and only C<FLOCK LOCK_UN> when it is saved.
If your system cannot handle C<flock>, do not use this setting.

=item C<ARTICLE_ROOT>

The directory in which the site is B<rooted>.

The C<ARTICLE_ROOT> is stripped from filepaths when creating HTML A href elements within your site, and is replaced with...

If this is not set by the user, it is sought in the C<main::> namespace.

=item C<URL_ROOT>

This parameter  is used as the BASE for created hyperlinks to files, instead of the filesystems actual ARTICLE_ROOT, above.

If this is not set by the user, it is sought in the C<main::> namespace.

=item C<NO_TAGS>

This is really a legacy attribute.  Defaulting to true, if the user sets it to evaluate to false, new template items will be surrounded by the C<TEMPLATEITEM> and C<TEMPLATEBLOCK> elements when saved. See also the next item.

=item C<ADD_TAGS>

If present, will surround output with respective C<TEMPLATEITEM> and C<TEMPLATEBLOCK> elements.  See also previous item.

=item C<HTML_TITLE>

Contains the HTML C<TITLE> element for reading/setting - see the C<title> method below.

=item C<FULL_TEMPLATE>

This slot will contain the filled template once the C<process/fill> method has been called.  See also the C<save> method.

=back

=cut

sub new { my ($class) = (shift);
	# Lets HTML::TokeParser handle the input file/string checks:-
	warn "HTML::EasyTemplate::new called without a class ref?" and return undef unless defined $class;
	my %args;
	my $self = {};
	bless $self,$class;

	# Take parameters and place in object slots/set as instance variables
	if (ref $_[0] eq 'HASH'){	%args = %{$_[0]} }
	elsif (not ref $_[0]){		%args = @_ }

	# Instance variables
	$self->{ARTICLE_PATH}	= '';			# Path to the article created from the template instance
	$self->{ARTICLE_URL}	= '';			# URL  of the article created from the template instance
	$self->{FULL_TEMPLATE}	= '';			# Contents of template once replacements have been made
	$self->{TEMPLATEITEMS}	= {};			# Hash of template-item names and contents;
	$self->{NO_TAGS}		= 1;			# Do not surround new content with TEMPLATE.* tags

	# Set/overwrite public slots with user's values
	foreach (keys %args) {	$self->{uc $_} = $args{$_} }

	delete $self->{NO_TAGS} if exists $self->{ADD_TAGS};

	# Set these if not set by user
	$self->{ARTICLE_ROOT}	= $main::ARTICLE_ROOT if defined $main::ARTICLE_ROOT and not exists $self->{ARTICLE_ROOT};
	$self->{URL_ROOT}		= $main::URL_ROOT if defined $main::URL_ROOT and not exists $self->{URL_ROOT};

	die "No filepath for template"
		if not exists  $self->{SOURCE_PATH}
		or not defined $self->{SOURCE_PATH};

	return $self;
}



=head2 METHOD title

Sets and/or returns C<$TEMPLATE->{HTML_TITLE}>, which is the HTML title to be substituted and/or found in the template.

=cut

sub title { defined $_[1] ? return $_[0]->{HTML_TITLE} = $_[1] : return $_[0]->{HTML_TITLE} }



=head2 METHOD save

Save the file to the supplied path, or in the supplied directory with a new name.

You may supply:

=over 4

=item *

just the full path to a file

=item *

both a directory and a filename

=item *

just a directory, with the filename being composed by the routine out of the time and an C<.html> extension.

=item *

supply no arguments, and the documents original source path is used - ie. the source document is updated (cf. C<$self->{SOURCE_PATH}>.

=back

Returns the path to the saved file, incidently a reset C<$self>'s C<ARTICLE_PATH>;

DEVELOPMENT NOTE: it may be an idea to bear in mind temporary renaming of files: as C<File::Copy> says:

	"The newer version of File::Copy exports a move() function."

=cut

sub save { my ($self, $save_dir, $file_name) = (shift,shift,shift);
	warn "Method HTML::EasyTemplate::save requires at least a directory or filepath as a parameter."
		and return undef unless defined $save_dir or defined $self->{SOURCE_PATH};
	local *OUTPUT;

	if (-d $save_dir and not defined $file_name ){
		$file_name = time.".html";
		$self->set_article_path($save_dir."/".$file_name);
	} elsif (-d $save_dir and defined $file_name) {
		$self->set_article_path($save_dir.'/'.$file_name);
	} else {
		$self->set_article_path($save_dir);
	}

	open OUTPUT, ">$self->{ARTICLE_PATH}" or warn "HTML::EasyTemplate::save could not open $self->{ARTICLE_PATH} for writing:\nperl said '$!'" and return undef;
		print OUTPUT $self->{FULL_TEMPLATE};
	close OUTPUT;
	file_unlock(*OUTPUT) if exists $self->{FLOCK};

	$self -> set_article_url;
	return $self->{ARTICLE_PATH};
}





=head2 METHOD process

Fill a template or take variables from a template.

Uses C<HTML::TokeParser> to iterate through template,replacing all text tagged with C<TEMPLATEITEM id="x"> with the value of I<x> being the keys of the third argument. So if that parser module can't read it, neither can this module.

Accepts:

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
	my ($tbname,$name) = "";# The 'name' or 'id'  attributes from TEMPLATEITEM/TEMPLATEBLOCK elements, cf. $usrvals{$name}
	my $substitute = 0;		# Flag set when ignoring elements nested within a TEMPLATEITEM element
	my $tbopen;				# Flag
	my $htmltitle = 0;		# Flags when inside HTML TITLE element
	my $tbblock;			# Store of tokens in a TEMPLATEBLOCK element
	my $tbvalign;			# The veritcal alignment of TEMPLATEBLOCK - above|below.
	my %tbblocks;			# Store blocks for insertion in second parse
	my %usrvals; %usrvals = %$usrvals if defined $usrvals;
	if (not open HTML,$self->{SOURCE_PATH} ){
		warn "Couldn't open file <$self->{SOURCE_PATH}> to create TokeParser object\n$!";
		return undef;
	} else {
		file_lock(*HTML) if exists $self->{FLOCK};
		read HTML, $_, -s HTML;
		close HTML;
	}

	# Remove commented out elements
	s/\Q<!--\E\s*<TEMPLATE\E/<TEMPLATE/sig;
	s/<\s*\/\s*TEMPLATE(ITEM|BLOCK)\s*>\s*-->/<\/TEMPLATE$1>/sig;

	my $p = HTML::TokeParser->new( \$_ ) or warn "Can't create TokeParser object from string\n $!" and return undef;

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
		elsif ( $htmltitle>0 and @$token[0] eq 'T' ){
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

		# A TEMPLATEBLOCK to fill
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

		# End of a TEMPLATEBLOCK to fill
		} elsif (@$token[1] eq 'templateblock' and @$token[0] eq 'E' and defined $tbblock and $method eq 'fill'){
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
			# Allow name or id attributes
			if (exists @$token[2]->{name}){$name=@$token[2]->{name} }else{ $name=@$token[2]->{id} }
			# If in a replicate block when completing a template
			if (defined $tbblock){ $tbblock .= @$token[4] }
			# If completing a template:
			if ($method eq 'fill'){
				$self->{FULL_TEMPLATE} .= @$token[4]		# Replace the full template tag
					if not exists $self->{NO_TAGS};			# if we're asked to
				# Add the content at this point
				$self->{FULL_TEMPLATE} .= "$usrvals{$name}" if exists $usrvals{$name};	# Insert into template
			}
		}

		# End of a template item
		elsif ( (@$token[1] eq 'templateitem') and (@$token[0] eq 'E') ) {
			$self->{FULL_TEMPLATE} .= @$token[2]			# Replace the template tag
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
			elsif (@$token[0] eq 'D') { $literal = @$token[1]; }
			elsif (@$token[0] eq 'PI'){ $literal = '<?'.@$token[1].'>'; }
			elsif (@$token[0] eq 'C') { $literal = @$token[1]; }
			else                      { $literal = @$token[1];}
			if (defined $tbblock){
				$tbblock .= $literal;	# Complete the template
			}
			$self->{FULL_TEMPLATE} .= $literal;	# Complete the template
		}

		# Substitution of TEMEPLATEITEM contents or not
		elsif ($method eq 'collect' and $substitute){
		# Remember filling of templateitem node is done on encountering opening of tempalteitem element, above
			my $literal = "";
			if    (@$token[0] eq 'S') { $literal = @$token[4] }
			elsif (@$token[0] eq 'E') { $literal = @$token[2] }
			elsif (@$token[0] eq 'D') { $literal = @$token[1] 	}
			elsif (@$token[0] eq 'PI'){ $literal = '<?'.@$token[1].'>' 	}
			elsif (@$token[0] eq 'C') { $literal = @$token[1]	}
			else  { 					$literal = @$token[1] }
			$self->{TEMPLATEITEMS}->{$name} .= $literal;# Store the template's element name and default value
		}# End if
	} # Whend

	warn  "Fatal error in template: TEMPLATEITEM '$name' not closed " and return undef if defined $name and $name ne '';
	warn "Fatal error in template: TEMPLATEBLOCK '$tbname' not closed " and return undef if defined $tbopen;

	# Second parse, this time of the FULL_TEMPLATE created above,  to insert TEMPLATEBLOCKs %tbblocks
	if ($method eq 'fill'){
		my ($tempdoc,$tbname,$tbvalign) = ('','','');

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
					if (@$token[2]->{valign} !~ /^\s*(top|bottom|above|below)\s*$/i){
						$tbvalign = "above";
					} else {
						$tbvalign = lc @$token[2]->{valign};
						$tbvalign = "below" if $tbvalign eq 'bottom';
						$tbvalign = "above" if $tbvalign eq 'top';
					}
				} else { $tbvalign = "above" }
				# Add content ABOVE
				$tempdoc .= '<!--'.$tbblocks{$tbname}.'-->'  if $tbvalign eq 'above';
			}

			my $literal="";
			if    (@$token[0] eq 'S') { $literal = @$token[4]; }
			elsif (@$token[0] eq 'E') { $literal = @$token[2]; }
			elsif (@$token[0] eq 'D') { $literal = @$token[1]; }
			elsif (@$token[0] eq 'PI'){ $literal = '<?'.@$token[1].'>'; }
			elsif (@$token[0] eq 'C') { $literal = @$token[1]; }
			else  {$literal = @$token[1]}


			# Complete the template
			$tempdoc .= $literal if not (@$token[1] =~ /^template(item|block)$/ and exists $self->{NO_TAGS});

			# The end of a TEMPLATEBLOCK

			# Add content BELOW
			if (@$token[1] eq 'templateblock' and @$token[0] eq 'E' and defined $tbvalign and $tbvalign ne 'above'){
				$tempdoc .= '<!--'.$tbblocks{$tbname}.'-->';
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




#
# file_lock: accepts glob ref
#
sub file_lock { my $glob = shift;
	if (!ref($glob) && ref(\$glob) ne "GLOB") {
		die "file_lock requires a glob";
	}
	no strict 'subs';
	flock $glob,LOCK_EX;
	use strict;
}

sub file_unlock { my $glob = shift;
	if (!ref($glob) && ref(\$glob) ne "GLOB") {
		die "file_unlock requires a glob";
	}
	no strict 'subs';
	flock $glob,LOCK_UN;
	use strict;
}


1; # Return a true value for 'use'

=head1 EXAMPLE: NEWS PAGE / GUESTBOOK

Three files can be used to produce a guestbook-like news page.  One file is an HTML file that takes form input, which is fed to a script that calls this module, that updates a further HTML page.  The form field C<name>s in the HTML form page are the same as the C<TEMPLATEITEM id>s in the updated/template page.

=item File One,

the viewable template, known as F<E:/www/leegoddard_com/latest.html> in the second file:

	<HTML><HEAD><TITLE>Latest News</TITLE></HEAD><BODY>
	<H1>Latest News</H1>
	<TEMPLATEBLOCK valign="above">
		<H2><TEMPLATEITEM id="1.Headline"></TEMPLATEITEM></H2>
		<DIV><TEMPLATEITEM id="2.Story"></TEMPLATEITEM></DIV>
	</TEMPLATEBLOCK>
	</BODY></HTML>

=item File Two,

perl script to do the business, in the first file called as F<http://localhost/cgi-bin/latestnews.pl>:

	use HTML::EasyTemplate;
	use CGI;
	$QUERY = new CGI;
	$TEMPLATE = new HTML::EasyTemplate("E:/www/leegoddard_com/latest.html",
		{	NO_TAGS => 1,
			ARTICLE_ROOT => 'E:/www/leegoddard_com',
			URL_ROOT => 'http://localhost/leegoddard_com',
		});
	if ($QUERY->param){
		foreach ($QUERY->param) {
			$template_items{$_} = join(', ',($QUERY->param($_)));
		}
		# Add them to the page
		$TEMPLATE -> process('fill', \%template_items );
		$TEMPLATE -> save( "$TEMPLATE->{ARTICLE_ROOT}/latest.html" );
	}
	print "Location:$TEMPLATE->{ARTICLE_URL}\n\n";
	exit;
	__END__

=item File Three,

the HTML form to add news items to the template; never referenced by other files:

	<HTML><HEAD><TITLE>Add a headline</TITLE></HEAD><BODY>
	<H1>Add a headline<HR></H1>
	<FORM action="http://localhost/cgi-bin/latestnews.pl" method="post">
		<H2>Headline</H2><INPUT type='text' name="1.Headline" size='60'></H2>
		<H3>Story</H3><TEXTAREA name="2.Story" COLS="40"  ROWS="5"  WRAP="HARD" size='60'></TEXTAREA>
		<HR><INPUT type="submit">
	</FORM></BODY></HTML>


=head1 SEE ALSO

	HTML::TokeParser
	HTML::EasyTemplate::DirMenu
	HTML::EasyTemplate::PageMenu

=head1 KEYWORDS

	Template, guestbook, news page, CGI, HTML, update, easy.

=head1 AUTHOR

Lee Goddard (LGoddard@CPAN.org)

=head1 COPYRIGHT

Copyright 2000-2001 Lee Goddard.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

