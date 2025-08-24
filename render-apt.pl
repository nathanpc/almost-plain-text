#!/usr/bin/env perl

## render-apt.pl
## Renders Almost Plain Text (APT) files into HTML.
##
## Author: Nathan Campos <nathan@innoveworkshop.com>

use strict;
use warnings;
use autodie;
use Data::Dumper;

# Global variables.
our @html = ();
our %refs = ();

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

# Make text inside asterisks bold.
sub bold_text {
	my $bolding = 0;
	my $render = sub {
		my ($l) = @_;

		# Substitute asterisks by <b> tags.
		if ($l =~ m/\*/) {
			if (!$bolding) {
				$l =~ s/\*/<b>/;
				$bolding = 1;
			} else {
				$l =~ s/\*/<\/b>/;
				$bolding = 0;
			}

			return $l;
		}

		return 0;
	};

	# Go through lines trying to make them bold.
	for (my $i = 0; $i <= $#html; $i++) {
		# Ignore code or quote blocks.
		next if is_indented($html[$i]);

		# Try to render bold text.
		my $bold = $render->($html[$i]);
		if ($bold) {
			$html[$i] = $bold;

			# Do a second pass to ensure bold doesn't end on the same line.
			$bold = $render->($bold);
			if ($bold) {
				$html[$i] = $bold;
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
	# Substitution helper.
	my $href_replace = sub { '<a href="' . $_[0] . '">' . $_[0] . '</a>' };

	# Search for bare URLs to link to.
	for (my $i = 0; $i <= $#html; $i++) {
		# Ignore code or quote blocks.
		next if is_indented($html[$i]);

		# Link up all bare URLs.
		$html[$i] =~ s/([\w\d]+:\/\/[^\/].+[^\s])/$href_replace->($1)/ge;
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

# Perform all the operations in the correct order.
read_file($ARGV[0]);
parse_refdefs();
autolink();
bold_text();
code_blocks();
ref_links();

# Print out the HTML document.
print "<pre>";
print "$_\n" for @html;
print "</pre>\n";
