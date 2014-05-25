#!/bin/bash
:<<HISTORIQUE
23/05/2014 - première version
HISTORIQUE

:<<USAGE
Le script est appelé une fois pour créer les différentes tables dans la BDD
USAGE

# si aucun paramètre en entrée on quitte
[ "$1" = "" ] && echo "Syntax: $0 PROJECT_NAME" && exit 1

# variables globales
DB="test"
DELIM=","

function fnCreateTable {
	# creation d'une table vide à partir des entetes du fichier CSV passé en paramètre
	TABLE=$1
	HEADER=$2

	# à partir de la variable HEADER on créé la table 
	FIELDS=$(echo $HEADER | sed -e 's/'$DELIM'/` varchar(255),\n`/g' -e 's/\r//g')
	FIELDS='`'"$FIELDS"'` varchar(255)'
	echo -n "Création de la table " $TABLE " .... "
	mysql -uroot -proot --local-infile --database=$DB -e "
	DROP TABLE IF EXISTS $TABLE;
	CREATE TABLE $TABLE ($FIELDS);"
	echo " terminée"
}

# création de la table dba_feature
HEADER="AUDIT_ID,DBID,NAME,VERSION,DETECTED_USAGES,TOTAL_SAMPLES,CURRENTLY_USED,"
HEADER=$HEADER"FIRST_USAGE_DATE,LAST_USAGE_DATE,AUX_COUNT,FEATURE_INFO,LAST_SAMPLE_DATE,"
HEADER=$HEADER"LAST_SAMPLE_PERIOD,SAMPLE_INTERVAL,DESCRIPTION,HOST_NAME,INSTANCE_NAME,SYSDATE"
fnCreateTable $1"_dba_feature" $HEADER

# création de la table segments
HEADER="AUDIT_ID,OWNER,SEGMENT_TYPE,SEGMENT_NAME,PARTITION_COUNT,PARTITION_MIN,PARTITION_MAX,HOST_NAME,INSTANCE_NAME,SYSDATE"
fnCreateTable $1"_segments" $HEADER

# création de la table version
HEADER="AUDIT_ID,BANNER,HOST_NAME,INSTANCE_NAME,SYSDATE"
fnCreateTable $1"_version" $HEADER

# creation de la table dba_feature_usage (plus complète que dba_feature)
HEADER="HOST_NAME,INSTANCE_NAME,DBA_FEATURE_USAGE_STATISTICS,COUNT,NAME,VERSION,DETECTED_USAGES,TOTAL_SAMPLES,CURRENTLY_USED,FIRST_USAGE_DATE,LAST_USAGE_DATE,LAST_SAMPLE_DATE,SAMPLE_INTERVAL"
fnCreateTable $1"_dba_usage" $HEADER

# creation de la table pour les données OLAP

# création de la table pour les données DB collectées par le script extract.sh
HEADER="HOST_NAME,INSTANCE_NAME,DB_VERSION_MAJ,PLATFORM_NAME,DB_EDITION,DB_CREATED_DATE,"
HEADER=$HEADER"DIAG_PACK_USED,TUNING_PACK_USED,V_OPT_RAC,V_OPT_PART,OLAP_INSTALLED,OLAP_CUBES,ANALYTIC_WORKSPACES,"
HEADER=$HEADER"V_OPT_DM,V_OPT_SPATIAL,V_OPT_ACDG,V_OPT_ADVSEC,V_OPT_LBLSEC,V_OPT_DBV,USERS_CREATED,SESSIONS_HW"
fnCreateTable $1"_db" $HEADER

# ajout de la clé primaire sur cette table HOST_NAME+INSTANCE_NAME
mysql -uroot -proot --local-infile --database=$DB -e "
ALTER TABLE ${1}_db ADD PRIMARY KEY (Host_Name, Instance_Name);"
echo "Création de la clé primaire ... OK"

# creation de la table pour les données serveurs
HEADER="HOST_NAME,OS_RELEASE,MARQUE,MODEL,VIRTUEL,TYPE_PROC,NB_SOCKETS,NB_COEURS,NB_COEURS_TOTAL,"
HEADER=$HEADER"Node_Name,Partition_Name,Partition_Number,Partition_Type,Partition_Mode,"
HEADER=$HEADER"Entitled_Capacity,Active_CPUs_in_Pool,Online_Virtual_CPUs"
fnCreateTable $1"_cpu" $HEADER

# ajout de la clé primaire sur cette table HOST_NAME
mysql -uroot -proot --local-infile --database=$DB -e "
ALTER TABLE ${1}_cpu ADD PRIMARY KEY (Host_Name);"
echo "Création de la clé primaire ... OK"

