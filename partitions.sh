#!/bin/bash
:<<HISTORIQUE
20/05/2014 - insertion des données sur le partitioning dans la base MySQL
22/05/2014 - insersion des données des fichiers versions.csv ds la base
05/08/2014 - insertion des données RAC depuis les fichiers *_options.csv
HISTORIQUE

# si aucun paramètre en entrée on quitte
[ "$1" = "" ] && echo "Syntax: $0 PROJECT_NAME" && exit 1

# variables globales
DB="test"
DELIM=","

function fnRAC {
	# recherche dans les fichiers options.csv des lignes qui contiennent RAC,GV$INSTANCE
	# à partir de ces lignes on va extraire seulement certains champs pour arriver à cette structure :
	# host_name,instance_name,database_name,nodes_count,rac_instance,node_name,node_id,instance_status
	TABLE=$1"_rac"
	TMPFILE="/tmp/rac.csv"
	
	# ensuite on parcourt les fichiers XXX_YYY_options.csv pour les insérer dans la table 
	rm -f $TMPFILE 2>/dev/null
	echo -n "Insertion des données RAC à partir des fichiers XXX_YYY_options.csv dans la table $TABLE : "
	find -type f -iname "*options.csv" | while read f
	do 
		echo -n "."
		cat $f | grep "^GREPME" | grep ",RAC,GV\$INSTANCE" | cut -d',' -f2,3,6,9,11,12,13 >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM';"
	# rm -f $TMPFILE
}

function fnPart {
	# faire des insertions pour chaque fichier lu
	# nom de la table est composé du nom du projet + segments
	TABLE=$1"_segments"
	TMPFILE="/tmp/segement.csv"

	# ensuite on parcourt les fichiers XXX_YYY_segments pour les insérer dans la table 
	rm -f $TMPFILE 2>/dev/null
	echo -n "Insertion des fichiers XXX_YYY_segments.csv dans la table $TABLE : "
	find -type f -iname "*segments.csv" | while read f
	do 
		echo -n "."
		cat $f | grep "^0," >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM';"
	# rm -f $TMPFILE
}

function fnAdminPack {
	# insertion des données sur l'utilisation des packs d'admin
	# les données proviennent des fichiers dba_features.csv
	TABLE=$1"_dba_feature"
	TMPFILE="/tmp/dba_feature.csv"

	echo -n "Insertion des fichiers XXX_YYY_dba_feature.csv dans la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname "*dba_feature.csv" | while read f
	do 
		echo -n "."
		cat $f | grep "^0," | sed 's/"//g' >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}

function fnVersion {
	# insertion des données sur les versions
	# les données proviennent des fichiers version.csv
	SRCFILE="*_version.csv"
	TABLE=$1"_version"
	TMPFILE="/tmp/version.csv"

	echo -n "Insertion des fichiers XXX_YYY_version.csv dans la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat $f | grep "^0," | head -1 | sed 's/"//g' >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}

function fnOlap {
	# insertion des données sur les analytics workspaces
	# les données proviennent des fichiers options.csv 
	SRCFILE="*_options.csv"
	TABLE=$1"_olap"
	TMPFILE="/tmp/olap.csv"

	echo -n "Insertion des données OLAP depuis les fichiers XXX_YYY_options.csv vers la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat $f | grep '^GREPME' | grep 'OLAP,ANALYTIC_WORKSPACES' >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}

fnPart $1
fnAdminPack $1
fnVersion $1
fnOlap $1
fnRAC $1
