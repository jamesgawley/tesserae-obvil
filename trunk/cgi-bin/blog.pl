#!/usr/bin/perl

#
# this script grabs content from the DHIB blogs
# and puts it into a Tesserae page
#

use strict;
use warnings;

use lib '/Users/chris/Sites/tesserae/perl';	# PERL_PATH
use TessSystemVars;

use LWP::Simple;

#
# print header
#

print "Content-type: text/html\n\n";

#
# download and parse the RSS feed
#

# the rss feed for the DHIB blogs

my $url = 'http://dhib.drupalgardens.com/blogs/feed';

# download the rss as xml

my $xml = get($url);

# extract the entries we want,
# and convert to html

my @item = parse($xml);

#
# print the page
#

# process the php template

my $html = `php -f $fs_html/blog.php`;

# add the blog entries

my $blogs;

for my $item (@item) {

	my $text = brief($$item{CONTENT});
	
	$blogs .= "<div class=\"blog\">\n$text<p><a href=\"$$item{LINK}\">read more...</a></p></div>\n\n";
}

$html =~ s/<!--BLOGS GO HERE-->/$blogs/;

print $html;

#
# parse the xml feed,
# extract <item>s,
# turn them into html and save them in an array
#

sub parse {
	
	my $xml = shift;

	# split into lines

	my @line = split("\n", $xml);

	# this will hold one <item> at a time

	my $item;

	# this will hold all the items

	my @item;

	# go through line by line, looking for <item> and </item>

	my $isitem = 0;

	for (@line) {
		
		# we assume that the begin/end tags are on their own lines
		# this seems to be true with the blogs generated by drupalgardens
	 
		# if we see the open tag, then turn on the flag
	
		if (/<item>/) { $isitem = 1 }
		
		# if the flag is set, every line is collected
	
		if ($isitem)  { $item .= $_ . "\n" }
		
		# when we see the close tag, turn the flag off,
		# and parse all the lines we've collected.
		# then reset the saved string to null
	
		if (/<\/item>/) {
		
			# set the flag

			$isitem = 0;
					
			# parse
			
			my %item = %{parseitem($item)};

			if (defined $item{AUTHOR} and ($item{AUTHOR} eq "Chris Forstall" || $item{AUTHOR} eq "Neil Coffee")) {
		
				push @item, \%item;
			}
	
			# reset
		
			$item = "";
		}
	}
	
	return @item;
}

#
# parse the xml of a single <item>
#

sub parseitem {

	my $s = shift;
	
	$s =~ /<dc:creator>(.+)<\/dc:creator>/s;
	
	my $author = $1;
		
	$s =~ /<title>(.+)<\/title>/s;
	
	my $title = $1 || "";
	
	$s =~ /<link>(.+)<\/link>/s;
	
	my $link = $1 || "";
	
	$s =~ /<pubDate>(.+) \d{2}:\d{2}:\d{2} .\d{4}<\/pubDate>/;
	
	my $date = $1 || "";
	
	# get rid of everything but the contents of <description>
	
	$s =~ s/.*<description>//s;
	$s =~ s/<\/description>.*//s;
	
	# change named entities back to chars
	
	$s =~ s/&gt;/>/g;
	$s =~ s/&lt;/</g;
	$s =~ s/&quot;/"/g;
	$s =~ s/&#(\d+);/chr($1)/eg;
	
	$s = <<END;
	
<h1>$title</h1>
<h2>$author</h2>
<h3>$date</h3>
	
	$s
	
END
	
   return {AUTHOR=>$author, LINK=>$link, DATE=>$date, CONTENT=>$s};
}

sub brief {

   my $text = shift;

	$text =~ /^(.{200}.+?\n\n)/s;
	
	my $brief = $1;
	
	# count the number of open <div> tags
	
	my @open = ($brief =~ /<div\b/g);
	
	# count the number of close tags
	
	my @close = ($brief =~ /<\/div>/);
	
	if ($#open > $#close) {
	
		$brief .= "</div>" x ($#open - $#close);
	}
	
	return $brief;
}
