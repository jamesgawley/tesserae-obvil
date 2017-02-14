<?php include "first.php"; ?>
<?php 	$page = 'tools'; ?>
<?php include "nav_search.php"; ?>

			</div>

			<div id="nav_sub2_spacer"></div>
			<div id="main">
				<h1>Other Search Tools</h1>

				<p>
					Here you can try out some searches we're still testing.  We would appreciate any feedback you have.  Caution: results may not be very stable.
				</p>

				<h2><a href="<?php echo $url_html.'/latin-multi-text.php'; ?>">Latin Multi-text search</a></h2>
					
				<p>
					Cross-references discovered parallels against the rest of the Latin corpus.
				</p>
				
				<h2><a href="<?php echo $url_html.'/greek-multi-text.php'; ?>">Greek Multi-text search</a></h2>
					
				<p>
					Cross-references discovered parallels against the rest of the Greek corpus.
				</p>
								
				<h2><a href="<?php echo $url_cgi.'/lsa.pl'; ?>">LSA Search Tool</a></h2>
				
				<p>
					Search for thematic similarities even where phrases have no words in common.
				</p>

				<h2><a href="<?php echo $url_html.'/3gr.php'; ?>">Tri-gram Visualizer</a></h2>
				
				<p>
					Customizable, color-coded visualization of 3-gram concentrations.
				</p>
				
				<h2><a href="<?php echo $url_html.'/full-text.php'; ?>">Full-Text Display</a></h2>
					
				<p>
					Displays the full text of the poems with references highlighted in red.
				</p>

				<h2><a href="<?php echo $url_cgi.'/check-recall.pl'; ?>">Lucan-Vergil Benchmark Test</a></h2>

				<p>
					Allows you to perform a search of Lucan's Pharsalia Book 1 against Vergil's Aeneid,
					and compares the results against our 3000-parallel benchmark set.
				</p>
            
			</div>
		
			<?php include "last.php"; ?>
