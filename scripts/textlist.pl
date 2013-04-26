# textlist.pl
#
# add texts to the drop-down menus

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
}

# load Tesserae-specific modules

use lib $lib;
use Tesserae;
use EasyProgressBar;

# load additional modules necessary for this script

use Storable qw(nstore retrieve);
use File::Basename;

#
# these lines set language-specific variables
# such as what is a letter and what isn't
#

my %abbr;
my $file_abbr = catfile($fs{data}, 'common', 'abbr');
	
if ( -s $file_abbr )	{  %abbr = %{retrieve($file_abbr)} }

my %lang;
my $file_lang = catfile($fs{data}, 'common', 'lang');

if (-s $file_lang )		{ %lang = %{retrieve($file_lang)} }

#
# get files to be processed from cmd line args
#  - sort into two bins: complete texts and partial
#

while (my $lang = shift @ARGV) {

	my @text = @{Tesserae::get_textlist($lang, -sort => 1)};

	my @full;
	my %part;
	
	for my $file_name (@text) {
	
		if ($file_name =~ /(.*)\.part\.(.*)/) {
		
			my ($work_name, $part_name) = ($1, $2);
			
			if ($part_name =~ /\.(.*)/) {
			
				$part_name = $1;
			}
			else {
			
				$part_name = "Book " . $part_name;
			}
		
			push @{$part{$work_name}}, {
				file => $file_name,
				part => $part_name};
		}
		else {
		
			push @full, $file_name;
		}
	} 

	#
	# write three textlists: source, target, multi
	#                                                     

                   
	my $base = catfile($fs{html}, "textlist.$lang");
	
	dropdown("$base.l.php", \@full);
	dropdown("$base.r.php", \@full, \%part);
	checkboxes("$base.multi.php", \@full);

}

#
# convert file name to nice display name
#

sub display {

	my $name = shift;
	
	my $display = $name;

	$display =~ s/\./ - /g;
	$display =~ s/\_/ /g;

	$display =~ s/\b([a-z])/uc($1)/eg;

	return $display;
}

#
# populate dropdown
#

sub dropdown {

	my ($file, $full, $part) = @_;
	my @full = @$full;
	my %part = $part ? %$part : ();
	
	open (FH, ">:utf8", $file) or die "can't write to $file: $!";
	
	for my $name (@full) {

		if (defined $part{$name}) {
		
			print FH sprintf("<optgroup label=\"%s\">\n", display($name));
	
			for (@{$part{$name}}) {
				
				my $file_name = $_->{file};
				my $part_name = $_->{part};
				
				print FH sprintf("   <option value=\"%s\">%s - %s</option>\n",
						$file_name,
				        display($name),
				        display($part_name));
			}
			
			print FH "</optgroup>\n";
		}
		else {
		
			print FH sprintf("<option value=\"%s\">%s</option>\n",
				$name,
				display($name));
		}
	}
	
	close FH;
}

sub checkboxes {

	my ($file, $full) = @_;
	
	my @full = @$full;
	
	open (FH, ">:utf8", $file) or die "can't write to $file: $!";

	print FH "<table>\n";
	
	push @full, ""if (scalar(@full) % 2);
	my $half = scalar(@full)/2;
	
	for (my $i = 0; $i < $half; $i++) {
	
		print FH sprintf("<tr><td>%s</td><td>%s</td></tr>\n",
			chk($full[$i]),
			$i + $half <= $#full ? chk($full[$i + $half]) : "");
	}
	
	print FH "</table>\n";

}

sub chk {
	
	my $name = shift;
		
	return sprintf('<input type="checkbox" name="include" value="%s">%s</input>',
		$name, display($name));
}
