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

use utf8;
use File::Path qw(mkpath rmtree);
use File::Basename;
use File::Copy;
use Storable qw(nstore retrieve);
use Encode;
use Tesserae;

# get the files and the language
my @files = @ARGV;
my $lang = "fr";

# grab the titles of the poems for this language
my $title_file = catfile($fs{data}, 'common', "$lang.titles.txt");
open my $fh, "<:utf8", $title_file or die $!;


my %titles;

while (<$fh>) {

	my ($tag, $title) = split (",", $_);
	
	$titles{$tag} = $title;

}


# process files: see if they have 'title' tags and if they do, split the files.
my %partfiles;
foreach my $file (@files) {

	next if -d $file;
	
	next unless $file =~ /\.tess/;
	
	my @lines;
	
	open my $f, "<:utf8", $file or die $!;
	
	
	my @subfile = ();
	my $part = 0;
		
		my $outfile;

	while (<$f>) {
	

		my $line = $_;
		
		$_ =~ /(^<.+?>)/;
		
		my $tag = $1;
				
		if ($titles{$tag}) {
		
			print "Tag: $tag\n";
				
			$part++;
		
			# begin a new text
			
			# first, print the new text
			
			#check whether a directory exists for this
			my $dir = $file;
			
			print "Raw directory: $dir\n";
			
			$dir =~ s/\.tess$//;
			
			print "Sliced directory: $dir\n";
			
			
			unless (-d $dir) {
			
				mkdir $dir;
			
			}
			
			my $filename = $titles{$tag};
			
			print "Raw filename: $filename";
			
			chomp($filename);
			
			$filename =~ s/\s/_/g;
			
			$filename = lc($filename);

			print "Prepped filename: $filename";


			
			#the $filename is just the stuff to be appended.
			
			$file =~ /\/([^\/]+?)\.tess/;
			
			print "\$file: $file\n";
									
			$outfile = "$dir/$1.part.$part.$filename.tess";

			print STDERR "\$outfile: $outfile" . "\n\n";
			
			#my $useless = <STDIN>;

#			if ($outhandle) {close $outhandle;}
			
#			open $outhandle, ">:utf8", $outfile or die $!;
			
		}
		
#		if ($outhandle) {print $outhandle $line;}
#		else {print "Unused: $outhandle $line";}
		push (@{$partfiles{$outfile}}, $line);
	
	}
	
	
	


}

foreach my $file (keys %partfiles) {

	open my $f, ">:utf8", $file or die $!;
	
	foreach my $line (@{$partfiles{$file}}) {
	
		print $f $line;
	}
	
	









}

