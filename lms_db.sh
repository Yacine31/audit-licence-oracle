#!/bin/bash -x
:<<HISTORIQUE
19/05/2014 - adaptation du script pour qu'il soit appelé depuis le script extract.sh
20/05/2014 - suppression des sortie d'erreur
HISTORIQUE

:<<README
Postulat de depart :
- collecte des données : 
  + pour chaque base un sous-repertoire a été créé
  + les données collectées par les scripts session.sql et review.sql sont 
    dans les sous répertoires respectifs.
- le script suivant va parcourir les sous-répertoires et générer un fichier csv
- contenu du fichier csv : 
  ${CONNECT_STRING} : chaine de connexion à la base
  ${HOST_NAME}      : nom du serveur
  ${INSTANCE_NAME}  : nom de l instance
  ${DB_VERSION_MIN} : version de la base (10.2.0.4.2, ...)
  ${DB_VERSION_MAJ} : version de la base (7, 8, 9, 10, ...)
  ${PLATFORM_NAME}  : Windows, Linux, HPUX
  ${PLATFORM_TYPE}  : plateforme 32 ou 64 bits
  ${DB_EDITION}     : entreprise/standard/personal
  ${PARTITIONING}   : true/false partitioning utilisé ou pas
  ${DBA_FEATURES}   : nombre d'options dba utilisées / nombre d'options installées
  ${TUNING_PACK}    : les options tuning packs utilisées (true/false)
  ${USERS_CREATED}  : nombre de comptes utilisateurs
README


# DATE_JOUR=`date +%Y.%m.%d-%H.%M.%S`
# OUTPUT_FILE="db_"${DATE_JOUR}".csv"
OUTPUT_FILE=$1

function print_headers {
	# insertion des entetes dans le fichier de sortie :
	echo -e "Host Name;\
	Instance Name;\
	DB Version;\
	Platform Name;\
	DB Edition;\
	DB Creation Date;\
	Diagnostics Pack Used;\
	Tuning Pack Used;\
	RAC;\
	Partitioning;\
	OLAP Installed;\
	OLAP Cubes;\
	Analytic Workspaces;\
	Data Mining;\
	Spatial and Locator;\
	Active DG;\
	Advanced Security;\
	Label Security;\
	Database Vault;\
	Users Created;\
	Sessions HWM" >> $OUTPUT_FILE
}

function print_data {
	# insertion d'une ligne de données dans le fichier OUTPUT_FILE
	echo -e "$HOST_NAME;\
	$INSTANCE_NAME;\
	$DB_VERSION_MAJ;\
	$PLATFORM_NAME;\
	$DB_EDITION;\
	$DB_CREATED_DATE;\
	$DIAG_PACK_USED;\
	$TUNING_PACK_USED;\
	$V_OPT_RAC;\
	$V_OPT_PART;\
	$OLAP_INSTALLED;\
	$OLAP_CUBES;\
	$ANALYTIC_WORKSPACES;\
	$V_OPT_DM;\
	$V_OPT_SPATIAL;\
	$V_OPT_ACDG;\
	$V_OPT_ADVSEC;\
	$V_OPT_LBLSEC;\
	$V_OPT_DBV;\
	$USERS_CREATED;\
	$SESSIONS_HW" >> $OUTPUT_FILE
}


# les noms des fichiers csv générés par le script reviewlite.sql
VERSION_FILE="*version.csv"
OPTIONS_FILE="*options.csv"
DBA_FEATURES_FILE="*dba_feature.csv"
SUMMARY_FILE="*summary.csv"
USERS_FILE="*users.csv"
V_OPTION_FILE="*v_option.csv"
LICENSE_FILE="*license.csv"
SEGMENT_FILE="*segments.csv"

echo "Debut du traitement : fichier de sortie $OUTPUT_FILE"

print_headers

echo "Conversion des fichiers text par dos2unix ..."
find -type f -iname "*csv" -exec dos2unix "{}" \; 2>/dev/null

find -type d | while read dir 
do
	if [ "$dir" == "." ]; then continue; fi
	echo "Traitement du repertoire : $dir"

	# on vérifie si un des fichiers CSV existe, sinon on ne traite pas le répertoire
	# if [ ! -e "${dir}/${dir}_version.csv" ]; then continue; fi

	CONNECT_STRING=`echo $dir | cut -d'/' -f2` 

	INSTANCE_NAME=`cat $dir/$VERSION_FILE | sed '5!d' | cut -d',' -f4`

	HOST_NAME=`cat $dir/$VERSION_FILE | sed '5!d' | cut -d',' -f3`

	DB_EDITION=`cat $dir/$VERSION_FILE | sed '5!d' | egrep -o 'Personal|Enterprise'`
	if [ ! "${DB_EDITION}" ]; then DB_EDITION="Standard"; fi

	DB_CREATED_DATE=`cat $dir/$USERS_FILE | grep '^0,SYSTEM,' | cut -d',' -f6 | cut -d'_' -f1`

	BANNER=`cat $dir/$VERSION_FILE | sed '5!d' | cut -d',' -f2`
	DB_VERSION_MIN=`echo ${BANNER//[a-zA-Z]/ } | cut -d' ' -f3`
	DB_VERSION_MAJ=`echo $DB_VERSION_MIN | cut -d'.' -f1`

	# PLATFORM_TYPE=`echo ${BANNER//[a-zA-Z]/ } | cut -d' ' -f4`
	PLATFORM_NAME=`cat $dir/$VERSION_FILE | grep '^0,"TNS' | cut -d',' -f2 | sed 's/"TNS for //g' | cut -d':' -f1`

	SESSIONS_HW=`cat $dir/$LICENSE_FILE | grep '^0,' | cut -d',' -f5`

	
	#
	# Detail des options Oracle Database Enterprise Management Packs : Diagnostics Pack, Tuning Pack, Change Management Pack, 
	#		Configuration Management Pack, Provisioning Pack, Service Level Management Pack
	# 		Source : http://download.oracle.com/docs/cd/B28359_01/license.111/b28287/options.htm#CIHHAIFB

	#--------------------------------
	# The Tuning Pack :  
	# on compte le nombre de fonctionnalité, si différent de 0 alors TUNING est utilisé
	#--------------------------------
	TUNING_PACK_USED=`cat $dir/$DBA_FEATURES_FILE | grep '^0,' | egrep -i '"SQL Access Advisor"|"SQL Tuning Advisor"|"SQL Plan Management"|"SQL Monitoring"' | wc -l`

	#--------------------------------
	# Diagnostic Pack : 
	# on compte le nombre de fonctionnalité, si différent de 0 alors DIAG est utilisé
	#--------------------------------
	DIAG_PACK_USED=`cat $dir/$DBA_FEATURES_FILE | grep '^0,' | egrep -i 'AWR|"Automatic Workload Repository"|"ADDM"|"Active Session History"|"EM Performance Page"' | wc -l`

	# Change Management Pack features :

	# Configuration Management Pack :

	# Provisioning Pack : 

	# Service Level Management Pack



	# users createad
	# egrep -v pour enlever les comptes système
	USERS_CREATED=`cat $dir/$USERS_FILE | grep '^0' | cut -d, -f2 | egrep -v 'WMSYS|SCOTT|SPATIAL_CSW_ADMIN_USR|OWBSYS|OLAPSYS|SI_INFORMTN_SCHEMAPERFSTAT|WKSYS|TSMSYS|MDDATA|SYS|ORDSYS|ORDPLUGINS|WK_TEST|ORACLE_OCM|XDB|EXFSYS|CTXSYS|DBSNMP|DIP|OWBSYS|FLOWS_FILES|MDSYS|OUTLN' | wc -l`

	#
	# Options Oracle Database Enterprise Edition :
	#

	#--------------------------------
	# Real Application Clusters
	#--------------------------------
	V_OPT_RAC=`cat $dir/$V_OPTION_FILE | grep '^0' | grep "Real Application Clusters" | cut -d',' -f3`
	
	#--------------------------------
	# Partitioning
	# on compte le nombre d'objets partitionés qui n'appartiennent pas à SYS, SYSTEM, SYSMAN, MDSYS
	#--------------------------------
	V_OPT_PART=`cat $dir/$SEGMENT_FILE | grep '^0' | egrep -v ',SYS,|,SYSTEM,|,SYSMAN,|,MDSYS,' | wc -l`
	
	#----------------------
	# OLAP
	#----------------------
	OLAP_INSTALLED=`cat $dir/$OPTIONS_FILE | grep '^ORACLE OLAP INSTALLED' | cut -d: -f2 | sed 's/ *$//g' | sed 's/^ *//g'`
	# les commandes sed enlèvent les espaces en début et en fin de ligne après le résultats (TRUE ou FALSE)
	# ou cette ligne 
	# OLAP_INSTALLED=`cat $dir/$OPTIONS_FILE | grep '^GREPME' | grep '"OLAP"' | cut -d, -f12`
	# Pour OLAP_USED, on récupère le count retourné par l'interrogation de la vue dba_olap_cubes
	OLAP_CUBES=`cat $dir/$OPTIONS_FILE | grep '^GREPME' | grep 'OLAP,DBA_CUBES' | cut -d, -f9`
	# si OLAP_CUBES = 0 ou -942, c est qu'il n y a pas de cube
	# Et on récupère le nombre de workspace analytic créé par un autre compte que SYS
	ANALYTIC_WORKSPACES=`cat $dir/$OPTIONS_FILE | grep '^GREPME' | grep 'OLAP,ANALYTIC_WORKSPACES' | grep -v ',SYS,' | cut -d, -f9 | sort | uniq`
	# si pas de résultat, ou résultat = 0 ou -942, donc aucun workspace
	# sinon des workspaces existent, il faut vérifier
	
	#----------------------
	# Data Mining
	# Data Mining is currently component of Advanced Analytics Enterprise Edition Option
	#----------------------
	V_OPT_DM=`cat $dir/$OPTIONS_FILE | grep '^0' | grep "DATA_MINING~HEADER" | cut -d, -f9 | sort | uniq`
	# si un résultat donc DM est en oeuvre, vérifier pour les comptes qui l'utilise
	# si pas de résultat donc DM n'est pas utilisé

	#----------------------
	# Spatial
	# On récupère le nombre d'objet, si =0 ou -942 donc rien à faire, on élimine ces deux valeur par egrep
	# si différent, donc Spatial ouLocator est utilisé : vérifier plus
	#----------------------
	V_OPT_SPATIAL=`cat $dir/$OPTIONS_FILE | grep '^GREPME' | grep ',SPATIAL,' | cut -d, -f9 | egrep -v '0$|-942$' | uniq`

	# Advanced Security
	V_OPT_ADVSEC=`cat $dir/$V_OPTION_FILE | grep '^0' | grep "Advanced Security" | cut -d',' -f3`

	# Label Security
	V_OPT_LBLSEC=`cat $dir/$V_OPTION_FILE | grep '^0' | grep "Label Security" | cut -d',' -f3`

	# Database Vault
	V_OPT_DBV=`cat $dir/$V_OPTION_FILE | grep '^0' | grep "Database Vault" | cut -d',' -f3`

	# Active Dataguard
	V_OPT_ACDG=`cat $dir/$V_OPTION_FILE | grep '^0' | grep "Active Data Guard" | cut -d',' -f3`

	# écriture des données dans le fichier OUTPUT_FILE
	print_data

done
# mise en forme du fichier de sortie
# suppression des tabulations causées par les commandes echo 
sed -i "s/\t//g" $OUTPUT_FILE
# suppression des lignes vides
sed -i "/^;/d" $OUTPUT_FILE

echo 
echo "Fin du traitement des fichiers CSV"
echo "Fichier de sortie $OUTPUT_FILE"
echo 

function fnPart {
	# dans un premier temps, il faut créer la table avec les entetes des fichiers
	# ensuite faire des insertions pour chaque fichier lu
	# nom de la table, pour l'instant dba_segments
	TABLE="dba_segments"

	# creation de la table à partir d'un fichier XXX_YYY_segments.csv
	# onprend le premier fichier qu'on trouve pour cela :
	CSV=$(find -type f -iname "*segments.csv" | head -1)
	FIELDS=$(head -1 "$CSV" | sed 's/ /_/g' | sed -e 's/'$DELIM'/` varchar(255),\n`/g' -e 's/\r//g')
	FIELDS='`'"$FIELDS"'` varchar(255)'
	mysql -uroot -proot --local-infile --database=test -e "
	DROP TABLE IF EXISTS $TABLE;
	CREATE TABLE $TABLE ($FIELDS);"

	# ensuite on parcourt les fichiers XXX_YYY_segments pour les insérer dans la table 
	echo -n "Insertion des fichiers XXX_YYY_segments dans la table $TABLE : "
	find -type f -iname "*segments.csv" | while read f
	do 
		echo -n ". "
		cat $f | sed '1,5d' > /tmp/segement.csv
		mysql -uroot -proot --local-infile --database=test -e "
		load data local infile '/tmp/segement.csv' into table ipsen_segments fields terminated by ',';"
		rm -f /tmp/segement.csv
	done
	echo ""
}
