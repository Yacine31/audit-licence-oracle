#!/bin/bash
:<<HISTORIQUE
20/05/2014 - insertion des données sur le partitioning dans la base MySQL
22/05/2014 - insersion des données des fichiers versions.csv ds la base
HISTORIQUE

# si aucun paramètre en entrée on quitte
[ "$1" = "" ] && echo "Syntax: $0 PROJECT_NAME" && exit 1

# variables globales
DB="test"
DELIM=","

function fnCreateTable {
	# creation d'une table vide à partir des entetes du fichier CSV passé en paramètre
	TABLE=$1
	CSV=$2

	# une fois qu'on a le fichier CSV, on récupère la 4ème ligne qui contient les entetes
	FIELDS=$(grep "^AUDIT_ID," "$CSV" | head -1 | sed 's/ /_/g' | sed -e 's/'$DELIM'/` varchar(255),\n`/g' -e 's/\r//g')
	FIELDS='`'"$FIELDS"'` varchar(255)'
	echo -n "Création de la table " $TABLE " .... "
	mysql -uroot -proot --local-infile --database=$DB -e "
	DROP TABLE IF EXISTS $TABLE;
	CREATE TABLE $TABLE ($FIELDS);"
	echo " terminée"

}

function fnPart {
	# dans un premier temps, il faut créer la table avec les entetes des fichiers
	# ensuite faire des insertions pour chaque fichier lu
	# nom de la table est composé du nom du projet + segments
	TABLE=$1"_segments"
	TMPFILE="/tmp/segement.csv"

	# creation de la table à partir d'un fichier XXX_YYY_segments.csv
	# onprend le premier fichier qu'on trouve pour cela :
	CSV=$(find -type f -iname "*segments.csv" | head -1)
	# on appel la fonction pour créer la table
	fnCreateTable $TABLE $CSV


	# ensuite on parcourt les fichiers XXX_YYY_segments pour les insérer dans la table 
	echo -n "Insertion des fichiers XXX_YYY_segments.csv dans la table $TABLE : "
	find -type f -iname "*segments.csv" | while read f
	do 
		echo -n "."
		cat $f | grep "^0," > $TMPFILE
		mysql -uroot -proot --local-infile --database=$DB -e "
		load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM';"
		rm -f $TMPFILE
	done
	echo ""
}

function fnAdminPack {
	# insertion des données sur l'utilisation des packs d'admin
	# les données proviennent des fichiers dba_features.csv
	TABLE=$1"_dba_feature"
	TMPFILE="/tmp/dba_feature.csv"

	# creation de la table à partir d'un fichier XXX_YYY_dba_feature.csv
	# onprend le premier fichier qu'on trouve pour cela :
	CSV=$(find -type f -iname "*dba_feature.csv" | head -1)
	# on appel la fonction pour créer la table
	fnCreateTable $TABLE $CSV

	echo -n "Insertion des fichiers XXX_YYY_dba_feature.csv dans la table $TABLE : "
	find -type f -iname "*dba_feature.csv" | while read f
	do 
		echo -n "."
		cat $f | grep "^0," | sed 's/"//g' > $TMPFILE
		mysql -uroot -proot --local-infile --database=$DB -e "
		load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
		rm -f $TMPFILE
	done
	echo ""
}

function fnVersion {
	# insertion des données sur les versions
	# les données proviennent des fichiers version.csv
	SRCFILE="*_version.csv"
	TABLE=$1"_version"
	TMPFILE="/tmp/version.csv"

	# creation de la table à partir d'un fichier XXX_YYY_version.csv
	# onprend le premier fichier qu'on trouve pour cela :
	CSV=$(find -type f -iname $SRCFILE | head -1)
	# on appel la fonction pour créer la table
	fnCreateTable $TABLE $CSV

	echo -n "Insertion des fichiers XXX_YYY_version.csv dans la table $TABLE : "
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat $f | grep "^0," | sed 's/"//g' > $TMPFILE
		mysql -uroot -proot --local-infile --database=$DB -e "
		load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
		rm -f $TMPFILE
	done
	echo ""
}

fnPart $1
fnAdminPack $1
fnVersion $1