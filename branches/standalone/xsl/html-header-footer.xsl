<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:variable name="url_cgi" select="'http://tesserae.caset.buffalo.edu/cgi-bin'"/><!-- URL_CGI -->
<xsl:variable name="url_css" select="'http://tesserae.caset.buffalo.edu/css'"/><!-- URL_CSS -->
<xsl:variable name="url_html" select="'http://tesserae.caset.buffalo.edu/html'"/><!-- URL_HTML -->
<xsl:variable name="url_image" select="'http://tesserae.caset.buffalo.edu/images'"/><!-- URL_IMAGE -->
<xsl:variable name="url_text" select="'http://tesserae.caset.buffalo.edu/texts'"/><!-- URL_TEXT -->
	
	<xsl:template match="/">
		<html>
	      <head>
				<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
				<meta name="author" content="Neil Coffee, Jean-Pierre Koenig, Shakthi Poornima, Chris Forstall, Roelant Ossewaarde"/>
				<meta name="keywords" content="inter-text, text analysis, classics, university at buffalo, latin"/>
				<meta name="description" content="Intertext analyzer for Latin texts"/>
				<link rel="stylesheet" type="text/css">
					<xsl:attribute name="href"><xsl:value-of select="concat($url_css, '/style.css')"/></xsl:attribute>
                                </link>
				<link rel="shortcut icon">
					<xsl:attribute name="href"><xsl:value-of select="concat($url_image, '/favicon.ico')"/></xsl:attribute>
				</link>
				
	         <title>Tesserae</title>
	      </head>

	      <body>
            <a name="top"/>

				<div id="container">

					<div id="header"> 
						<div id="title">
							<h1><b>Tesserae</b></h1>
							<h2>Intertextual Phrase Matching</h2>
						</div>

						<div id="nav_main">
							<ul>
								<li>
									<a>
										<xsl:attribute name="href">
											<xsl:value-of select="concat($url_html, '/index.php')"/>
										</xsl:attribute>
										Search Home
									</a>
								</li>
								<li>
									<a>
										<xsl:attribute name="href">
											<xsl:value-of select="concat($url_html, '/help.php')"/>
										</xsl:attribute>
										Help
									</a>
								</li>
								<li>
									<a>
										<xsl:attribute name="href">
											<xsl:value-of select="concat($url_html, '/about.php')"/>
										</xsl:attribute>
										About
									</a>
								</li>
								<li>
									<a>
										<xsl:attribute name="href">
											<xsl:value-of select="concat($url_html, '/research.php')"/>
										</xsl:attribute>
										Research
									</a>
								</li>
							</ul>
						</div>
					</div>
					
					<div id="nav_sub">
						<ul>
							<li>
								<a>
									<xsl:attribute name="href">
										<xsl:value-of select="concat($url_html, '/index.php')"/>
									</xsl:attribute>
									Basic Search
								</a>
							</li>
							<li>
								<a>
									<xsl:attribute name="href">
										<xsl:value-of select="concat($url_html, '/la_table.php')"/>
									</xsl:attribute>
									Advanced Features
								</a>
							</li>
							<li>
								<a>
									<xsl:attribute name="href">
										<xsl:value-of select="concat($url_html, '/legacy.php')"/>
									</xsl:attribute>
									Older Versions
								</a>
							</li>
							<li>
								<a>
									<xsl:attribute name="href">
										<xsl:value-of select="concat($url_html, '/grc_table.php')"/>
									</xsl:attribute>
									Greek
								</a>
							</li>
							<li>
								<a>
									<xsl:attribute name="href">
										<xsl:value-of select="concat($url_html, '/experimental.php')"/>
									</xsl:attribute>
									Experimental
								</a>
							</li>
						</ul>
					</div>
									
	            <xsl:apply-templates select="results"/>
    
					<div style="margin:1em;text-align:left;">
						<a href="#top">Back to top</a>
					</div>

					<div style="margin-left:100px;text-align:left;">
						<h2>Session Details</h2>
						<a name="fullinfo"/>
						<p>
							<b>Session ID: </b>
							<xsl:value-of select="results/@sessionID"/>
						</p>
						<p>
							<b>Source Text: </b>
							<xsl:value-of select="concat($url_text, '/', results/@source, '.tess')"/>

							<br/>

	                  <b>Target Text: </b>
							<xsl:value-of select="concat($url_text, '/', results/@target, '.tess')"/>             
						</p>

						<p>
							<b>Comments: </b>
							<xsl:value-of select="results/comments"/>
						</p>
						<p>
							<b>Stop words: </b>
							<xsl:value-of select="results/commonwords"/>
						</p>
					</div>
				
					<div id="footer">
						<div class="footer_icon_left">
							<img>
								<xsl:attribute name="src">
									<xsl:value-of select="concat($url_image, '/DHIBlogo.png')"/>
								</xsl:attribute>
								<xsl:attribute name="alt">
									DHIB logo
								</xsl:attribute>
							</img>
							<img>
								<xsl:attribute name="src">
									<xsl:value-of select="concat($url_image, '/uccs.png')"/>
								</xsl:attribute>
								<xsl:attribute name="alt">
									VAST Lab logo
								</xsl:attribute>
							</img>
						</div>
						<div class="footer_icon_right">
							<img>
								<xsl:attribute name="src">
									<xsl:value-of select="concat($url_image, '/neh_logo_horizontal_rgb.jpg')"/>
								</xsl:attribute>
								<xsl:attribute name="alt">
									NEH logo
								</xsl:attribute>
							</img>
						</div>
						<div id="footer_content">
							<p> 
								Tesserae is a collaborative project of the 
								<a href="http://www.buffalo.edu">University at Buffalo</a>'s <br />
								<a href="http://www.classics.buffalo.edu"><b>Department of Classics</b></a> and
								<a href="http://linguistics.buffalo.edu"><b>Department of Linguistics</b></a>,<br />
								and the <a href="http://vast.uccs.edu">VAST Lab</a> of the 
								<a href="http://www.uccs.edu/">University of Colorado at Colorado Springs</a>.
							</p>
	   					<p>
								This project is funded by the
								<a href="http://www.neh.gov/ODH/ODHUpdate/tabid/108/EntryId/177/Announcing-22-New-Start-Up-Grant-Awards-March-2012.aspx">
									<b>Office of Digital Humanities</b><br /> 
									of the <b>National Endowment for the Humanities</b>
								</a>
								<br /> and by the 
								<a href="http://digitalhumanities.buffalo.edu/">
									<b>Digital Humanities Initiative at Buffalo</b>
								</a>.<br />
							</p>
							<p>	
								Inquiries or comments about this website should be 
								directed to <br/>
								<a href="mailto:ncoffee@buffalo.edu"> <b>Neil Coffee</b></a> |

								Department of Classics | 338 MFAC | Buffalo, NY 14261<br />

		   					tel: (716) 645-2154 | fax: (716) 645-2225
							</p>
						</div>
					</div>
				</div>					
	      </body>
	   </html>
	</xsl:template>
</xsl:stylesheet>