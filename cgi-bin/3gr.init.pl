#! /opt/local/bin/perl5.12

# the line below is designed to be modified by configure.pl

use lib '/Users/chris/Sites/tesserae/perl';	# PERL_PATH

#
# 3gr.init.pl
#
# visualize 3-gram frequencies
#

use strict;
use warnings;

use CGI::Session;
use CGI qw/:standard/;

use Getopt::Long;
use Storable qw(nstore retrieve);
use File::Spec::Functions;
use File::Path qw(mkpath rmtree);

use TessSystemVars;
use EasyProgressBar;

#
# initialize set some parameters
#

# text to parse 

my $target = 0;

# unit

my $unit = 'line';

# length of memory effect in units

my $memory = 10;

# used to calculated the decay exponent

my $decay = .5;

# print debugging messages to stderr?

my $quiet = 0;

# 3-grams to look for; if empty, use all available

my $keys = 0;

# choose top n 3-grams

my $top = 0;

# for progress bars

my $pr;

# abbreviations of canonical citation refs

my $file_abbr = catfile($fs_data, 'common', 'abbr');
my %abbr = %{retrieve($file_abbr)};

# language database

my $file_lang = catfile($fs_data, 'common', 'lang');
my %lang = %{retrieve($file_lang)};

#
# check for cgi interface
#

my $cgi = CGI->new() || die "$!";
my $session;

my $no_cgi = defined($cgi->request_method()) ? 0 : 1;

# create new cgi session,
# print html header, if necessary

unless ($no_cgi) {

	$session = CGI::Session->new(undef, $cgi, {Directory => '/tmp'});
	
	my $cookie = $cgi->cookie(CGISESSID => $session->id );

	print header(-cookie=>$cookie, -encoding=>"utf8");
	
	my $stylesheet = "$url_css/style.css";

	print <<END;

<html>
	<head>
		<title>Tesserae results</title>
		<link rel="stylesheet" type="text/css" href="$stylesheet" />
	</head>
	<body>
END

}

#
# get options from command-line or cgi as appropriate
#

if ($no_cgi) {

	GetOptions( 
		'unit=s'       => \$unit,
		'decay=f'      => \$decay,
		'keys=s'       => \$keys,
		'top=i'        => \$top,
		'memory=i'     => \$memory,
		'quiet'        => \$quiet );
		
	$target = shift @ARGV;
}
else {

	$target = $cgi->param('target');
	$unit   = $cgi->param('unit')     || $unit;
	$decay  = $cgi->param('decay')    || $decay;
	$keys   = $cgi->param('keys')     || $keys;
	$top    = $cgi->param('top')      || $top;
	$memory = $cgi->param('memory')   || $memory;

	$session->save_param($cgi);

	$quiet  = 1;

	print <<END;
	
		<table>
			<tr><td>target</td><td>$target</td></tr>
			<tr><td>unit  </td><td>$unit  </td></tr>
			<tr><td>decay </td><td>$decay </td></tr>
			<tr><td>keys  </td><td>$keys  </td></tr>
			<tr><td>top   </td><td>$top   </td></tr>								
			<tr><td>memory</td><td>$memory</td></tr>
		</table>
END

}

#
# bail out if no target selected
# or if needed files aren't present
#

unless ($target) {

	die "no target specified";
}

unless (defined $lang{$target}) {

	die "target $target has no entry in the language database";
}

my $file = catfile($fs_data, 'v3', $lang{$target}, $target, $target);

for ('token', 'index_3gr', $unit) {

	unless (-s "$file.$_") {
	
		die "can't read $file.$_: $!";
	}
}

#
# read the files
#

print STDERR "loading $target\n" unless $quiet;

my @token = @{retrieve("$file.token")};

my @unit  = @{retrieve("$file.$unit")};

my %index = %{retrieve("$file.index_3gr")};

#
# set up the matrix of 3-gram frequencies
#

my @matrix;
$#matrix = $#unit;

# tally n-gram occurrences; used to choose funcional ngrams

my %count;

# user-selected set of keys

my @keys = $keys ? split(/,/, $keys) : keys(%index);

# max values for each column; used for scaling

my %max;

#
# get 3-gram counts from the index
#

# progress bar

if ($no_cgi) {

	print STDERR "Calculating n-gram count matrix\n" unless $quiet;	
	print STDERR "Initial counts\n" unless $quiet;

	$pr = ProgressBar->new(scalar(@keys), $quiet);
}
else {

	print "<p>Calculating n-gram count matrix</p>\n";
	print "<p>Initial counts</p>\n";

	$pr = HTMLProgress->new(scalar(@keys));
}

for my $key (@keys) {

	$pr->advance();

	for my $token_id (@{$index{$key}}) {
	
		my $unit_id = $token[$token_id]{uc($unit) . "_ID"};
		
		$matrix[$unit_id]{$key}++;
		
		$count{$key} ++;
	}
}

$pr->finish();

#
# add in the effect of earlier lines
#

# progress bar

if ($no_cgi) {

	print STDERR "Memory effect\n" unless $quiet;

	$pr = ProgressBar->new($#matrix, $quiet);
}
else {

	print "<p>Memory effect</p>\n";

	$pr = HTMLProgress->new($#matrix);
}

for (my $unit_id = $#matrix; $unit_id > 0; $unit_id--) {

	$pr->advance();

	my $first = $unit_id < $memory ? 0 : ($unit_id - $memory);
	
	for my $i ($first..$unit_id-1) {
	
		for my $key (keys %{$matrix[$i]}) {
		
			$matrix[$unit_id]{$key} += $matrix[$i]{$key}/($unit_id-$i) ** $decay;
			
			if ($matrix[$unit_id]{$key} > $max{$key}) {
			
				$max{$key} = $matrix[$unit_id]{$key};
			}
		}
	}	
}

$pr->finish();

#
# select functional ngrams if top set
#

@keys  = sort {$count{$b} <=> $count{$a}} keys %count;

if ($top and $top > 0 and $top < ($#keys-1)) {

	if ($no_cgi) {
	
		print STDERR "Selecting $top functional 3-grams\n";
	}
	else {
	
		print "<p>Selecting $top functional 3-grams</p>\n";
	}

	$#keys = $top - 1
}

#
# convert from array of hashes to array of arrays
#

for (@matrix) {

	$_ = [@{$_}{@keys}];
}

#
# export the matrix
#

if ($no_cgi) {

	print STDERR "Exporting matrix\n" unless $quiet;
	
	$pr = ProgressBar->new($#matrix+1, $quiet);
	
	print join("\t", @keys) . "\n";
	
	for my $i (0..$#matrix) {
	
		$pr->advance();
	
		print join("\t", $i, @{$matrix[$i]}) . "\n";		
	}
	
	$pr->finish();
}
else {

	print "<p>Saving matrix data</p>\n";

	$session->param('matrix', \@matrix);
	$session->param('keys',   \@keys);
	$session->param('maxval', [@max{@keys}]);
	
	my $link = "$url_cgi/3gr.display.pl";
	
	my $test = $session->param("target");

	print <<END;
	
		<a href="$link">Click here.</a>
	</body>
</html>
END

}