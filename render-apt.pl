#!/usr/bin/env perl

## render-apt.pl
## Renders Almost Plain Text (APT) files into multiple formats.
##
## Author: Nathan Campos <nathan@innoveworkshop.com>

use strict;
use warnings;
use autodie;
use Data::Dumper;

# Contents in multiple formats.
our @orig = ();
our @html = ();
our @plain = ();

# Read the file.
sub read_file {
	my ($fname) = @_;

	# Slurp the file into the original array.
	open(my $fh, '<:encoding(UTF-8)', $fname);
	@orig = <$fh>;
	chomp @orig;
	close($fh);

	# Copy the contents of the file into the HTML and plain text arrays.
	@html = @orig;
	@plain = @orig;
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
		next if ($html[$i] =~ m/^[\s>]/);

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

# Perform all the operations in the correct order.
read_file($ARGV[0]);
bold_text();

print "<pre>\n";
foreach my $line (@html) {
	print "$line\n";
}
print "</pre>\n";
