#!/bin/bash

# ---------------------------------
# 15/08/2014 - Création
# ---------------------------------

#--------------------------------------------------------------------------------#
# les fonction suivantes permettent d'écrire le fichier XML
# qui sera lu par Excel
#--------------------------------------------------------------------------------#

#--------------------------------------------------------------------------------#
# entete du fichier xml : à insérer une seule fois dans le fichier XML de sortie
#--------------------------------------------------------------------------------#
function print_xml_header {
echo "<?xml version=\"1.0\"?>
<?mso-application progid=\"Excel.Sheet\"?>
<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"
 xmlns:o=\"urn:schemas-microsoft-com:office:office\"
 xmlns:x=\"urn:schemas-microsoft-com:office:excel\"
 xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\"
 xmlns:html=\"http://www.w3.org/TR/REC-html40\">
 <DocumentProperties xmlns=\"urn:schemas-microsoft-com:office:office\">
  <Version>14.00</Version>
 </DocumentProperties>
 <OfficeDocumentSettings xmlns=\"urn:schemas-microsoft-com:office:office\">
  <AllowPNG/>
 </OfficeDocumentSettings>
 <Styles>
  <Style ss:ID=\"Default\" ss:Name=\"Normal\">
   <Alignment ss:Vertical=\"Bottom\"/>
   <Font ss:FontName=\"Calibri\" x:Family=\"Swiss\" ss:Size=\"10\" ss:Color=\"#000000\"/>
  </Style>
 <Style ss:ID=\"TableauTexte\">
   <Borders>
    <Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
   </Borders>
  </Style>
  <Style ss:ID=\"TableauEntete\">
   <Alignment ss:Horizontal=\"Center\" ss:Vertical=\"Bottom\"/>
   <Borders>
    <Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
   </Borders>
   <Font ss:FontName=\"Calibri\" x:Family=\"Swiss\" ss:Size=\"11\" ss:Color=\"#000000\" ss:Bold=\"1\"/>
   <Interior ss:Color=\"#92D050\" ss:Pattern=\"Solid\"/>
  </Style>
  </Styles>" >> $XML_FILE
}

#--------------------------------------------------------------------------------#
# dernière balise : fin du fichier xml :                                         
#           à insérer une seule fois dans le fichier XML de sortie               
#--------------------------------------------------------------------------------#
function print_xml_footer {
	echo "</Workbook>" >> $XML_FILE
}

#--------------------------------------------------------------------------------#
# insertion de l'entete de la feuille excel
# cela permet d'ouvir une feuille pour y insérer plusieurs tableaux
# avant d'appeler la fonction close pour fermer les balises table et worksheet
#--------------------------------------------------------------------------------#

function open_xml_sheet {
# remplacer le séparateur par défaut \t par |
# sed -ie 's/\t/|/g' $TMP_FILE

echo " <Worksheet ss:Name=\"$SHEET_NAME\">
  <Table>" >> $XML_FILE
}

#--------------------------------------------------------------------------------#
# à partir d'un fichier csv on insère dans le fichier XML : balise Worksheet     
# 3 paramètres : nom de la feuille, fichier csv source et fichier xml destination
#--------------------------------------------------------------------------------#

function print_xml_sheet {

# remplacer le séparateur par défaut \t par |
sed -ie 's/\t/|/g' $TMP_FILE

# echo " <Worksheet ss:Name=\"$SHEET_NAME\">
#   <Table>" >> $XML_FILE

# insertion d'une ligne vide
echo "<Row></Row>"    >> $XML_FILE
# insertion de l'entete d'abord : les noms des colonnes
echo "<Row>"    >> $XML_FILE
head -1 $TMP_FILE | tr '|' '\n' | while read c
do
        echo "<Cell ss:StyleID=\"TableauEntete\"><Data ss:Type=\"String\">$c</Data></Cell>"  >> $XML_FILE
done

# fin du header
echo "</Row>"   >> $XML_FILE

# insertion des données  : sed '1d' supprime la ligne qui contient l'entete
cat $TMP_FILE | sed '1d' | while read line
do
	echo "<Row>"  >> $XML_FILE
	# pour chaque ligne on va lire les champs et les insérer
	echo $line | tr '|' '\n' | while read c
	do
		# un test pour définir le format String ou Number
		pattern='^[0-9]+([.][0-9]+)?$'         # le pattern recherche des nombres sous la forme 12.3445
		if ! [[ $c =~ $pattern ]] ; then
			# $c n'est pas un nombre => Type=String
			echo "<Cell ss:StyleID=\"TableauTexte\"><Data ss:Type=\"String\">$c</Data></Cell>"   >> $XML_FILE
		else
			# $c est un nombre => Type=Number
			echo "<Cell ss:StyleID=\"TableauTexte\"><Data ss:Type=\"Number\">$c</Data></Cell>"   >> $XML_FILE
		fi
	done
	echo "</Row>"   >> $XML_FILE
done

# suppression du fichier temporaire
rm -f $TMP_FILE

# echo "</Table>
#</Worksheet>" >> $XML_FILE

}


#--------------------------------------------------------------------------------#
# fermeture des balise de la feuille excel
#--------------------------------------------------------------------------------#

function close_xml_sheet {
echo "</Table>
</Worksheet>" >> $XML_FILE
}

#--------------------------------------------------------------------------------#
# Export des résultats vers un fichier XML
#--------------------------------------------------------------------------------#

function export_to_xml {
# export du résulat pour Excel

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL" > $TMP_FILE

# si fichier TMP_FILE pas vide, donc il y a des résultats retourné par la requête SQL
if [ -s $TMP_FILE ]
then
	# insertion des données de la requête dans le fichier XML
	print_xml_sheet $SHEET_NAME $TMP_FILE $XML_FILE
fi
}

#--------------------------------------------------------------------------------#
# Export des résultats vers un tampon XML
#--------------------------------------------------------------------------------#

function write_xml_buffer {

  mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL" >> $TMP_FILE

  # si fichier TMP_FILE pas vide, donc il y a des résultats retourné par la requête SQL
  if [ -s $TMP_FILE ]
  then
    # insertion des données de la requête dans le fichier XML
    print_xml_sheet $SHEET_NAME $TMP_FILE $XML_FILE
  fi
}