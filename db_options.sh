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

function fnSqlProfiles {
	# recherche dans les fichiers options.csv des lignes qui commencent parGREPME et contiennent SQL_PROFILES
	# à partir de ces lignes on va extraire seulement certains champs 
	# exemple des lignes dans le fichier csv
	# GREPME>>,mrs-db-00026,LARA1PRD,2014-07-25_15:21:48,mrs-db-00026,LARA_PRD,OEM~HEADER,SQL_PROFILES~HEADER,48,count,COUNT,NAME,CREATED,LAST_MODIFIED,DESCRIPTION,TYPE,STATUS,
	# exemple avec les champs retenus :
	# LARA1PRD,mrs-db-00026,LARA_PRD,NAME,CREATED,LAST_MODIFIED,DESCRIPTION,TYPE,STATUS,
	# LARA1PRD,mrs-db-00026,LARA_PRD,"SYS_SQLPROF_g2fmwfghgfcdp","2014-05-13_12:10:33","2014-05-13_12:10:33","Plan fix Plan 1561606260 for SQL ID g2fmwfghgfcdp","MANUAL","ENABLED",

	SRCFILE="*options.csv"
	TABLE=$1"_sqlprofiles"
	TMPFILE="/tmp/sqlprofiles.csv"
	
	# ensuite on parcourt les fichiers XXX_YYY_options.csv pour les insérer dans la table 
	rm -f $TMPFILE 2>/dev/null
	echo -n "Insertion des données SQL PROFILES à partir des fichiers XXX_YYY_options.csv dans la table $TABLE : "
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep "^GREPME" | grep ",SQL_PROFILES," | cut -d',' -f3,5,6,12- >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM';"
	# rm -f $TMPFILE

}

function fnRAC {
	# recherche dans les fichiers options.csv des lignes qui contiennent RAC,GV$INSTANCE
	# à partir de ces lignes on va extraire seulement certains champs pour arriver à cette structure :
	# host_name,instance_name,database_name,nodes_count,rac_instance,node_name,node_id,instance_status
	SRCFILE="*options.csv"
	TABLE=$1"_rac"
	TMPFILE="/tmp/rac.csv"
	
	# ensuite on parcourt les fichiers XXX_YYY_options.csv pour les insérer dans la table 
	rm -f $TMPFILE 2>/dev/null
	echo -n "Insertion des données RAC à partir des fichiers XXX_YYY_options.csv dans la table $TABLE : "
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep "^GREPME" | grep ",RAC,GV\$INSTANCE" | cut -d',' -f2,3,6,9,11,12,13 >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM';"
	# rm -f $TMPFILE
}

function fnPart {
	# faire des insertions pour chaque fichier lu
	# nom de la table est composé du nom du projet + segments
	SRCFILE="*segments.csv"
	TABLE=$1"_segments"
	TMPFILE="/tmp/segement.csv"

	# ensuite on parcourt les fichiers XXX_YYY_segments pour les insérer dans la table 
	rm -f $TMPFILE 2>/dev/null
	echo -n "Insertion des fichiers XXX_YYY_segments.csv dans la table $TABLE : "
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep "^0," >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM';"
	# rm -f $TMPFILE
}

function fnAdminPack {
	# insertion des données sur l'utilisation des packs d'admin
	# les données proviennent des fichiers dba_features.csv
	SRCFILE="*dba_feature.csv"
	TABLE=$1"_dba_feature"
	TMPFILE="/tmp/dba_feature.csv"

	echo -n "Insertion des fichiers XXX_YYY_dba_feature.csv dans la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		# le champs description contient des , ce qui pose problème lors de l'insertion
		# car la virgule est aussi le délimiteur de champs
		# on remplace les "," par ";"
		# ensuite on remplace les , par des .
		# et on remet le délimiteur à "," au lieu de ";"
		cat "$f" | grep "^0," | sed 's/,"/;"/g' | sed 's/,//g' | sed 's/;"/,"/g' | sed 's/"//g' >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}

function fnVersion {
	# insertion des données sur les versions
	# les données proviennent des fichiers version.csv
	SRCFILE="*version.csv"
	TABLE=$1"_version"
	TMPFILE="/tmp/version.csv"

	echo -n "Insertion des fichiers XXX_YYY_version.csv dans la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep "^0," | head -1 | sed 's/"//g' >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	rm -f $TMPFILE
	# mise à jour de la table version pour supprimer tout ce qui est derrière le '-' dans la colonne BANNER
	SQL="update $TABLE set banner=substring_index(banner,'-',1)";
	echo $SQL
	mysql -uroot -proot --local-infile --database=$DB -e "$SQL"


}

function fnOlap {
	# insertion des données sur les analytics workspaces
	# les données proviennent des fichiers options.csv 
	SRCFILE="*options.csv"
	TABLE=$1"_olap"
	TMPFILE="/tmp/olap.csv"

	echo -n "Insertion des données OLAP depuis les fichiers XXX_YYY_options.csv vers la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep '^GREPME' | grep 'OLAP,ANALYTIC_WORKSPACES' >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}

function fnSpatial {
	# insertion des données sur les analytics workspaces
	# les données proviennent des fichiers options.csv 
	SRCFILE="*options.csv"
	TABLE=$1"_spatial"
	TMPFILE="/tmp/spatial.csv"

	echo -n "Insertion des données Spatial/Locator depuis les fichiers XXX_YYY_options.csv vers la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep '^GREPME' | grep ',SPATIAL,' | egrep -v '0$|-942$'  >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}

function fnvoption {
	# insertion des données des fichiers v_option.csv
	SRCFILE="*v_option.csv"
	TABLE=$1"_v_option"
	TMPFILE="/tmp/v_option.csv"

	echo -n "Insertion des données des fichiers XXX_YYY_v_option.csv dans la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep '^0,'  >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}

function fnRegistry {
	# insertion des données sur les composants de la vue dba_registry
	# les données proviennent des fichiers options.csv 
	SRCFILE="*options.csv"
	TABLE=$1"_registry"
	TMPFILE="/tmp/registry"

	echo -n "Insertion des données de la vue dba_registry les fichiers XXX_YYY_options.csv vers la table $TABLE : "
	rm -f $TMPFILE 2>/dev/null
	find -type f -iname $SRCFILE | while read f
	do 
		echo -n "."
		cat "$f" | grep '^GREPME' | grep ',DBA_REGISTRY,'  >> $TMPFILE
	done
	echo ""

	mysql -uroot -proot --local-infile --database=$DB -e "
	load data local infile '$TMPFILE' into table $TABLE fields terminated by '$DELIM' ;"
	# rm -f $TMPFILE
}


fnvoption $1
fnPart $1
fnAdminPack $1
fnVersion $1
fnRAC $1
fnSqlProfiles $1
fnOlap $1
fnSpatial $1
fnRegistry $1
