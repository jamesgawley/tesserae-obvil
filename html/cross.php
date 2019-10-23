<?php
	$lang = array(
		'target' => 'fr',
		'source' => 'la'
	);
	$selected = array(
		'target' => 'voltaire.henriade.part.1',
		'source' => 'vergil.aeneid'
	);
	$features = array(
		'f2l' => 'French-Latin dictionary'
	);
	$selected_feature = 'f2l';
	$page = 'search';
?>

<?php include "first.php"; ?>
<?php include "nav_search.php"; ?>

</div>
<?php include "nav_lang.php"; ?>
<div id="main">
	
	<h1>French-Latin Search</h1>
	
	<p>
				For explanations of advanced features, see the 
		<a href="<?php echo $url_html . '/help_advanced.php' ?>">Instructions</a> page.

	</p>	

	<script src="<?php echo $url_html . '/tesserae.js' ?>"></script>

	<?php include "advanced.php"; ?>

</div>

<?php include "last.php"; ?>

