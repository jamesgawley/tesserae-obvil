<?php
	$lang = array(
		'target' => 'la',
		'source' => 'la'
	);
	$selected = array(
		'target' => 'vergil.georgics.part.1',
		'source' => 'catullus.carmina'
	);
	$features = array(
		'word' => 'exact word',
		'stem' => 'lemma',
		'syn'  => 'semantic',
		'syn_lem'  => 'lemma + semantic',		
		'3gr'  => 'sound'
	);
	$selected_feature = 'stem';
	$page = 'search';
?>

<?php include "first.php"; ?>
<?php include "nav_search.php"; ?>

</div>


	
<div id="main">
	
	<p>
		The Tesserae Musivae project aims to combine the search techniques of the <a href="http://tesserae.caset.buffalo.edu/">
		Tesserae Project</a> and <a href="http://mqdq.it/">Musisque Deoque</a> to
		 provide new resources for exploring intertextual parallels in Latin literature. 
		Select two texts below to see a list of lines sharing two or more words (regardless of inflectional changes).
	</p>
	

	<script src="<?php echo $url_html . '/tesserae.js' ?>"></script>

	<?php include "advanced.php"; ?>

</div>

<?php include "last.php"; ?>

