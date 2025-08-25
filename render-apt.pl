#!/usr/bin/env perl

## render-apt.pl
## Renders Almost Plain Text (APT) files into HTML.
##
## Author: Nathan Campos <nathan@innoveworkshop.com>

use strict;
use warnings;
use autodie;
use Data::Dumper;

package Render::APT;

# Global variables.
our @html = ();
our %refs = ();
our @img_exts = qw(jpg jpeg png bmp svg gif tif tiff webp heic);

# Checks if a line contains code.
sub is_code {
	return $_[0] =~ m/^\s{4}/;
}

# Checks if a line contains a quote.
sub is_quote {
	return $_[0] =~ m/^>/;
}

# Checks if a line contains code or a quote.
sub is_indented {
	return $_[0] =~ m/^(?:>|\s{4})/;
}

# Checks if a line is a reference link definition.
sub is_refdef {
	return $_[0] =~ m/^\s*\[\d+\]:\s+/;
}

# Checks if a line contains a reference link.
sub has_reflink {
	return $_[0] =~ m/^(?!\[\d+\]:).+\[(\d+)\]/;
}

# Read the file.
sub read_file {
	my ($fname) = @_;

	# Slurp the file into the contents array.
	open(my $fh, '<:encoding(UTF-8)', $fname);
	@html = <$fh>;
	chomp @html;
	close($fh);
}

# Parse all reference link definitions.
sub parse_refdefs {
	foreach my $line (@html) {
		if ($line =~ m/^\s*\[(?<id>\d+)\]:\s+(?<href>.+)/) {
			$refs{$+{id}} = $+{href};
		}
	}
}

# Encode all HTML entities in the file.
sub encode_entities {
	for (my $i = 0; $i <= $#html; $i++) {
		$html[$i] =~ s/&/&amp;/g if is_indented($html[$i]);
		$html[$i] =~ s/</&lt;/g;
		$html[$i] =~ s/>/&gt;/g;
	}
}

# Make text inside asterisks bold.
sub bold_text {
	my $bolding = 0;
	my $render = sub {
		my ($l) = @_;

		# Substitute asterisks by <b> tags.
		if ($l =~ m/\*/) {
			if (!$bolding) {
				$l =~ s/\*/<b>&ast;/;
				$bolding = 1;
			} else {
				$l =~ s/\*/&ast;<\/b>/;
				$bolding = 0;
			}
		}

		return $l;
	};

	# Go through lines trying to make them bold.
	for (my $i = 0; $i <= $#html; $i++) {
		# Ignore code or quote blocks.
		next if is_indented($html[$i]);

		# Double asterisk should be rendered as a simple asterisk.
		$html[$i] =~ s/\*\*/&ast;/g;

		# Try to render bold text.
		while ($html[$i] =~ m/\*/) {
			$html[$i] = $render->($html[$i]);
		}
	}
}

# Make header lines.
sub make_headers {
	# Search for header lines.
	for (my $i = 0; $i <= $#html; $i++) {
		# Is this a line with only - or = characters? Same length and previous?
		if (($html[$i] =~ m/^([-=])[-=]+$/) &&
				(length($html[$i]) == length($html[$i - 1]))) {
			if ($1 eq '=') {
				# Header 1
				$html[$i - 1] = '<h1>' . $html[$i - 1];
				$html[$i] = $html[$i] . '</h1>';
			} else {
				# Header 2
				$html[$i - 1] = '<h2>' . $html[$i - 1];
				$html[$i] = $html[$i] . '</h2>';
			}
		}
	}
}

# Adds code blocks to indented text (4 spaces).
sub code_blocks {
	my $coding = 0;

	# Search for code blocks.
	for (my $i = 0; $i <= $#html; $i++) {
		# Is line indented for code?
		if (is_code($html[$i])) {
			# De-indent the line.
			$html[$i] = substr($html[$i], 4);

			# Add opening code tag if at the beginning.
			if (!$coding) {
				$html[$i] = '<code>' . $html[$i];
				$coding = 1;
			}

			next;
		}

		# Close code tag if we are no longer indented.
		if ($coding && !is_code($html[$i])) {
			$html[$i - 1] = $html[$i - 1] . '</code>';
			$coding = 0;
		}
	}
}

# Automatically adds links to bare URLs.
sub autolink {
	my $url_regex = qr/([\w\d]+:\/\/[^\/].+[^\s])/;

	# Substitution helper.
	my $href_replace = sub { '<a href="' . $_[0] . '">' . $_[0] . '</a>' };
	my $img_replace = sub { '<a href="' . $_[0] . '"><img src="' . $_[0] .
		'"></a>' };

	# Search for bare URLs to link to.
	for (my $i = 0; $i <= $#html; $i++) {
		# Ignore code or quote blocks.
		next if is_indented($html[$i]);

		# Embed images when possible.
		if (!is_refdef($html[$i])) {
			foreach my $ext (@img_exts) {
				if ($html[$i] =~ m/\.\Q$ext\E$/) {
					$html[$i] =~ s/$url_regex/$img_replace->($1)/ge;
					goto next_iter;
				}
			}
		}

		# Link up all bare URLs.
		$html[$i] =~ s/$url_regex/$href_replace->($1)/ge;
next_iter:
	}
}

# Adds links to references in the middle of the text.
sub ref_links {
	# Substitution helper.
	my $href_replace = sub { '<sup>[<a href="' . $refs{$_[0]} . '">' . $_[0] .
		'</a>]</sup>' };

	# Search for reference links.
	for (my $i = 0; $i <= $#html; $i++) {
		# Ignore code or quote blocks.
		next if is_indented($html[$i]);

		# Substitute all references in a line.
		while (has_reflink($html[$i])) {
			$html[$i] =~ s/\[(\d+)\]/$href_replace->($1)/e;
		}
	}
}

# Renders a file to our internal contents array.
sub render_file {
	my ($fname) = @_;

	# Perform all the operations in the correct order.
	read_file($fname);
	parse_refdefs();
	encode_entities();
	autolink();
	make_headers();
	bold_text();
	code_blocks();
	ref_links();

	return @html;
}

# Running as a script.
unless (caller) {
	# Render the file.
	render_file($ARGV[0]);

	# Print out the HTML document.
	print "<pre>";
	print "$_\n" for @html;
	print "</pre>\n";
}
