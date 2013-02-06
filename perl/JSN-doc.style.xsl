<-- http://sagehill.net/docbookxsl/CustomMethods.html#CustomizationLayer -->
<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="html/docbook.xsl"/>

  <xsl:attribute-set name="monospace.properties">
    <xsl:attribute name="font-size">10pt</xsl:attribute>
  </xsl:attribute-set>

  <xsl:param name="html.stylesheet" select="'corpstyle.css'"/>
  <xsl:param name="admon.graphics" select="1"/>
</xsl:stylesheet>
