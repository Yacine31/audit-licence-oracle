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
	echo -n "Création de la table $TABLE .... "
	mysql -uroot -proot --local-infile --database=$DB -e "
	DROP TABLE IF EXISTS $TABLE;
	CREATE TABLE $TABLE ($FIELDS);"
	echo " terminée"
}

function fnAddPrimaryKey {
	# ajout d'une clé primaire sur une table
	TABLE=$1
	KEY=$2
	
	# TODO : ajouter la vérification des paramètres 
	echo -n "Ajout de la clé primaire ($KEY) à la table $TABLE ... "
	mysql -uroot -proot --local-infile --database=$DB -e "
	ALTER TABLE $TABLE ADD PRIMARY KEY ($KEY);"
	echo " terminé"

}

# création de la table sqlprofiles
TABLE=$1"_sqlprofiles"
HEADER="instance_name,host_name,database_name,name,created,last_modified,description,type,status"
fnCreateTable $TABLE $HEADER


# création de la table rac
TABLE=$1"_rac"
HEADER="host_name,instance_name,database_name,nodes_count,rac_instance,node_name,node_id,instance_status"
fnCreateTable $TABLE $HEADER

# création de la table dba_feature
TABLE=$1"_dba_feature"
HEADER="AUDIT_ID,DBID,NAME,VERSION,DETECTED_USAGES,TOTAL_SAMPLES,CURRENTLY_USED,"
HEADER=$HEADER"FIRST_USAGE_DATE,LAST_USAGE_DATE,AUX_COUNT,FEATURE_INFO,LAST_SAMPLE_DATE,"
HEADER=$HEADER"LAST_SAMPLE_PERIOD,SAMPLE_INTERVAL,DESCRIPTION,HOST_NAME,INSTANCE_NAME,SYSDATE"
fnCreateTable $TABLE $HEADER

# création de la table segments
TABLE=$1"_segments"
HEADER="AUDIT_ID,OWNER,SEGMENT_TYPE,SEGMENT_NAME,PARTITION_COUNT,PARTITION_MIN,PARTITION_MAX,HOST_NAME,INSTANCE_NAME,SYSDATE"
fnCreateTable $TABLE $HEADER

# création de la table version
TABLE=$1"_version"
HEADER="AUDIT_ID,BANNER,HOST_NAME,INSTANCE_NAME,SYSDATE"
fnCreateTable $TABLE $HEADER

# ajout de la clé sur la table version : host + instance
KEY=HOST_NAME,INSTANCE_NAME
fnAddPrimaryKey $TABLE $KEY

# creation de la table dba_feature_usage (plus complète que dba_feature)
TABLE=$1"_dba_usage"
HEADER="HOST_NAME,INSTANCE_NAME,DBA_FEATURE_USAGE_STATISTICS,COUNT,NAME,VERSION,DETECTED_USAGES,TOTAL_SAMPLES,CURRENTLY_USED,FIRST_USAGE_DATE,LAST_USAGE_DATE,LAST_SAMPLE_DATE,SAMPLE_INTERVAL"
fnCreateTable $TABLE $HEADER

# creation de la table pour les données OLAP

# création de la table pour les données DB collectées par le script extract.sh
TABLE=$1"_db"
HEADER="HOST_NAME,INSTANCE_NAME,DB_VERSION_MAJ,PLATFORM_NAME,DB_EDITION,DB_CREATED_DATE,"
HEADER=$HEADER"DIAG_PACK_USED,TUNING_PACK_USED,V_OPT_RAC,V_OPT_PART,OLAP_INSTALLED,OLAP_CUBES,ANALYTIC_WORKSPACES,"
HEADER=$HEADER"V_OPT_DM,V_OPT_SPATIAL,V_OPT_ACDG,V_OPT_ADVSEC,V_OPT_LBLSEC,V_OPT_DBV,USERS_CREATED,SESSIONS_HW"
fnCreateTable $TABLE $HEADER

# ajout de la clé primaire sur cette table HOST_NAME+INSTANCE_NAME
KEY=HOST_NAME,INSTANCE_NAME
fnAddPrimaryKey $TABLE $KEY

#mysql -uroot -proot --local-infile --database=$DB -e "
#ALTER TABLE ${1}_db ADD PRIMARY KEY (Host_Name, Instance_Name);"
#echo "Création de la clé primaire ... OK"

# creation de la table pour les données serveurs
TABLE=$1"_cpu"
HEADER="PHYSICAL_SERVER,Host_Name,OS,Marque,Model,Virtuel,Processor_Type,Socket,Cores_per_Socket,Total_Cores,"
HEADER=$HEADER"Node_Name,Partition_Name,Partition_Number,Partition_Type,Partition_Mode,Entitled_Capacity,Active_CPUs_in_Pool,Online_Virtual_CPUs,Machine_Serial_Number,Active_Physical_CPUs"
fnCreateTable $TABLE $HEADER

# ajout de la clé primaire sur cette table HOST_NAME
KEY=Host_Name
fnAddPrimaryKey $TABLE $KEY

# creation de la table pour les serveurs physiques
TABLE=$1"_pservers"
HEADER="Physical_Server,Socket,Cores_per_Socket"
fnCreateTable $TABLE $HEADER
# ajout de la clé primaire
KEY=Physical_Server
fnAddPrimaryKey $TABLE $KEY


# creation de la table pour les données OLAP
TABLE=$1"_olap"
HEADER="GREPME,Host_Name,Instance_Name,Sysdate,Host_name_2,Instance_Name_2,Olap_Header,ANALYTIC_WORKSPACES_HEADER,Count_Nbr,Count_Txt,OWNER,AW_NUMBER,AW_NAME,PAGESPACES,GENERATIONS"
fnCreateTable $TABLE $HEADER
# ajout de la clé primaire
KEY=host_name,instance_name,OWNER,AW_NAME
fnAddPrimaryKey $TABLE $KEY

# creation de la table pour les données Spatial
TABLE=$1"_spatial"
HEADER="GREPME,Host_Name,Instance_Name,Sysdate,Host_name_2,Instance_Name_2,Spatial,Metadata,Count_Nbr,Count_Txt,OWNER,name,geometry"
fnCreateTable $TABLE $HEADER
# ajout de la clé primaire sur cette table 
KEY=HOST_NAME,INSTANCE_NAME,OWNER,NAME
fnAddPrimaryKey $TABLE $KEY

