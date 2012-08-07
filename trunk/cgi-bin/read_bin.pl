#! /usr/bin/perl

# the line below is designed to be modified by configure.pl

use lib '/Users/chris/Sites/tesserae/perl';	# PERL_PATH

#
# read_table.pl
#
# select two texts for comparison using the big table
#

use strict;
use warnings;

use CGI qw(:standard);

use Getopt::Long;
use POSIX;
use Storable qw(nstore retrieve);
use File::Spec::Functions;

use TessSystemVars;
use EasyProgressBar;

# allow unicode output

binmode STDOUT, ":utf8";

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

my $no_cgi = defined($query->request_method()) ? 0 : 1;

#
# command-line options
#

# print debugging messages to stderr?

my $quiet = 0;

# sort algorithm

my $sort = 'target';

# first page of results to display

my $page = 1;

# how many results on a page?

my $batch = 100;

# reverse order ?

my $rev = 0;

# determine file from session id

my $session;

# format for results

my $export = 'html';

#
# command-line arguments
#

GetOptions( 
	'sort=s'    => \$sort,
	'page=i'    => \$page,
	'batch=i'   => \$batch,
	'session=s' => \$session,
	'quiet'     => \$quiet );

#
# cgi input
#

unless ($no_cgi) {
	
	my $query = new CGI || die "$!";

	$session = $query->param('session')    || die "no session specified from web interface";
	$sort       = $query->param('sort')    || $sort;
	$rev        = $query->param('rev')     || $rev;
	$page       = $query->param('page')    || $page;
	$batch      = $query->param('batch')   || $batch;
	$export     = $query->param('export')  || $export;

	my %h = ('-charset'=>'utf-8', '-type'=>'text/html');
	
	if ($export eq "xml") { $h{'-type'} = "text/xml"; $h{'-attachment'} = "tesresults-$session.xml" }
	if ($export eq "csv") { $h{'-type'} = "text/csv"; $h{'-attachment'} = "tesresults-$session.csv" }
	
	print header(%h);
}

my $file;

if (defined $session) {

	$file = catfile($fs_tmp, "tesresults-" . $session . ".bin");
}
else {
	
	$file = shift @ARGV;
}


#
# load the file
#

print STDERR "reading $file\n" unless $quiet;

my %match = %{retrieve($file)};

#
# set some parameters
#

# source means the alluded-to, older text

my $source = $match{META}{SOURCE};

# target means the alluding, newer text

my $target = $match{META}{TARGET};

# unit means the level at which results are returned: 
# - choice right now is 'phrase' or 'line'

my $unit = $match{META}{UNIT};

# feature means the feature set compared: 
# - choice is 'word' or 'stem'

my $feature = $match{META}{FEATURE};

# stoplist

my @stoplist = @{$match{META}{STOPLIST}};

# session id

$session = $match{META}{SESSION};

# total number of matches

my $total_matches = $match{META}{TOTAL};

# notes

my $comments = $match{META}{COMMENT};

# now delete the metadata from the match records 

delete $match{META};

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

my $file_abbr = "$fs_data/common/abbr";
my %abbr = %{ retrieve($file_abbr) };

# language of input texts

my $file_lang = "$fs_data/common/lang";
my %lang = %{retrieve($file_lang)};

# read source text

unless ($quiet) {
	
	print STDERR "reading source data\n";
}

my $path_source = "$fs_data/v3/$lang{$source}/$source";

my @token_source   = @{ retrieve( "$path_source/$source.token"    ) };
my @unit_source    = @{ retrieve( "$path_source/$source.${unit}" ) };
my %index_source   = %{ retrieve( "$path_source/$source.index_$feature" ) };

# read target text

unless ($quiet) {

	print STDERR "reading target data\n";
}

my $path_target = "$fs_data/v3/$lang{$target}/$target";

my @token_target   = @{ retrieve( "$path_target/$target.token"    ) };
my @unit_target    = @{ retrieve( "$path_target/$target.${unit}" ) };
my %index_target   = %{ retrieve( "$path_target/$target.index_$feature" ) };


#
# if the featureset is synonyms, get the parameters used
# to create the synonym dictionary for debugging purposes
#

my $max_heads = "NA";
my $min_similarity = "NA";

if ( $feature eq "syn" ) { 

	($max_heads, $min_similarity) = @{ retrieve("$fs_data/common/$lang{$target}.syn.cache.param") };
}

#
# output
#

if ($export eq "html") {

	print_html($page, $batch);	
}
elsif ($export eq "csv") {
	
}
elsif  ($export eq "xml") {
	
	print_xml();
}


#
# subroutines
#

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
			$back_arrow .= "<a href=\"$url_cgi/read_bin.pl?session=$session;sort=$sort;page=1;batch=$batch\"> [first] </a>\n";
			$back_arrow .= "</span>";

			my $p = $page-1;

			$back_arrow .= "<span>";				
			$back_arrow .= "<a href=\"$url_cgi/read_bin.pl?session=$session;sort=$sort;page=$p;batch=$batch\"> [previous] </a>\n";
			$back_arrow .= "</span>";
		
		
			@left = (($page > 4 ? $page-4 : 1)..$page-1);
		}
	
		if ($page < $pages) {
		
			my $p = $page+1;
		
			$forward_arrow .= "<span>";
			$forward_arrow .= "<a href=\"$url_cgi/read_bin.pl?session=$session;sort=$sort;page=$p;batch=$batch\"> [next] </a>\n";
			$forward_arrow .= "</span>";

			$forward_arrow .= "<span>";
			$forward_arrow .= "<a href=\"$url_cgi/read_bin.pl?session=$session;sort=$sort;page=$pages;batch=$batch\"> [last] </a>\n";		       
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
			
				$html .= "<a href=\"$url_cgi/read_bin.pl?session=$session;sort=$sort;page=$p;batch=$batch\"> $p </a>";
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
	my %sel_export = (html => "", xml => "");
	my %sel_batch  = (50 => '', 100 => '', 200 => '', $total_matches => '');

	$sel_rev[$rev]       = 'selected="selected"';
	$sel_sort{$sort}     = 'selected="selected"';
	$sel_export{$export} = 'selected="selected"';
	$sel_batch{$batch}   = 'selected="selected"';

	my $html=<<END;
	
	<form action="$url_cgi/read_bin.pl" method="post" id="Form1">
		
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

sub print_html {
	
	my $first; 
	my $last;
	
	$first = ($page-1) * $batch;
	$last  = $first + $batch - 1;
	
	if ($last > $total_matches) { $last = $total_matches }
	
	my $html = `php -f $fs_html/results.php`;
	
	my ($top, $bottom) = split /<!--results-->/, $html;
	
	$top =~ s/<!--pager-->/&nav_page()/e;
	$top =~ s/<!--sorter-->/&re_sort()/e;
	$top =~ s/<!--session-->/$session/;
	
	print $top;

	for my $i ($first..$last) {

		my $unit_id_target = $rec[$i]{target};
		my $unit_id_source = $rec[$i]{source};
						
		#
		# print one row of the table
		#
		
		my $score = $match{$unit_id_target}{$unit_id_source}{SCORE};
		my %marked_source = %{$match{$unit_id_target}{$unit_id_source}{MARKED_SOURCE}};
		my %marked_target = %{$match{$unit_id_target}{$unit_id_source}{MARKED_TARGET}};

		# format the list of all unique shared words
	
		my $keys = join(", ", @{$match{$unit_id_target}{$unit_id_source}{KEY}});

		# now write the xml record for this match

		print "  <tr>\n";

		# result serial number

		print "    <td>" . sprintf("%i", $i+1) . ".</td>\n";
		print "    <td>\n";
		print "      <table>\n";
		print "        <tr>\n";
		
		# target locus
		
		print "          <td>\n";
		print "            <a href=\"javascript:;\""
		    . " onclick=\"window.open(link='$url_cgi/context2.pl?target=$target;unit=$unit;id=$unit_id_target', "
		    . " 'context', 'width=520,height=240')\">";
		print "$abbr{$target} $unit_target[$unit_id_target]{LOCUS}";
		print "            </a>\n";
		print "          </td>\n";
		
		# target phrase
		
		print "          <td>\n";
		
		for my $token_id_target (@{$unit_target[$unit_id_target]{TOKEN_ID}}) {
		
			if (defined $marked_target{$token_id_target}) { print '<span class="matched">' }
			print $token_target[$token_id_target]{DISPLAY};
			if (defined $marked_target{$token_id_target}) { print "</span>" }
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
		    . " onclick=\"window.open(link='$url_cgi/context2.pl?target=$source;unit=$unit;id=$unit_id_source', "
		    . " 'context', 'width=520,height=240')\">";
		print "$abbr{$source} $unit_source[$unit_id_source]{LOCUS}";
		print "            </a>\n";
		print "          </td>\n";
		
		# source phrase
		
		print "          <td>\n";
		
		for my $token_id_source (@{$unit_source[$unit_id_source]{TOKEN_ID}}) {
		
			if (defined $marked_source{$token_id_source}) { print '<span class="matched">' }
			print $token_source[$token_id_source]{DISPLAY};
			if (defined $marked_source{$token_id_source}) { print '</span>' }
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
	
	$bottom =~ s/<!--session_id-->/$session/;
	$bottom =~ s/<!--source-->/$source/;
	$bottom =~ s/<!--target-->/$target/;
	$bottom =~ s/<!--comments-->/$comments/;
	
	my $stoplist = join(", ", @stoplist);
	
	$bottom =~ s/<!--stoplist-->/$stoplist/;
	
	print $bottom;
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
		syn  => "Stem + synonym matching.  This search is still in development.  Note that stopwords may match on less-common synonyms.  max_heads=$max_heads; min_similarity=$min_similarity"
	
		);

	print STDERR "writing results\n" unless $quiet;

	# draw a progress bar

	my $pr = $quiet ? 0 : ProgressBar->new(scalar(keys %match));

	# print the xml doc header

	print <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<results source="$source" target="$target" unit="$unit" feature="$feature" sessionID="$session" version="3">
	<comments>V3 results. $feature_notes{$feature}</comments>
	<commonwords>$commonwords</commonwords>
END

	# now look at the matches one by one, according to unit id in the target

	for my $unit_id_target (sort {$a <=> $b} keys %match)
	{

		# advance the progress bar

		$pr->advance() unless $quiet;
	
		# look at all the source units where the feature occurs
		# sort in numerical order

		for my $unit_id_source ( sort {$a <=> $b} keys %{$match{$unit_id_target}})
		{

			# get this parallel's score & marked words from the record

			my $score = $match{$unit_id_target}{$unit_id_source}{SCORE};
			my %marked_source = %{$match{$unit_id_target}{$unit_id_source}{MARKED_SOURCE}};
			my %marked_target = %{$match{$unit_id_target}{$unit_id_source}{MARKED_TARGET}};

			# format the list of all unique shared words
		
			my $keypair = join(", ", @{$match{$unit_id_target}{$unit_id_source}{KEY}});

			# now write the xml record for this match

			print "\t<tessdata keypair=\"$keypair\" score=\"$score\">\n";

			print "\t\t<phrase text=\"source\" work=\"$abbr{$source}\" "
					. "unitID=\"$unit_id_source\" "
					. "line=\"$unit_source[$unit_id_source]{LOCUS}\" "
					. "link=\"$url_cgi/context2.pl?target=$source;unit=$unit;id=$unit_id_source\">";

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
					. "line=\"$unit_target[$unit_id_target]{LOCUS}\" "
					. "link=\"$url_cgi/context2.pl?target=$target;unit=$unit;id=$unit_id_target\">";

			for my $token_id_target (@{$unit_target[$unit_id_target]{TOKEN_ID}}) {
			
				if (defined $marked_target{$token_id_target}) { print '<span class="matched">' }
				print $token_target[$token_id_target]{DISPLAY};
				if (defined $marked_target{$token_id_target}) { print "</span>" }
			}

			print "</phrase>\n";

			print "\t</tessdata>\n";

		}
	}


	# finish off the xml doc

	print "</results>\n";	
}

sub sort_results {
	
	my @rec;
		
	for my $unit_id_target (sort {$a <=> $b} keys %match) {

		for my $unit_id_source (sort {$a <=> $b} keys %{$match{$unit_id_target}}) {
			
			push @rec, {target => $unit_id_target, source => $unit_id_source};
		}
	}
	
	if ($export eq "html") {
	
		if ($sort eq "source") {
	
			@rec = sort {$$a{source} <=> $$b{source}} @rec;
		}
	
		if ($sort eq "score") {
	
			@rec = sort {$match{$$a{target}}{$$a{source}}{SCORE} <=> $match{$$b{target}}{$$b{source}}{SCORE}} @rec;
		}

		if ($rev) { @rec = reverse @rec };
	}
	
	return \@rec;
}