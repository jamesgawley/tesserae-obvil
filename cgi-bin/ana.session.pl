#!/usr/bin/env perl

use strict;
use warnings;

#
# Read configuration file
#

# modules necessary to read config file

use Cwd qw/abs_path/;
use File::Spec::Functions;
use FindBin qw/$Bin/;

# read config before executing anything else

my $lib;

BEGIN {

	# look for configuration file
	
	$lib = $Bin;
	
	my $oldlib = $lib;
	
	my $pointer;
			
	while (1) {

		$pointer = catfile($lib, '.tesserae.conf');
	
		if (-r $pointer) {
		
			open (FH, $pointer) or die "can't open $pointer: $!";
			
			$lib = <FH>;
			
			chomp $lib;
			
			last;
		}
									
		$lib = abs_path(catdir($lib, '..'));
		
		if (-d $lib and $lib ne $oldlib) {
		
			$oldlib = $lib;			
			
			next;
		}
		
		die "can't find .tesserae.conf!\n";
	}	
	
	$lib = catdir($lib, 'TessPerl');
}

# load Tesserae-specific modules

use lib $lib;
use Tesserae;
use EasyProgressBar;

# modules to read cmd-line options and print usage

use Getopt::Long;
use Pod::Usage;

# load additional modules necessary for this script

use Storable qw(nstore retrieve);
use CGI qw/:standard/;

print "Content-type: text/html\n\n";

#
# cgi input
#

my $query = new CGI || die "$!";

my $text 		= $query->param('text');
my $selected 	= $query->param('word');

my $file_in =  catfile($fs{data}, 'ana', $text);

my @locus 	= @{retrieve("$file_in.locus")}	;
my @word 	= @{retrieve("$file_in.word")}	;
my @space 	= @{retrieve("$file_in.space")}	;
my %index	= %{retrieve("$file_in.index")}	;
my %anagram	= %{retrieve("$file_in.ana")}		;


my @ana_keys = grep { length($_) > 3 && $#{$anagram{$_}} > 0} keys %anagram;

if (defined($selected) && ($selected ne ""))
{
	$selected = join("", sort( split( //, $selected)));

	#
	# highlight selected anagram
	#
	
	for my $word (@{$anagram{$selected}})
	{
		for my $loc (@{$index{$word}})
		{
			my ($l,$w) = split(/\./, $loc);

			${$word[$l]}[$w] = "<span class=\"selected\">${$word[$l]}[$w]</span>";
		}
	}
}



for my $ana (@ana_keys)
{
	for my $word (@{$anagram{$ana}})
	{
		for my $loc (@{$index{$word}})
		{
			my ($l,$w) = split(/\./, $loc);

			${$word[$l]}[$w] = "<a href=\"$url{cgi}/ana.session.pl?word=$ana\">${$word[$l]}[$w]</a>";
		}
	}
}



print <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" 
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<title>$text</title>
		
		<style type="text/css">
			div.index
			{
				font-size: .8em;
				width:15%;
				float:right;
				border:1px solid black;
			}
			div.index table
			{
				float:left;
			}
			div.index a
			{
				text-decoration: none;
				color: blue;
			}
			div.header
			{
				margin.bottom: 2em;
			}
			div.header h1
			{
				font-size: 1em;
				font-weight: bold;
			}
			div.main a
			{
				text-decoration: none;
				color: grey;
			}
			div.l	
			{
				height: 1.3em;
			}
			span.text
			{
				position:	absolute;
				left: 20%;
			}
			span.selected
			{
				color: red;
			}
		</style>
	</head>
	
	<body>
		<div class="header">
			<h1>$text</h1>
		</div>
END

#
# guide to locations
#

if ($selected ne "")
{
	print '		<div class="index">' . "\n";
	
	for my $word (@{$anagram{$selected}})
	{
		print "<table><tr><th>$word</th></tr>\n";
		
		for my $loc (@{$index{$word}})
		{
			my ($l,$w) = split(/\./, $loc);

			print "<tr><td><a href=\"#$locus[$l]\">$locus[$l]</a></td></tr>\n";
		}
		print "</table>\n\n";
	}
	
	print "		</div>\n";
}



	
#
# poem text
#

print '		<div class="main">' . "\n";
	
	
for my $l (0..$#word)
{
	print "			<div class=\"l\"><span class=\"loc\"><a name=\"$locus[$l]\">$locus[$l]</a></span><span class=\"text\">";

	for my $w (0..$#{$word[$l]})
	{
		print ${$space[$l]}[$w];
		print ${$word[$l]}[$w];
	}

	print "</span></div>\n";
}
	
print <<END;
		</div>
	</body>
</html>
END
