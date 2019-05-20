#!/usr/bin/env perl

=head1 NAME 

read_bin.pl - Sort and format the results of a Tesserae search.

=head1 SYNOPSIS

B<read_bin.pl> [OPTIONS] <I<name> | B<--session> I<session_id>>

=head1 DESCRIPTION

This script reads the directory of binary files produced by I<read_table.pl> and presents the results to the user.  It's usually run behind the scenes to create the paged HTML tables seen from the web interface, but it can also be run from the command-line, and can format results as plain text or XML as well as HTML.

It takes as its argument the I<name> of the results saved by I<read_table.pl>--that is "tesresults," or whatever was specified using the B<--binary> flag.  Alternatively you may specify the I<session_id> of a previous web session.  Output is dumped to STDOUT.

Options:

=over

=item B<--sort> target|source|score

Which column to sort the results table by.  B<target> (the default) sorts by location in the target text, B<source>, by location in the source text, and B<score> sorts by the Tesserae-assigned score.

=item B<--reverse>

Reverse the sort order.  For sorting by score this is probably a good idea; otherwise you get the lowest scores first.

=item B<--batch> I<page_size>

For paged results, I<page_size> gives the number of results per page. The default is 100.  If you say B<all> here instead of a number, you'll get all the results on one page.

=item B<--page> I<page_no> 

For paged results, I<page_no> gives the page to display.  The default is 1.

=item B<--export> html|tab|csv|xml

How to format the results.  The default is B<html>.  I<tab> and I<csv> are similar: both produce plain text output, with one parallel to a line, and fields either separated by either tabs or commas.  Tab- and comma-separated results are not paged, but will be sorted according to the values of B<--sort> and B<--rev>. XML results are neither paged nor sorted (actually, they're always sorted by target).

If you want to import the results into Microsoft Excel, I<tab> seems to work best.

=item B<--session> I<session_id>

When this option is given, the results are read not from a local, named session, but rather from a previously-created session file in C<tmp/> having id I<session_id>.  This is useful if the results you want to read were generated from the web interface.

=item B<--quiet>

Don't write progress info to STDERR.

=item B<--help>

Print this message and exit.

=back

=head1 EXAMPLE

Presuming that you had previously run read_table.pl using the default name "tesresults" for your output:

% cgi-bin/read_bin.pl --export tab tesresults > results.txt

=head1 SEE ALSO

I<cgi-bin/read_table.pl>

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is read_bin.pl.

The Initial Developer of the Original Code is Research Foundation of State University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research Foundation of State University of New York, on behalf of University at Buffalo. All Rights Reserved.

Contributor(s): Neil Coffee, Chris Forstall, James Gawley.

Alternatively, the contents of this file may be used under the terms of either the GNU General Public License Version 2 (the "GPL"), or the GNU Lesser General Public License Version 2.1 (the "LGPL"), in which case the provisions of the GPL or the LGPL are applicable instead of those above. If you wish to allow use of your version of this file only under the terms of either the GPL or the LGPL, and not to allow others to use your version of this file under the terms of the UBPL, indicate your decision by deleting the provisions above and replace them with the notice and other provisions required by the GPL or the LGPL. If you do not delete the provisions above, a recipient may use your version of this file under the terms of any one of the UBPL, the GPL or the LGPL.

=cut

use strict;
use warnings;

#
# Read configuration file
#

# modules necessary to read config file

use Cwd qw/abs_path/;
use File::Spec::Functions;
use FindBin qw/$Bin/;
use utf8;
use Data::Dumper;
use JSON;
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

use CGI qw(:standard);
use POSIX;
use Storable qw(nstore retrieve);
use Encode;

# allow unicode output

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

my $no_cgi = defined($query->request_method()) ? 0 : 1;

#
# command-line options
#

# stopwords is the number of words on the stoplist

my $stopwords = 10;

# stoplist_basis is where we draw our feature
# frequencies from: source, target, or corpus

my $stoplist_basis = "corpus";

# maximum distance between matching tokens

my $max_dist = 5;

# metric for measuring distance

my $distance_metric = "freq";

# filter results below a certain score

my $cutoff = 0;

# filter multi-results if passing off to multitext.pl

my $multi_cutoff = 0;                  

# text list to pass on to multitext.pl

my @include;

# cache param to pass on to check-recall.pl

my $recall_cache = 'rec';

# what frequency table to use in scoring (distinguishes between word and lemma only)

my $score_basis = 'stem';

# print benchmark times?

my $bench = 0;

# which data file to use for the frequency metric used in scoring (either the texts or the corpus)

my $freq_basis = 'text';

# relative filepath to the results folder for this specific comparison method.

my $path;

# print debugging messages to stderr?

my $quiet = 0;

# sort algorithm

my $sort = 'score';

# first page of results to display

my $page = 1;

# how many results on a page?

my $batch = 1000;

# reverse order ?

my $rev = 1;

# determine file from session id

my $session;

# format for results

my $export = 'html';

# help flag

my $help;

# force word order flag
my $word_order;

# search nearby phrases/lines?

my $nearby;

# limit to sliding word window
my $window_size;

# unit (from the cgi interface)

my $unit;

#
# command-line arguments
#

GetOptions( 
		'path=s'			=> \$path,
		'stopwords=s'  => \$stopwords, 
		'freq_basis=s'  => \$freq_basis, 			
		'stbasis=s'    => \$stoplist_basis,
#		'binary=s'     => \$file_results,
		'order'			=> \$word_order,
		'nearby'		=> \$nearby,
		'window=i'		=> \$window_size,
		'distance=i'   => \$max_dist,
		'dibasis=s'    => \$distance_metric,
		'cutoff=f'     => \$cutoff,
		'score=s'      => \$score_basis,
		'benchmark'    => \$bench,
		'no-cgi'       => \$no_cgi,
		'sort=s'    => \$sort,
		'reverse'   => \$rev,
		'page=i'    => \$page,
		'batch=i'   => \$batch,
		'session=s' => \$session,
		'export=s'  => \$export,
		'quiet'     => \$quiet,
		'help'      => \$help );

#
# if help requested, print usage
#

if ($help) {

	pod2usage( -verbose => 2 );
}



#
# cgi input
#

unless ($no_cgi) {
	
	my $query = new CGI || die "$!";

#	$session = $query->param('session')    || die "no session specified from web interface"; #this needs to change for the REST API
	$sort       = $query->param('sort')    || $sort;
	$rev        = $query->param('rev')     if defined ($query->param("rev"));
	$nearby		= $query->param('nearby') 	|| $nearby;
	$page       = $query->param('page')    || $page;
	$word_order       = $query->param('order')    || $word_order;
	$batch      = $query->param('batch')   || $batch;
	$export     = $query->param('export')  || $export;
	$stopwords       = defined($query->param('stopwords')) ? $query->param('stopwords') : $stopwords;
	$stoplist_basis  = $query->param('stbasis')      || $stoplist_basis;
	$window_size        = $query->param('dist')         || $window_size;
	$distance_metric = $query->param('dibasis')      || $distance_metric;
	$cutoff          = $query->param('cutoff')       || $cutoff;
	$score_basis     = $query->param('score')        || $score_basis;
	$freq_basis     = $query->param('freq_basis')    || $freq_basis;
	$multi_cutoff    = $query->param('mcutoff')      || $multi_cutoff;
	@include         = $query->param('include');
	$recall_cache    = $query->param('recall_cache') || $recall_cache;
	my $source          = $query->param('source');
	my $target          = $query->param('target');
	$unit     		 = $query->param('unit');

	my $cts_ref = Tesserae::load_cts_map();

	my %cts_hash = %{$cts_ref};

	# open the new session file for output

	$path = catfile($cts_hash{$target}, $cts_hash{$source}, $unit);
	
	unless (defined $path) {
	
		die "read_bin_tmv.pl called from web interface with no DEFINED comparison file.";
	}
	
	my $file_results = catfile($fs{tmp}, $path);
	unless(-e $file_results and -d $file_results) {
		
		die "read_bin_tmv.pl called from web interface with no EXISTING comparison file.";
	
	}

	my %h = ('-charset'=>'utf-8', '-type'=>'text/html');
	
	if ($export eq "xml") { $h{'-type'} = "text/xml"; $h{'-attachment'} = "tesresults-$session.xml" }
	if ($export eq "csv") { $h{'-type'} = "text/csv"; $h{'-attachment'} = "tesresults-$session.csv" }
	if ($export eq "tab") { $h{'-type'} = "text/plain"; $h{'-attachment'} = "tesresults-$session.txt" }
	if ($export eq "json") { $h{'-type'} = "application/json"; $h{'-attachment'} = "tesresults-$session.txt" }		
	
	print header(%h);
	
	$quiet = 1;
}
else {

	unless (defined ($path)) {

		pod2usage( -verbose => 1);
	}


}

#
# first load up metadata and target and source hashes
#

print STDERR "reading $path\n" unless $quiet;

my $absolute_path;

unless ($no_cgi) {

	$absolute_path = catfile($fs{tmp}, $path, 'match');

}
else {

		$absolute_path = catfile($fs{tmp}, $path, 'match');

}

my %match_target = %{ retrieve("$absolute_path.target" ) };
my %match_source = %{ retrieve("$absolute_path.source")};
my %meta = %{ retrieve("$absolute_path.meta")};;
my %match_score; # this will be filled by the scoring algorithm
my %match_index = %{ retrieve("$absolute_path.index" ) };





=begin comment
my $file;

if (defined $session) {

	$file = catdir($fs{tmp}, "tesresults-" . $session);
}
else {
	
	$file = shift @ARGV;
}


#
# load the file
#

print STDERR "reading $file\n" unless $quiet;

my %match_target = %{retrieve(catfile($file, "match.target"))};
my %match_source = %{retrieve(catfile($file, "match.source"))};
my %score        = %{retrieve(catfile($file, "match.score"))};
my %meta         = %{retrieve(catfile($file, "match.meta"))};
=cut
#
# set some parameters
#

# source means the alluded-to, older text

my $source = $meta{SOURCE};

# target means the alluding, newer text

my $target = $meta{TARGET};

# unit means the level at which results are returned: 
# - choice right now is 'phrase' or 'line'

if ($no_cgi) {

	$unit = $meta{UNIT};
}

# feature means the feature set compared: 
# - choice is 'word' or 'stem'

my $feature = $meta{FEATURE};

my $lang = Tesserae::lang($target);

my $modern = 0;

if ($lang eq 'en') {

	$modern = 1;

}
my %target_dictionary;

my %source_dictionary;

my $corpus_wide = 0;

# If corpus-wide frequencies need to be counted, set the corpus-wide flag.

if ($score_basis eq 'stem' && $freq_basis eq 'corpus' || $score_basis eq 'syn_lem' && $freq_basis eq 'corpus' || $score_basis eq 'g_l' && $freq_basis eq 'corpus' ) { 	
	
	$corpus_wide = 1;
	
}


#
# read data from table
#


unless ($quiet) {
	
	print STDERR "reading source data\n";
}

my $file_source = catfile($fs{data}, 'v3', Tesserae::lang($source), $source, $source);

my @token_source   = @{ retrieve("$file_source.token") };
my @unit_source    = @{ retrieve("$file_source.$unit") };
my %index_source   = %{ retrieve("$file_source.index_$feature")};

unless ($quiet) {

	print STDERR "reading target data\n";
}

my $file_target = catfile($fs{data}, 'v3', Tesserae::lang($target), $target, $target);

my @token_target   = @{ retrieve("$file_target.token") };
my @unit_target    = @{ retrieve("$file_target.$unit") };
my %index_target   = %{ retrieve("$file_target.index_$feature" ) };


#
# perform scoring and cutoff functions
#


my $t1 = time;

# default score basis set by Tesserae.pm

unless (defined $score_basis)  { 
	
	$score_basis = $Tesserae::feature_score{$feature} || 'word';
	
}

# the Tesserae.pm hash needs to be called if the score basis is set to 'feature'

if ($score_basis eq 'feature')  { 
	
	$score_basis = $Tesserae::feature_score{$feature} || 'word';
	
}
# if user selected 'feature' as score basis,
# set it to whatever the feature is

if ($score_basis =~ /^feat/) {

	$score_basis = $feature;
	
}

if ($lang eq 'fr') {

	$modern = 1;

}

unless ($modern == 1) {
	
	# resolve the path to the stem dictionaries

	my $target_dict_file = catfile($fs{data}, 'common', Tesserae::lang($target) . '.stem.cache');

	my $source_dict_file = catfile($fs{data}, 'common', Tesserae::lang($source) . '.stem.cache');	

	# load the storable binaries
	
	%target_dictionary = %{retrieve($target_dict_file)};

	%source_dictionary = %{retrieve($source_dict_file)};	
}



#
# calculate feature frequencies
#

# token frequencies from the target text

my $file_freq_target;
unless ($freq_basis =~ /^corp/) {

	# by default, the frequency of the words or lemmas is drawn from the text in question
	
	$file_freq_target = select_file_freq($target) . ".freq_score_" . $score_basis;
	
}
else {

	# if the $freq_basis is set to corpus, the files which provide frequency stats are replaced with the corpus-wide versions.

	$file_freq_target = catfile($fs{data}, 'common', Tesserae::lang($target) . '.' . $score_basis . '.freq');

}

my %freq_target = %{Tesserae::stoplist_hash($file_freq_target)};

# token frequencies from the source text

my $file_freq_source;

unless ($freq_basis =~ /^corp/) {

	$file_freq_source = select_file_freq($source) . ".freq_score_" . $score_basis;
	
}
else {

	# this should allow target and source to use different corpus-frequency hashes based on respective language.

	$file_freq_source = catfile($fs{data}, 'common', Tesserae::lang($source) . '.' . $score_basis . '.freq')
	
}

my %freq_source = %{Tesserae::stoplist_hash($file_freq_source)};



unless ($quiet) {

	print STDERR "target=$target\n";
	print STDERR "source=$source\n";
	print STDERR "lang(target)=" . Tesserae::lang($target) . ";\n";
	print STDERR "lang(source)=" . Tesserae::lang($source) . ";\n";		
	print STDERR "feature=$feature\n";
	print STDERR "unit=$unit\n";
	print STDERR "stopwords=$stopwords\n";
	print STDERR "stoplist basis=$stoplist_basis\n";
	print STDERR "max_dist=$max_dist\n";
	print STDERR "distance basis=$distance_metric\n";
	print STDERR "score cutoff=$cutoff\n";
	print STDERR "frequency basis=$freq_basis\n";
	print STDERR "score basis=$score_basis\n";
	print STDERR "corpus-wide flag=$corpus_wide\n";
	print STDERR "File for source frequency=$file_freq_source\n";	
	print STDERR "File for target frequency=$file_freq_target\n";		
}

#
# basis for stoplist is feature frequency from one or both texts
#

my @stoplist = @{load_stoplist($stoplist_basis, $stopwords)};

unless ($quiet) { print STDERR "stoplist: " . join(",", @stoplist) . "\n"}



#
#
# assign scores
#
#

$t1 = time;

# how many matches in all?

my $total_matches = 0;

# draw a progress bar

#my $pr;



#
#
# remove stopwords
#
#

if ($no_cgi) {

	print STDERR "removing stopwords\n" unless $quiet;

#	$pr = ProgressBar->new(scalar(keys %match_target), $quiet);
}
else {

#	print "<p>Removing Stopwords...</p>\n";

#	$pr = HTMLProgress->new(scalar(keys %match_target));
}

foreach my $stopword (@stoplist) {

#	$pr->advance();

	foreach my $address (@{$match_index{$stopword}}) {
	
#		print STDERR "$address\n";
	
		my ($unit_id_target, $unit_id_source, $token_id_target, $token_id_source) = split (",", $address);
	
#		print STDERR "$unit_id_target, $unit_id_source, $token_id_target, $token_id_source\n";
	
		delete $match_target{$unit_id_target}{$unit_id_source}{$token_id_target}{$stopword};
	
		delete $match_source{$unit_id_target}{$unit_id_source}{$token_id_source}{$stopword};
	
	}

}




if ($no_cgi) {

	print STDERR "calculating scores\n" unless $quiet;

	#$pr = ProgressBar->new(scalar(keys %match_target), $quiet);
}
else {

	#print "<p>Scoring...</p>\n";

	#$pr = HTMLProgress->new(scalar(keys %match_target));
}

#
# look at the matches one by one, according to unit id in the target
#

# the global expanded match lists
my %all_match_target;
my %all_match_source;

# a list of all the combinations of target and source unit sequences that pass muster; used to avoid duplicates.
my %seen_matches;

for my $unit_id_target (keys %match_target) {

	# advance the progress bar

	#$pr->advance();


	# look at all the source units where the feature occurs
	# sort in numerical order

	for my $unit_id_source (keys %{$match_target{$unit_id_target}}) {
                                     
		# intra-textual matching:
		# 
		# where source and target are the same text, don't match
		# a line with itself
		
		next if ($source eq $target) and ($unit_id_source == $unit_id_target);

		# in order to avoid repeating the same matches when nearby units can be recruited, build a description of this match
		
		my $source_unit_description;
		my $target_unit_description;

		# at this point, it might help to load the nearby units and discover additional shared language.
		# one could potentially replace the list of words matched (keys %{$match_target{$unit_id_target}{$unit_id_source}})
		# with an array composed of all the shared language.
		
		#check the 'nearby flag'. define variables to avoid bugs in other code blocks.
		
		my $prev_unit_id_target;

		my $next_unit_id_target;
			
		my $prev_unit_id_source;

		my $next_unit_id_source;		
		
		if ($nearby) {
			
			if ($match_target{$unit_id_target - 1}){
			
				$prev_unit_id_target = $unit_id_target - 1;
			 
			}
			else {
			
				$prev_unit_id_target = $unit_id_target;
				
			}
			
			if ($match_target{$unit_id_target + 1}){
			
				$next_unit_id_target = $unit_id_target + 1;
			 
			}
			else {
			
				$next_unit_id_target = $unit_id_target;
				
			}
			
			# same for the source units

			if ($match_source{$unit_id_source - 1}){
			
				$prev_unit_id_source = $unit_id_source - 1;
			 
			}
			else {
			
				$prev_unit_id_source = $unit_id_source;
				
			}
			
			if ($match_source{$unit_id_source + 1}){
			
				$next_unit_id_source = $unit_id_source + 1;
			 
			}
			else {
			
				$next_unit_id_source = $unit_id_source;
				
			}
		}		
		# put all the matchwords together
		
		%{$all_match_target{$unit_id_target}{$unit_id_source}} = %{$match_target{$unit_id_target}{$unit_id_source}};
		
		if (defined $match_target{$prev_unit_id_target}{$prev_unit_id_source}) {
		
			$target_unit_description = "$prev_unit_id_target-";
		
			%{$all_match_target{$unit_id_target}{$unit_id_source}}	=  (%{$all_match_target{$unit_id_target}{$unit_id_source}}, %{$match_target{$prev_unit_id_target}{$prev_unit_id_source}});
		
		}
		
		$target_unit_description .= "$unit_id_target";
		
		if (defined $match_target{$next_unit_id_target}{$next_unit_id_source}) {
		
			$target_unit_description .= "-$next_unit_id_source";
		
			%{$all_match_target{$unit_id_target}{$unit_id_source}}	=  (%{$all_match_target{$unit_id_target}{$unit_id_source}}, %{$match_target{$next_unit_id_target}{$next_unit_id_source}});
		
		}
		
		#same for source as target
		
		%{$all_match_source{$unit_id_target}{$unit_id_source}} = %{$match_source{$unit_id_target}{$unit_id_source}};
		
		if (defined $match_source{$prev_unit_id_target}{$prev_unit_id_source}) {
		
			$source_unit_description = "$prev_unit_id_source-";		
		
			%{$all_match_source{$unit_id_target}{$unit_id_source}}	=  (%{$all_match_source{$unit_id_target}{$unit_id_source}}, %{$match_source{$prev_unit_id_target}{$prev_unit_id_source}});
		
		}
		
		
		$source_unit_description .= "$unit_id_source";		
		
		if (defined $match_source{$next_unit_id_target}{$next_unit_id_source}) {
		
			$source_unit_description .= "-$next_unit_id_source";		
		
			%{$all_match_source{$unit_id_target}{$unit_id_source}}	=  (%{$all_match_source{$unit_id_target}{$unit_id_source}}, %{$match_source{$next_unit_id_target}{$next_unit_id_source}});
		
		}
		

		#
		# remove matches having fewer than 2 matching words 
		# or matching on fewer than 2 different keys
		#
			
		# check that the target has two matching words
		# Note: when single-word search is implemented, this should probably just be lowered, not skipped.
		# That way if the stoplist check deleted something from target but not from the source, we still delete the record.
			
		if ( scalar( keys %{$all_match_target{$unit_id_target}{$unit_id_source}} ) < 2) {
		
			# it's a really bad idea to delete things like this when we're studying a sliding window
#			delete $match_target{$unit_id_target}{$unit_id_source};
#			delete $match_source{$unit_id_target}{$unit_id_source};			

			#try deleting the new record instead
			delete $all_match_target{$unit_id_target}{$unit_id_source};
			delete $all_match_source{$unit_id_target}{$unit_id_source};
			
			next;

		}
		
		# check that the source has two matching words


		if ( scalar( keys %{$all_match_source{$unit_id_target}{$unit_id_source}} ) < 2) {
	
			#delete $match_target{$unit_id_target}{$unit_id_source};
			#delete $match_source{$unit_id_target}{$unit_id_source};
			delete $all_match_target{$unit_id_target}{$unit_id_source};
			delete $all_match_source{$unit_id_target}{$unit_id_source};
			
			next;			
		}		
	
		# make sure each phrase has at least two different inflected forms
		
		my %seen_forms;	
		
		for my $token_id_target (keys %{$all_match_target{$unit_id_target}{$unit_id_source}} ) {
						
			$seen_forms{$token_target[$token_id_target]{FORM}}++;
		}
		
		if (scalar(keys %seen_forms) < 2) {
		
			#delete $match_target{$unit_id_target}{$unit_id_source};
			#delete $match_source{$unit_id_target}{$unit_id_source};
			delete $all_match_target{$unit_id_target}{$unit_id_source};
			delete $all_match_source{$unit_id_target}{$unit_id_source};
			next;			
		}	
		
		%seen_forms = ();
		
		for my $token_id_source ( keys %{$all_match_source{$unit_id_target}{$unit_id_source}} ) {
		
			$seen_forms{$token_source[$token_id_source]{FORM}}++;
		}

		if (scalar(keys %seen_forms) < 2) {
		
			#delete $match_target{$unit_id_target}{$unit_id_source};
			#delete $match_source{$unit_id_target}{$unit_id_source};

			delete $all_match_target{$unit_id_target}{$unit_id_source};
			delete $all_match_source{$unit_id_target}{$unit_id_source};

			next;			

		}
		
		#if word order is flagged, make sure the matches come in the same order.
		
		my $skip_for_order = 0;
		
		my %token_id_lineup;
		
		
        # the lemmatized form is necessary for this comparison.
        # the problem is that there could be multiple lemma options for one word, and only one for another.
        # so we need to retrieve the keys and check for intersection between those two arrays.
        # we end up with a list of target_token_ids -> source_token_ids
        # then we sort the list by target token id, and check to make sure that also sorts the source token ids.

        for my $token_id_target (keys %{$all_match_target{$unit_id_target}{$unit_id_source}}) { # the target->target->source hash contains a list of target unit ID#s

            for my $token_id_source (keys %{$all_match_source{$unit_id_target}{$unit_id_source}}) { # the source->target->source hash contains a list of source unit IDs
                
                my @source_lemmas = keys %{$all_match_source{$unit_id_target}{$unit_id_source}{$token_id_source}};
                
                my @lemma_overlap = grep (${$all_match_target{$unit_id_target}{$unit_id_source}{$token_id_target}}{$_}, @source_lemmas);
                
                if (scalar @lemma_overlap > 0) {
                
                    $token_id_lineup{$token_id_target} = $token_id_source;
                
                }
            }
        }
        
        my @ordered_targets = sort {$a <=> $b} keys %token_id_lineup;
        
        for my $ordered_position (0..$#ordered_targets) {
        
            if (defined $ordered_targets[$ordered_position + 1]) {
            
                unless ($token_id_lineup{$ordered_targets[$ordered_position]} < $token_id_lineup{$ordered_targets[$ordered_position + 1]}) {
                
                    $skip_for_order = 1;
                
                }
            
            }
        
        }

		
		if ($word_order && $skip_for_order == 1) {
		
			next;
		
		}
		
		my $window_flag = 0;
		
		if ($window_size) {
		
	        my @ordered_source = sort {$a <=> $b} values %token_id_lineup;
		
			my %all_tokens_target;
			
			for my $target_token_id ($ordered_targets[0]..$ordered_targets[$#ordered_targets]) {
			
				if ($token_target[$target_token_id]->{'TYPE'} eq 'WORD') {
				
					$all_tokens_target{$target_token_id} = 1;
				
				}
			
			}
			
			my %all_tokens_source;
			
			for my $source_token_id ($ordered_source[0]..$ordered_source[$#ordered_source]) {
			
				if ($token_source[$source_token_id]->{'TYPE'} eq 'WORD') {
				
					$all_tokens_source{$source_token_id} = 1;
				
				}
			
			}

			my @ordered_all_target = sort {$a <=> $b} keys %all_tokens_target;			
			my @ordered_all_source = sort {$a <=> $b} keys %all_tokens_source;
			
			#how many word tokens exist between one matchword and the next?
			my %all_tokens_target_indexed;
			@all_tokens_target_indexed{@ordered_all_target} = (0..$#ordered_all_target);
					
			my %all_tokens_source_indexed;
			@all_tokens_source_indexed{@ordered_all_source} = (0..$#ordered_all_source);
			
			for my $index (0..$#ordered_targets) {
			
				if (defined $ordered_targets[$index + 1]) {
				
					my $current_token_id = $ordered_targets[$index];
					
					my $next_token_id = $ordered_targets[$index + 1];
				
					my $distance = $all_tokens_target_indexed{$next_token_id} - $all_tokens_target_indexed{$current_token_id} - 1;
					
					if ($distance > $window_size) {
					
						$window_flag = 1;
					
					}
				
				}
			
			}

			for my $index (0..$#ordered_source) {
			
				if (defined $ordered_source[$index + 1]) {
				
					my $current_token_id = $ordered_source[$index];
					
					my $next_token_id = $ordered_source[$index + 1];
				
					my $distance = $all_tokens_source_indexed{$next_token_id} - $all_tokens_source_indexed{$current_token_id} - 1;
					
					if ($distance > $window_size) {
					
						$window_flag = 1;
					
					}
				
				}
			
			}			
		}
		
		
		if ($window_size && $window_flag == 1) {
		
			next;
		
		}
		
		# check to see whether this set of units has been seen before already
		
		my $match_description = join ('-', sort (keys %{$all_match_target{$unit_id_target}{$unit_id_source}})) . "|" . join ('-', sort (keys %{$all_match_source{$unit_id_target}{$unit_id_source}}));
		
		if (defined $seen_matches{"$match_description"}) {
		
#			print STDERR "$match_description is a duplicate.\n";
		
			next;
		}
		
		$seen_matches{"$match_description"} = 1;

		
		

		#
		# calculate the distance
		# 
		
		my $distance = dist($all_match_target{$unit_id_target}{$unit_id_source}, $all_match_source{$unit_id_target}{$unit_id_source}, $distance_metric);
		
		if ($distance > $max_dist) {
		
			delete $all_match_target{$unit_id_target}{$unit_id_source};
			delete $all_match_source{$unit_id_target}{$unit_id_source};
			next;
		}
		
		
		#
		# calculate the score
		#
		
		# score
		
		my $score = score_default($all_match_target{$unit_id_target}{$unit_id_source}, $all_match_source{$unit_id_target}{$unit_id_source}, $distance);
								
		if ( $score < $cutoff) {

			delete $all_match_target{$unit_id_target}{$unit_id_source};
			delete $all_match_source{$unit_id_target}{$unit_id_source};
			next;			
		}
		
		# save calculated score, matched words, etc.
		
		$match_score{$unit_id_target}{$unit_id_source} = $score;
		
		$total_matches++;
	}
}

print "score>>" . (time-$t1) . "\n" if $no_cgi and $bench;




if (@include) {

	write_multi_list($path, \@include);
}

#
# end the code originally taken from read_table.pl
#

=begin comments

# stoplist

my $stop = $meta{STOP};

my @stoplist = @{$meta{STOPLIST}};

# stoplist basis

my $stoplist_basis = $meta{STBASIS};

# max distance

my $max_dist = $meta{DIST};

# distance metric

my $distance_metric = $meta{DIBASIS};

# low-score cutoff

my $cutoff = $meta{CUTOFF};

# score team filter state

my $filter = $meta{FILTER};

# session id

$session = $meta{SESSION};

# total number of matches

my $total_matches = $meta{TOTAL};

# notes

my $comments = $meta{COMMENT};

=cut

#
# load some more parameters
#

my $filter = $meta{FILTER}; 

my $stop = scalar(@stoplist);

# sort the results

my @rec = @{sort_results()};

if ($batch eq 'all') {

	$batch = $total_matches;
	$page  = 1;
}

#
# load texts
#

# abbreviations of canonical citation refs

my $file_abbr = catfile($fs{data}, 'common', 'abbr');
my %abbr = %{retrieve($file_abbr)};


=begin comments
# read source text

unless ($quiet) {
	
	print STDERR "reading source data\n";
}

my $path_source = catfile($fs{data}, 'v3', Tesserae::lang($source), $source, $source);

my @token_source   = @{ retrieve( "$path_source.token"    ) };
my @unit_source    = @{ retrieve( "$path_source.${unit}" ) };
my %index_source   = %{ retrieve( "$path_source.index_$feature" ) };

# read target text

unless ($quiet) {

	print STDERR "reading target data\n";
}

my $path_target = catfile($fs{data}, 'v3', Tesserae::lang($target), $target, $target);

my @token_target   = @{ retrieve( "$path_target.token"    ) };
my @unit_target    = @{ retrieve( "$path_target.${unit}" ) };
my %index_target   = %{ retrieve( "$path_target.index_$feature" ) };
=cut

#
# output
#

if ($export eq "html") {

	print_html($page, $batch);	
}
elsif ($export eq "csv") {
	
	print_delim(",");
}
elsif ($export eq "tab") {
	
	print_delim("\t");
}
elsif  ($export eq "xml") {
	
	print_xml();
}
elsif  ($export eq "json") {
	
	print_json();
}



#
# subroutines
#

#
# dist : calculate the distance between matching terms
#
#   used in determining match scores
#   and in filtering out bad results

sub dist {

	my ($match_t_ref, $match_s_ref, $metric) = @_;
	
	my %match_target = %$match_t_ref; # The list of matchwords come to this subroutine in the form of a hash. The keys are token ID #s.
	my %match_source = %$match_s_ref;
	
	my @target_id = sort {$a <=> $b} keys %match_target; # To perform the calculation of distance, the token IDs have to be put in ascending order.
	my @source_id = sort {$a <=> $b} keys %match_source;
	
	my $dist = 0;
	
	#
	# distance is calculated by one of the following metrics
	#
	
	# freq: count all words between (and including) the two lowest-frequency 
	# matching words in each phrase.  NB this is the best metric in my opinion.
	
	if ($metric eq "freq") {
	
		# sort target token ids by frequency of the forms
		
		my @t;
		
		unless ($corpus_wide == 1) {
	
			@t = sort {$freq_target{$token_target[$a]{FORM}} <=> $freq_target{$token_target[$b]{FORM}}} @target_id;
	
		}
		else {
		
			# if frequency values are supposed to be stem-based and corpus-wide, invoke the stem-averaging subroutine
		
			@t = sort {stem_frequency($token_target[$a]{FORM}, 'target') <=> stem_frequency($token_target[$b]{FORM}, 'target')} @target_id;
			
		}
			      
		# consider the two lowest;
		# put them in order from left to right
			      
		if ($t[0] > $t[1]) { @t[0,1] = @t[1,0] }
			
		# now go token to token between them, incrementing the distance
		# only if each token is a word.
			
		for ($t[0]..$t[1]) {
		
		  $dist++ if $token_target[$_]{TYPE} eq 'WORD';
		}
			
		# now do the same in the source phrase
			
		my @s;
		
		unless ($corpus_wide == 1) {
			
			@s = sort {$freq_source{$token_source[$a]{FORM}} <=> $freq_source{$token_source[$b]{FORM}}} @source_id; 

		} 
		else {

			@s = sort {stem_frequency($token_source[$a]{FORM}, 'source') <=> stem_frequency($token_source[$b]{FORM}, 'source')} @source_id; 
			
		}
		
		if ($s[0] > $s[1]) { @s[0,1] = @s[1,0] }
			
		for ($s[0]..$s[1]) {
		
		  $dist++ if $token_source[$_]{TYPE} eq 'WORD';
		}
	}
	
	# freq_target: as above, but only in the target phrase
	
	elsif ($metric eq "freq_target") {
		
		my @t = sort {$freq_target{$token_target[$a]{FORM}} <=> $freq_target{$token_target[$b]{FORM}}} @target_id; 
			
		if ($t[0] > $t[1]) { @t[0,1] = @t[1,0] }
			
		for ($t[0]..$t[1]) {
		
		  $dist++ if $token_target[$_]{TYPE} eq 'WORD';
		}
	}
	
	# freq_source: ditto, but source phrase only
	
	elsif ($metric eq "freq_source") {
		
		my @s = sort {$freq_source{$token_source[$a]{FORM}} <=> $freq_source{$token_source[$b]{FORM}}} @source_id; 
		
		if ($s[0] > $s[1]) { @s[0,1] = @s[1,0] }
			
		for ($s[0]..$s[1]) {
		
		  $dist++ if $token_source[$_]{TYPE} eq 'WORD';
		}
	}
	
	# span: count all words between (and including) first and last matching words
	
	elsif ($metric eq "span") {
	
		# check all tokens from the first (lowest-id) matching word
		# to the last.  increment distance only if token is of type WORD.
	
		for ($target_id[0]..$target_id[-1]) {
		
		  $dist++ if $token_target[$_]{TYPE} eq 'WORD';
		}
		
		for ($source_id[0]..$source_id[-1]) {
		
		  $dist++ if $token_source[$_]{TYPE} eq 'WORD';
		}
	}
	
	# span_target: as above, but in the target only
	
	elsif ($metric eq "span_target") {
		
		for ($target_id[0]..$target_id[-1]) {
		
		  $dist++ if $token_target[$_]{TYPE} eq 'WORD';
		}
	}
	
	# span_source: ditto, but source only
	
	elsif ($metric eq "span_source") {
		
		for ($source_id[0]..$source_id[-1]) {
		
		  $dist++ if $token_source[$_]{TYPE} eq 'WORD';
		}
	}
		
	return $dist;
}

sub load_stoplist {

	my ($stoplist_basis, $stopwords) = @_[0,1];
	
	my %basis;
	my @stoplist;
	
	if ($stopwords eq "function") {
	
		my $file = catfile($fs{data}, 'common', Tesserae::lang($target) . '.' . 'function');
	
		my $list = Tesserae::stoplist_array($file);
		

		return $list;
	
	}
	
	
	if ($stoplist_basis eq "target") {
		
		my $file = select_file_freq($target) . '.freq_stop_' . $feature;
		%basis = %{Tesserae::stoplist_hash($file)};
	}
	
	elsif ($stoplist_basis eq "source") {
		
		my $file = select_file_freq($source) . '.freq_stop_' . $feature;

		%basis = %{Tesserae::stoplist_hash($file)};
	}
	
	elsif ($stoplist_basis eq "corpus") {

		my $file = catfile($fs{data}, 'common', Tesserae::lang($target) . '.' . $feature . '.freq');
		
		%basis = %{Tesserae::stoplist_hash($file)};
	}
	
	elsif ($stoplist_basis eq "both") {
		
		my $file_target = select_file_freq($target) . '.freq_stop_' . $feature;
		%basis = %{Tesserae::stoplist_hash($file_target)};
		
		my $file_source = select_file_freq($source) . '.freq_stop_' . $feature;
		my %basis2 = %{Tesserae::stoplist_hash($file_source)};
		
		for (keys %basis2) {
		
			$basis{$_} = 0 unless defined $basis{$_};
		
			$basis{$_} = ($basis{$_} + $basis2{$_})/2;
		}
	}
		
	@stoplist = sort {$basis{$b} <=> $basis{$a}} keys %basis;
	
	if ($stopwords > 0) {
		
		if ($stopwords > scalar(@stoplist)) { $stopwords = scalar(@stoplist) }
		
		@stoplist = @stoplist[0..$stopwords-1];
	}
	else {
		
		@stoplist = ();
	}

	return \@stoplist;
}


sub score_default {
	
	my ($match_t_ref, $match_s_ref, $distance) = @_;

	my %match_target = %$match_t_ref;
	my %match_source = %$match_s_ref;
	
	my $score = 0;
		
	for my $token_id_target (keys %match_target ) {
									
		# add the frequency score for this term
		
		# if $freq_basis is set to corpus and $score_basis is set to stem
		# retrieve the stem array and take the average frequency value of all possibilities
		
		my $freq;
		
		unless ($corpus_wide == 1) {
		
			$freq = 1/$freq_target{$token_target[$token_id_target]{FORM}}; 
		
		} 
		else {
		
			$freq = 1/stem_frequency($token_target[$token_id_target]{FORM}, 'target');
		
		}
				
		# for 3-grams only, consider how many features the word matches on
				
	if ($feature eq '3gr') {
		
			$freq *= scalar(keys %{$match_target{$token_id_target}});
		}
		
		$score += $freq;
	}
	
	for my $token_id_source ( keys %match_source ) {

		# add the frequency score for this term

		my $freq;
		
		unless ($corpus_wide == 1) {
		
			$freq = 1/$freq_source{$token_source[$token_id_source]{FORM}};
		
		}
		else {
		
			$freq = 1/stem_frequency($token_source[$token_id_source]{FORM}, 'source');
		
		}
		# for 3-grams only, consider how many features the word matches on
				
		if ($feature eq '3gr') {
		
			$freq *= scalar(keys %{$match_source{$token_id_source}});
		}
		
		$score += $freq;
	}
	
	$score = sprintf("%.3f", log($score/$distance));
	
	return $score;
}


# save the list of multi-text searches to session file

sub write_multi_list {
	
	my ($session, $incl) = @_;
	
	my @include = @$incl;
	
	my $file_list = catfile($session, '.multi.list');
	
	open (FH, ">:utf8", $file_list) or die "can't write $file_list: $!";
	
	for (@include) {
	
		print FH $_ . "\n";
	}
	
	close FH;
}

# choose the frequency file for a text

sub select_file_freq {

	my $name = shift;
	
	if ($name =~ /\.part\./) {
	
		my $origin = $name;
		$origin =~ s/\.part\..*//;
		
		if (defined $abbr{$origin} and defined Tesserae::lang($origin)) {
		
			$name = $origin;
		}
	}
	
	my $lang = Tesserae::lang($name);
	my $file_freq = catfile(
		$fs{data}, 
		'v3', 
		$lang, 
		$name, 
		$name
	);
	
	return $file_freq;
}

# take an inflected form, and return the average corpus-wide frequency value of the associated stems

sub stem_frequency {
	
	my ($form, $text) = @_;
	
	# this subroutine is agnostic of language but must be fed the appropriate text (target or source)
	
	my $average;
		
	if ($text eq 'target') {
		

		my @stems = ();
		
		# load all possible stems
		# if the stem array doesn't exist, use the form

		
		unless ($modern == 1) {		

			if ($target_dictionary{$form}) {

				@stems = @{$target_dictionary{$form}};

			}

			else {

				$stems[0] = $form;

			}

		}

		else { 
		
		# if the language is modern, it's necessary to use Lingua::Stem
		
			my $stem_ref = stem($form);
		
			@stems = @{$stem_ref};
		
		}
				

		# retrieve corpus-wide frequency values for each stem
	
		my $freq_values;
	
		for (0..$#stems) {

			$freq_values += $freq_target{$stems[$_]};

		}
	
		# average the frequencies
	
		$average = $freq_values / (scalar @stems);
		
	}
	else {
	
		# load all possible stems
		
		my @stems = ();
	
		unless ($modern == 1) {
		
			if ($source_dictionary{$form}) {	

				@stems = @{$source_dictionary{$form}};

			}

			else {

				$stems[0] = $form;

			}
	
		}
		
		else { 
		
		# if the language is modern, it's necessary to use Lingua::Stem
		
			my $stem_ref = stem($form);
		
			@stems = @{$stem_ref};
		

		}
	
		# retrieve corpus-wide frequency values for each stem
	
		my $freq_values;
	
		for (0..$#stems) {

			$freq_values += $freq_source{$stems[$_]};
		
		}
	
		# average the frequencies
	
		$average = $freq_values / (scalar @stems);
		
	}
	
	
	return $average;

}


sub nav_page {
		
	my $html = "<p>$total_matches results";
	
	my $pages = ceil($total_matches/$batch);
	
	#
	# if there's only one page, don't bother
	#
	
	if ($pages > 1) {
				
		$html .= " in $pages pages.</br>\n";
	
		#
		# draw navigation links
		# 
	
		my @left = ();
		my @right = ();
	
		my $back_arrow = "";
		my $forward_arrow = "";
			
		$html .= "Go to page: ";
	
		if ($page > 1) {
		
			$back_arrow .= "<span>";
			$back_arrow .= "<a href=\"$url{cgi}/read_bin.pl?session=$session;sort=$sort;rev=$rev;page=1;batch=$batch\"> [first] </a>\n";
			$back_arrow .= "</span>";

			my $p = $page-1;

			$back_arrow .= "<span>";				
			$back_arrow .= "<a href=\"$url{cgi}/read_bin.pl?session=$session;sort=$sort;rev=$rev;page=$p;batch=$batch\"> [previous] </a>\n";
			$back_arrow .= "</span>";
		
		
			@left = (($page > 4 ? $page-4 : 1)..$page-1);
		}
	
		if ($page < $pages) {
		
			my $p = $page+1;
		
			$forward_arrow .= "<span>";
			$forward_arrow .= "<a href=\"$url{cgi}/read_bin.pl?session=$session;sort=$sort;rev=$rev;page=$p;batch=$batch\"> [next] </a>\n";
			$forward_arrow .= "</span>";

			$forward_arrow .= "<span>";
			$forward_arrow .= "<a href=\"$url{cgi}/read_bin.pl?session=$session;sort=$sort;rev=$rev;page=$pages;batch=$batch\"> [last] </a>\n";		       
			$forward_arrow .= "</span>";
		
			@right = ($page+1..($page < $pages-4 ? $page+4 : $pages));
		}
	
		$html .= $back_arrow;
	
		for my $p (@left, $page, @right) {
		
			$html .= "<span>";
		
			if ($page == $p) { 
			
				$html .= " $p ";
			}
			else {
			
				$html .= "<a href=\"$url{cgi}/read_bin_tmv.pl?session=$session;sort=$sort;rev=$rev;page=$p;batch=$batch\"> $p </a>";
			}	
			
			$html .= "</span>";
		}
	
		$html .= $forward_arrow;
		$html .= "\n";
	}
			
	return $html;
	
}

sub re_sort {
	
	my @sel_rev    = ("", "");
	my %sel_sort   = (target => "", source => "", score => "");
	my %sel_export = (html => "", xml => "", csv => "", tab => "");
	my %sel_batch  = (50 => '', 100 => '', 200 => '', $total_matches => '');

	$sel_rev[$rev]       = 'selected="selected"';
	$sel_sort{$sort}     = 'selected="selected"';
	$sel_export{$export} = 'selected="selected"';
	$sel_batch{$batch}   = 'selected="selected"';

	my $html=<<END;
	
	<form action="$url{cgi}/read_bin_tmv.pl" method="post" id="Form1">
		
		<table>
			<tr>
				<td>

			Sort

			<select name="rev">
				<option value="0" $sel_rev[0]>increasing</option>
				<option value="1" $sel_rev[1]>decreasing</option>
			</select>

			by

			<select name="sort">
				<option value="target" $sel_sort{target}>target locus</option>
				<option value="source" $sel_sort{source}>source locus</option>
				<option value="score"  $sel_sort{score}>score</option>
			</select>

			and format as

			<select name="export">
				<option value="html" $sel_export{html}>html</option>
				<option value="csv"  $sel_export{csv}>csv</option>
				<option value="tab"  $sel_export{csv}>tab-separated</option>
				<option value="xml"  $sel_export{xml}>xml</option>
			</select>.
			
			</td>
			<td>
				<input type="hidden" name="session" value="$session" />
				<input type="submit" name="submit" value="Change Display" />
			</td>
		</tr>
		<tr>
			<td>
									
			Show

			<select name="batch">
				<option value="50"  $sel_batch{50}>50</option>
				<option value="100" $sel_batch{100}>100</option>
				<option value="200" $sel_batch{200}>200</option>
				<option value="all" $sel_batch{$total_matches}>all</option>
			</select>

			results at a time.
			</td>
		</tr>
	</table>
	</form>

END
	
	return $html;
	
}

sub print_json {

	
#	my $stoplist = join(" ", @stoplist);
#	my $filtertoggle = $filter ? 'on' : 'off';
	

	for my $i (0..$#rec) {

		my $unit_id_target = $rec[$i]{target};
		my $unit_id_source = $rec[$i]{source};
		
		# get the score
		
		my $score = sprintf("%.0f", $match_score{$unit_id_target}{$unit_id_source});

		# a guide to which tokens are marked in each text
	
		my %marked_target;
		my %marked_source;
		
		# THIS MUST BE CHANGED TO CREATE AN ARRAY OF KEYS
		
		my %seen_keys;

		for (keys %{$match_target{$unit_id_target}{$unit_id_source}}) { 
		
			$marked_target{$_} = 1;
		
			$seen_keys{join("-", sort keys %{$match_target{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
		
		for (keys %{$match_source{$unit_id_target}{$unit_id_source}}) {
		
			$marked_source{$_} = 1;

			$seen_keys{join("-", sort keys %{$match_source{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
		
		# format the list of all unique shared words
	
		my $keys = join("; ", keys %seen_keys);
		
		#
		# print one row of the table
		#

		my %record;
		
		
		# target locus
		
		$record{'target'} = $unit_target[$unit_id_target]{LOCUS};
		
		# target phrase
		
		my $phrase = "";
				
		for my $token_id_target (@{$unit_target[$unit_id_target]{TOKEN_ID}}) {
		
			if ($marked_target{$token_id_target}) { $phrase .= "**" }
		
			$phrase .= $token_target[$token_id_target]{DISPLAY};

			if ($marked_target{$token_id_target}) { $phrase .= "**" }
		}
		
		$record{'target_phrase'} = $phrase;
				
		# source locus
		
		$record{'source'} = $unit_source[$unit_id_source]{LOCUS};
		
		# source phrase
		
		$phrase = "";
		
		for my $token_id_source (@{$unit_source[$unit_id_source]{TOKEN_ID}}) {
		
			if ($marked_source{$token_id_source}) { $phrase .= "**" }
		
			$phrase .= $token_source[$token_id_source]{DISPLAY};
			
			if ($marked_source{$token_id_source}) { $phrase .= "**" }
		}

		$record{'source_phrase'} = $phrase;
	
		# keywords
		
		$record{'match'} = $keys;

		# score

		$record{'score'} = $score;
		
		# print row
		
		my $json = encode_json \%record;
		
		print "$json\n";
	}
}

sub print_html {
	
	my $first; 
	my $last;
	
	$first = ($page-1) * $batch;
	$last  = $first + $batch - 1;
	
	if ($last > $total_matches) { $last = $total_matches }
	
	print STDERR "$fs{html}/results.php\n";
	
	my $html = `php -f $fs{html}/results.php` or die $!;
	
	my ($top, $bottom) = split /<!--results-->/, $html;
	
	$top =~ s/<!--pager-->/&nav_page()/e;
	$top =~ s/<!--sorter-->/&re_sort()/e;
	$top =~ s/<!--session-->/$session/;
	
	print $top;

	for my $i ($first..$last) {

		my $unit_id_target = $rec[$i]{target};
		my $unit_id_source = $rec[$i]{source};
						
		# get the score
		
		my $score = sprintf("%.0f", $match_score{$unit_id_target}{$unit_id_source});

		# a guide to which tokens are marked in each text
	
		my %marked_target;
		my %marked_source;
		
		# collect the keys
		
		my %seen_keys;

		for (keys %{$all_match_target{$unit_id_target}{$unit_id_source}}) { 
		
			$marked_target{$_} = 1;
		
			$seen_keys{join("-", sort keys %{$all_match_target{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
		
		for (keys %{$all_match_source{$unit_id_target}{$unit_id_source}}) {
		
			$marked_source{$_} = 1;

			$seen_keys{join("-", sort keys %{$all_match_source{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
		
		# format the list of all unique shared words
	
		my $keys = join(", ", keys %seen_keys);
		
		# utf8 encoded versions of target, source
		
		my $utarget = decode('utf8', $target);
		my $usource = decode('utf8', $source);

		#
		# print one row of the table
		#

		print "  <tr>\n";

		# result serial number

		print "    <td>" . sprintf("%i", $i+1) . ".</td>\n";
		print "    <td>\n";
		print "      <table>\n";
		print "        <tr>\n";
		
		# target locus
		
		print "          <td>\n";
		print "            <a href=\"javascript:;\""
		    . " onclick=\"window.open(link='$url{cgi}/context.pl?target=$utarget;unit=$unit;id=$unit_id_target', "
		    . " 'context', 'width=520,height=240')\">";
		print "$abbr{$target} $unit_target[$unit_id_target]{LOCUS}";
		print "            </a>\n";
		print "          </td>\n";
		
		# target phrase
		
		print "          <td>\n";
		# the problem here is that the token id is sometimes in the previous unit id. 
		my @target_keys_ordered = sort (keys %marked_target);
		my %previous_unit = map { $_ => 1} @{$unit_target[$unit_id_target-1]{TOKEN_ID}};
		my %next_unit = map { $_ => 1} @{$unit_target[$unit_id_target+1]{TOKEN_ID}};
		if (defined $previous_unit{$target_keys_ordered[0]}) {
			for my $token_id_target (@{$unit_target[$unit_id_target-1]{TOKEN_ID}}) {		
				if (defined $marked_target{$token_id_target}) { print '<span class="matched">' }
				print $token_target[$token_id_target]{DISPLAY};
				if (defined $marked_target{$token_id_target}) { print "</span>" }
			}
			print "<br>";
		}
		for my $token_id_target (@{$unit_target[$unit_id_target]{TOKEN_ID}}) {
			if (defined $marked_target{$token_id_target}) { print '<span class="matched">' }
			print $token_target[$token_id_target]{DISPLAY};
			if (defined $marked_target{$token_id_target}) { print "</span>" }
		}
		if (defined $next_unit{$target_keys_ordered[$#target_keys_ordered]}) {		
			print "<br>";
			for my $token_id_target (@{$unit_target[$unit_id_target+1]{TOKEN_ID}}) {
				if (defined $marked_target{$token_id_target}) { print '<span class="matched">' }
				print $token_target[$token_id_target]{DISPLAY};
				if (defined $marked_target{$token_id_target}) { print "</span>" }
			}
			
		}
		print "          </td>\n";
		
		print "        </tr>\n";
		print "      </table>\n";
		print "    </td>\n";
		print "    <td>\n";
		print "      <table>\n";
		print "        <tr>\n";
		
		# source locus
		
		print "          <td>\n";
		print "            <a href=\"javascript:;\""
		    . " onclick=\"window.open(link='$url{cgi}/context.pl?target=$usource;unit=$unit;id=$unit_id_source', "
		    . " 'context', 'width=520,height=240')\">";
		print "$abbr{$source} $unit_source[$unit_id_source]{LOCUS}";
		print "            </a>\n";
		print "          </td>\n";
		
		# source phrase
		
		print "          <td>\n";
		
		my @source_keys_ordered = sort (keys %marked_source);
		my %previous_source_unit = map { $_ => 1} @{$unit_source[$unit_id_source-1]{TOKEN_ID}};
		my %next_source_unit = map { $_ => 1} @{$unit_source[$unit_id_source+1]{TOKEN_ID}};
		if (defined $previous_source_unit{$source_keys_ordered[0]}) {
			for my $token_id_source (@{$unit_source[$unit_id_source-1]{TOKEN_ID}}) {		
				if (defined $marked_source{$token_id_source}) { print '<span class="matched">' }
				print $token_source[$token_id_source]{DISPLAY};
				if (defined $marked_source{$token_id_source}) { print "</span>" }
			}
			print "<br>";
		}
		for my $token_id_source (@{$unit_source[$unit_id_source]{TOKEN_ID}}) {
			if (defined $marked_source{$token_id_source}) { print '<span class="matched">' }
			print $token_source[$token_id_source]{DISPLAY};
			if (defined $marked_source{$token_id_source}) { print "</span>" }
		}
		if (defined $next_source_unit{$source_keys_ordered[$#source_keys_ordered]}) {		
			print "<br>";
			for my $token_id_source (@{$unit_source[$unit_id_source+1]{TOKEN_ID}}) {
				if (defined $marked_source{$token_id_source}) { print '<span class="matched">' }
				print $token_source[$token_id_source]{DISPLAY};
				if (defined $marked_source{$token_id_source}) { print "</span>" }
			}
			
		}
		
		print "          </td>\n";

		print "        </tr>\n";
		print "      </table>\n";
		print "    </td>\n";
		
		# keywords       
				
		print "    <td>$keys</td>\n";

		# score
		
		print "    <td>$score</td>\n";
		
		print "  </tr>\n";
	}

	my $stoplist = join(", ", @stoplist);
	my $filtertoggle = $filter ? 'on' : 'off';
	my $ordertoggle = $word_order ? 'on' : 'off';
	
	$bottom =~ s/<!--session_id-->/$session/;
	$bottom =~ s/<!--source-->/$source/;
	$bottom =~ s/<!--target-->/$target/;
	$bottom =~ s/<!--unit-->/$unit/;
	$bottom =~ s/<!--feature-->/$feature/;
	$bottom =~ s/<!--stoplistsize-->/$stop/;
	$bottom =~ s/<!--stbasis-->/$stoplist_basis/;
	$bottom =~ s/<!--stoplist-->/$stoplist/;
	$bottom =~ s/<!--maxdist-->/$window_size/;
	$bottom =~ s/<!--dibasis-->/$distance_metric/;
	$bottom =~ s/<!--cutoff-->/$cutoff/;
	$bottom =~ s/<!--order-->/$ordertoggle/;
	$bottom =~ s/<!--filter-->/$filtertoggle/;
		
	print $bottom;
}

sub print_delim {

	my $delim = shift;

	#
	# print header with settings info
	#
	
	my $stoplist = join(" ", @stoplist);
	my $filtertoggle = $filter ? 'on' : 'off';
	
	print <<END;
# Tesserae V3 results
#
# session   = $session
# source    = $source
# target    = $target
# unit      = $unit
# feature   = $feature
# stopsize  = $stop
# stbasis   = $stoplist_basis
# stopwords = $stoplist
# max_dist  = $max_dist
# dibasis   = $distance_metric
# cutoff    = $cutoff
# filter    = $filtertoggle

END

	print join ($delim, 
	
		qw(
			"RESULT"
			"TARGET_LOC"
			"TARGET_TXT"
			"SOURCE_LOC"
			"SOURCE_TXT"
			"SHARED"
			"SCORE"
		)
		) . "\n";

	for my $i (0..$#rec) {

		my $unit_id_target = $rec[$i]{target};
		my $unit_id_source = $rec[$i]{source};
		
		# get the score
		
		my $score = sprintf("%.0f", $match_score{$unit_id_target}{$unit_id_source});

		# a guide to which tokens are marked in each text
	
		my %marked_target;
		my %marked_source;
		
		# collect the keys
		
		my %seen_keys;

		for (keys %{$match_target{$unit_id_target}{$unit_id_source}}) { 
		
			$marked_target{$_} = 1;
		
			$seen_keys{join("-", sort keys %{$match_target{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
		
		for (keys %{$match_source{$unit_id_target}{$unit_id_source}}) {
		
			$marked_source{$_} = 1;

			$seen_keys{join("-", sort keys %{$match_source{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
		
		# format the list of all unique shared words
	
		my $keys = join("; ", keys %seen_keys);
		
		#
		# print one row of the table
		#

		my @row;
		
		# result serial number
		
		push @row, $i+1;
		
		# target locus
		
		push @row, "\"$abbr{$target} $unit_target[$unit_id_target]{LOCUS}\"";
		
		# target phrase
		
		my $phrase = "";
				
		for my $token_id_target (@{$unit_target[$unit_id_target]{TOKEN_ID}}) {
		
			if ($marked_target{$token_id_target}) { $phrase .= "**" }
		
			$phrase .= $token_target[$token_id_target]{DISPLAY};

			if ($marked_target{$token_id_target}) { $phrase .= "**" }
		}
		
		push @row, "\"$phrase\"";
				
		# source locus
		
		push @row, "\"$abbr{$source} $unit_source[$unit_id_source]{LOCUS}\"";
		
		# source phrase
		
		$phrase = "";
		
		for my $token_id_source (@{$unit_source[$unit_id_source]{TOKEN_ID}}) {
		
			if ($marked_source{$token_id_source}) { $phrase .= "**" }
		
			$phrase .= $token_source[$token_id_source]{DISPLAY};
			
			if ($marked_source{$token_id_source}) { $phrase .= "**" }
		}
				
		push @row, "\"$phrase\"";
	
		# keywords
		
		push @row, "\"$keys\"";

		# score

		push @row, $score;
		
		# print row
		
		print join($delim, @row) . "\n";
	}
}


sub print_xml {

	#
	# print xml
	#

	# this line should ensure that the xml output is encoded utf-8

	binmode STDOUT, ":utf8";

	# format the stoplist

	my $commonwords = join(", ", @stoplist);

	# add a featureset-specific message

	my %feature_notes = (
	
		word => "Exact matching only.",
		stem => "Stem matching enabled.  Forms whose stem is ambiguous will match all possibilities.",
		syn  => "Stem + synonym matching.  This search is still in development.  Note that stopwords may match on less-common synonyms."
	);

	print STDERR "writing results\n" unless $quiet;

	# draw a progress bar

#	my $pr = ProgressBar->new(scalar(@rec), $quiet);

	# print the xml doc header

	print <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<results 
	source="$source" target="$target" unit="$unit" feature="$feature" 
	sessionID="$session" stop="$stop" stbasis="$stoplist_basis"
	maxdist="$max_dist" dibasis="$distance_metric" cutoff="$cutoff" version="3">
	<comments>V3 results. $meta{COMMENT}</comments>
	<commonwords>$commonwords</commonwords>
END

	# now look at the matches one by one, according to unit id in the target

	for my $i (0..$#rec) {

		my $unit_id_target = $rec[$i]{target};
		my $unit_id_source = $rec[$i]{source};

		# advance the progress bar

		#$pr->advance();
			
		# get the score
	
		my $score = sprintf("%.0f", $match_score{$unit_id_target}{$unit_id_source});

		# a guide to which tokens are marked in each text

		my %marked_target;
		my %marked_source;
	
		# collect the keys
	
		my %seen_keys;

		for (keys %{$match_target{$unit_id_target}{$unit_id_source}}) { 
	
			$marked_target{$_} = 1;
	
			$seen_keys{join("-", sort keys %{$match_target{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
	
		for (keys %{$match_source{$unit_id_target}{$unit_id_source}}) {
	
			$marked_source{$_} = 1;

			$seen_keys{join("-", sort keys %{$match_source{$unit_id_target}{$unit_id_source}{$_}})} = 1;
		}
		
		# format the list of all unique shared words

		my $keys = join(", ", keys %seen_keys);

		#
		# now write the xml record for this match
		#

		print "\t<tessdata keypair=\"$keys\" score=\"$score\">\n";

		print "\t\t<phrase text=\"source\" work=\"$abbr{$source}\" "
				. "unitID=\"$unit_id_source\" "
				. "line=\"$unit_source[$unit_id_source]{LOCUS}\">";

		# here we print the unit

		for my $token_id_source (@{$unit_source[$unit_id_source]{TOKEN_ID}}) {
		
			if (defined $marked_source{$token_id_source}) { print '<span class="matched">' }

			# print the display copy of the token
		
			print $token_source[$token_id_source]{DISPLAY};
		
			# close the tag if necessary
		
			if (defined $marked_source{$token_id_source}) { print '</span>' }
		}

		print "</phrase>\n";
	
		# same as above, for the target now
	
		print "\t\t<phrase text=\"target\" work=\"$abbr{$target}\" "
				. "unitID=\"$unit_id_target\" "
				. "line=\"$unit_target[$unit_id_target]{LOCUS}\">";

		for my $token_id_target (@{$unit_target[$unit_id_target]{TOKEN_ID}}) {
		
			if (defined $marked_target{$token_id_target}) { print '<span class="matched">' }
			print $token_target[$token_id_target]{DISPLAY};
			if (defined $marked_target{$token_id_target}) { print "</span>" }
		}

		print "</phrase>\n";

		print "\t</tessdata>\n";
	}

	# finish off the xml doc

	print "</results>\n";	
}

sub sort_results {
	
	my @rec;
	my @score_;
		
	for my $unit_id_target (sort {$a <=> $b} keys %match_score) {

		for my $unit_id_source (sort {$a <=> $b} keys %{$match_score{$unit_id_target}}) {
			
			push @rec, {target => $unit_id_target, source => $unit_id_source};
		}
	}
	
	if ($sort eq "source") {

		@rec = sort {$$a{source} <=> $$b{source}} @rec;
	}

	if ($sort eq "score") {

		@rec = sort {$match_score{$$a{target}}{$$a{source}} <=> $match_score{$$b{target}}{$$b{source}}} @rec;
	}

	if ($rev) { @rec = reverse @rec };
	
	return \@rec;
}

sub get_stems {

		my ($form, $text) = @_;

		my @stems = ();
		
		my %dictionary;
		
		# load all possible stems
		# if the stem array doesn't exist, use the form

		if ($text eq "target") {
		
			%dictionary = %target_dictionary;
		
		}
		else {
		
			%dictionary = %source_dictionary;
			
		}
		
		unless ($modern == 1) {		

			if ($dictionary{$form}) {

				@stems = @{$dictionary{$form}};

			}

			else {

				$stems[0] = $form;

			}

		}

		else { 
		
		# if the language is modern, it's necessary to use Lingua::Stem
		
			my $stem_ref = stem($form);
		
			@stems = @{$stem_ref};
		
		}
		
		return \@stems;

}
