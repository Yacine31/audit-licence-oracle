#!/bin/bash
# interroger les tables pour trouver les infos
# 19/05/2014 - le script est appelé depuis extract.sh
# 20/05/2014 - séparation des affichages pour AIX : les colonnes ne sont pas les mêmes
# 22/05/2014 - modification des jointures (left join) pour prendre en compte les noms des serveurs
#              même si les infos serveurs ne sont pas présentes.
# 23/05/2014 - ajout de MDSYS aux compte exclus du partitioning
#              ajout des listing des bases et serveur par edition
# 22/07/2014 - suppression des détails des bases
#            - le détails est disponible à le demande via le script reports_detail.sh
# 04/08/2014 - ajout du calcul des processeurs pour les serveurs AIX
# 10/08/2014 - export vers XML au format Excel

# MYSQL_ARGS="--defaults-file=/etc/mysql/debian.cnf"

export DEBUG=0

# Inclusion des fonctions
export REP_COURANT="/home/merlin/lms_scripts"
# REP_COURANT=`dirname $0`
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

export PROJECT_NAME="$1"

[ "$PROJECT_NAME" = "" ] && echo "Syntax: $0 PROJECT_NAME" && exit 1

# tDB=$PROJECT_NAME"_db"      # table qui contient les donnees db
export tCPU=$PROJECT_NAME"_cpu"    # table qui contient les donnees des serveurs
export tSegments=$PROJECT_NAME"_segments"  # table qui contient les objets partitionés
export tDbaFeatures=$PROJECT_NAME"_dba_feature"  # table qui contient les options et packs utilisés
export tVersion=$PROJECT_NAME"_version"  # table qui contient les versions
export tCPUAIX=$PROJECT_NAME"_cpu_aix"	  # table pour le calcul des CPUs Oracle pour les serveurs AIX
export tCPUNONAIX=$PROJECT_NAME"_cpu_non_aix"	  # table pour le calcul des CPUs Oracle pour les serveurs AIX
export tRAC=$PROJECT_NAME"_rac"	# table avec les données RAC : nodes_count != 1
export tSQLP=$PROJECT_NAME"_sqlprofiles"	# table avec les données SQL PROFILES
export tOLAP=$PROJECT_NAME"_olap"    # table avec les données OLAP
export tSpatial=$PROJECT_NAME"_spatial"    # table avec les données SPATIAL/LOCATOR
export tVoption=$PROJECT_NAME"_v_option"    # table avec les paramètres v_option
export tDataMining=$PROJECT_NAME"_data_mining"    # table avec les paramètres v_option


#--------------------------------------------------------------------------------#
# calcul des processeurs pour les serveurs AIX
# on créé une nouvelle table avec 3 colonnes supplémentaires :
# - Core_Count : pour avoir le nombre de processeurs retenus en fonction du mode
# - Core_factor : 0,75 ou 1 en fonction du Proc
# - CPU_Oracle : égale Core_Count * Core_Factore 
#--------------------------------------------------------------------------------#
SQL="drop table if exists ${tCPU}_tmp;
create table ${tCPU}_tmp as 
    select *,
        case Partition_Mode
            when 'Uncapped' then least(cast(Active_CPUs_in_Pool as signed), cast(Online_Virtual_CPUs as signed))
            when 'Capped'   then cast(Entitled_Capacity as decimal(4,2))
            when 'Donating' then cast(Entitled_Capacity as decimal(4,2))
        end as Core_Count,
    case left(reverse(Processor_Type),1)
            when 4 then 0.75
            when 5 then 0.75
            when 6 then 1
            when 7 then 1
            when 8 then 1
    end as Core_Factor
    from ${tCPU} 
    order by physical_server, host_name;

alter table ${tCPU}_tmp add column CPU_Oracle int;

update ${tCPU}_tmp set CPU_Oracle=CEILING(cast(Core_Count as decimal(4,2))* cast(Core_Factor as decimal(4,2)));
"
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

# c'est cette table qui va remplacer la table cpu dans la suite du rapport

export tCPU=${tCPU}_tmp

#--------------------------------------------------------------------------------#
# debut du traitement et initialisation du fichier XML
#--------------------------------------------------------------------------------#
export DATE_JOUR=`date +%Y%m%d-%H%M%S`
export TMP_FILE=${PROJECT_NAME}.tmp
export XML_FILE=${PROJECT_NAME}_${DATE_JOUR}.xml
export TXT_FILE=${PROJECT_NAME}_${DATE_JOUR}.txt

# insertion du header du fichier xml :
print_xml_header $XML_FILE

#--------------------------------------------------------------------------------#
# Infos générales par rapport à l'audit 
#--------------------------------------------------------------------------------#

# 
# select OS, count(*) 'Nombre de serveurs' from $tCPU group by os  union select '--- Tous les OS : ---', count(*) from $tCPU;
# 
echo "Statistiques des serveurs et OS :"
export SQL="select OS, count(*) 'Nombre de serveurs' from $tCPU group by os union select '--- Total des serveurs ---', count(*) from $tCPU;"
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL" 

echo "Les bases et les versions :"
export SQL="select banner 'Version', count(*) 'Nombre de bases' from $tVersion group by banner 
union select '--- Total des bases ---', count(*) from $tVersion;"
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL" 

export SQL="
select 'Les bases par editions : ' from dual;
select concat('Personal Edition   : ', count(*)) from $tVersion where banner like '%Oracle%' and banner like '%Personal%' ;
select concat('Express Edition    : ', count(*)) from $tVersion where banner like '%Oracle%' and banner like '%Express%' ;
select concat('Standard Edition   : ', count(*)) from $tVersion where banner like '%Oracle%' and banner not like '%Enterprise%' and banner not like '%Personal%' and banner not like '%Express%' ;
select concat('Enterprise Edition : ', count(*)) from $tVersion where banner like '%Oracle%' and banner like '%Enterprise%' ;
select '----------------------------------' from dual;
"
mysql -ss -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

# ouverture d'une feuille Excel
export SHEET_NAME=Infos
open_xml_sheet
# export des données 
export_to_xml 

# ici on liste les serveurs qui n'ont pas de base de données associées : oubli de passage des scripts ou serveurs qui n'héberge pas de base Oracle
export SQL="select Host_Name, os, Marque, Model, Processor_Type 
from $tCPU where host_name not in (SELECT Host_Name FROM $tVersion)
order by Host_Name;
"
RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo "Les serveurs sans base de données"
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

    # export des données 
    export_to_xml 
fi

# ici on vérifie si tous les serveurs récupérés depuis les fichiers CSV des bases, ont un résultat du script lms_cpuq.
export SQL="SELECT distinct Host_Name FROM $tVersion where Host_Name not in (select Host_Name from $tCPU) order by Host_Name;"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo "Les serveur sans le résultat de lms_cpuq.sh"

    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

    # export des données 
    export_to_xml 
fi

# fermeture de la feuille
close_xml_sheet

#--------------------------------------------------------------------------------#
# Base de données en Standard Edition
#--------------------------------------------------------------------------------#

export SELECT=" distinct c.physical_server, v.Host_Name, v.instance_name, c.os, c.Marque, c.Model, v.banner"
export FROM="$tVersion v left join $tCPU c on c.Host_Name=v.Host_Name"
export WHERE=" v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%'"
export ORDERBY=" c.physical_server, c.Host_Name, v.instance_name, c.os "

SQL="SELECT $SELECT from $FROM where $WHERE order by $ORDERBY ;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi


RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo "#--------------------------------------------------------------------------------#"
    echo "# Base de données en Standard Edition"
    echo "#--------------------------------------------------------------------------------#"

    echo 
    echo "Les serveurs et bases en Standard Edition :"
    echo 
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL" 

    #--------- insertion des données de la requête dans le fichier XML
    export SHEET_NAME=SE
    # ouverture d'une feuille Excel
    open_xml_sheet
    # export des données 
    export_to_xml 
    # la feuille reste ouverte pour y ajouter le calcul
    # la fonction close sera appelée plus tard

    #--------- groupement par serveur pour calculer le nombre de sockets

    echo 
    echo "Regroupement par serveur physique pour le calcul des processeurs :"
    echo 

    export SELECT=" distinct c.physical_server, c.Marque, c.Model, c.os, c.Processor_Type, c.Socket "
    export FROM="$tVersion v left join $tCPU c on c.Host_Name=v.Host_Name"
    export WHERE=" v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' "
    export GROUPBY=" c.physical_server "
    export ORDERBY=" c.physical_server, c.Host_Name, c.os "

    SQL="SELECT $SELECT from $FROM where $WHERE group by $GROUPBY order by $ORDERBY ;"

    if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL" 

    #--------- insertion des données de la requête dans le fichier XML
    # feuille déjà ouverte on ajoute le tableau de calcul des sockets
    export_to_xml
    # fermeture de la feuille
    close_xml_sheet
fi

#--------------------------------------------------------------------------------#
# Bases de données en Enterprise Edition
#--------------------------------------------------------------------------------#

#--------- liste des serveurs avec une instance en SE
export SELECT_EE="distinct c.physical_server, v.Host_Name, v.instance_name, c.OS, c.Processor_Type, v.banner "
export FROM="$tVersion v left join $tCPU c on v.HOST_NAME=c.Host_Name "
export WHERE="v.banner like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' "
export ORDERBY="c.physical_server, c.Host_Name, v.instance_name "

export SQL="select $SELECT_EE from $FROM where $WHERE order by $ORDERBY;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo "#--------------------------------------------------------------------------------#"
    echo "# Bases de données en Enterprise Edition"
    echo "#--------------------------------------------------------------------------------#"

    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

    #--------- insertion des données de la requête dans le fichier XML
    export SHEET_NAME=EE
    # ouverture d'une feuille Excel
    open_xml_sheet
    # export des données
    export_to_xml

    #--------- Calcul des processeurs : OS != AIX
    export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, '' as Core_Factor, '' as Proc_Oracle"
    export WHERE="v.banner like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' and c.os not like '%AIX%' "
    export ORDERBY="c.physical_server, c.Host_Name, c.os"
    
    export SQL="select $SELECT_NON_AIX from $FROM where $WHERE"
    RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
    if [ "$RESULT" != "" ]; then
        # affichage du tableau pour le calcul du nombre de processeur
        print_proc_oracle $SELECT_NON_AIX'|'$FROM'|'$WHERE
        
        # export des données
        export_to_xml

        if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
    fi

    #--------- Calcul des processeurs : OS = AIX
    # SELECT_EE_AIX définie plus haut
    export FROM="$tVersion v left join $tCPU c on v.HOST_NAME=c.Host_Name "
    export WHERE="v.banner like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' and c.os like '%AIX%' "

    export SQL="select $SELECT_EE_AIX from $FROM where $WHERE order by $ORDERBY ;"

    RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
    if [ "$RESULT" != "" ]; then
        if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
        echo "Caractéristiques des serveurs AIX, la colonne CPU_Oracle correspond au nombre de processeurs Oracle retenus"
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

        # export des données
        export_to_xml

        print_proc_oracle_aix $SELECT_EE_AIX'|'$FROM'|'$WHERE

        #--------- insertion des données de la requête dans le fichier XML
        export_to_xml
    fi

    # fermeture de la feuille
    close_xml_sheet
fi

#--------------------------------------------------------------------------------#
# Option RAC 
#--------------------------------------------------------------------------------#

reports_rac.sh $PROJECT_NAME


#--------------------------------------------------------------------------------#
# Option Partitioning
#--------------------------------------------------------------------------------#

reports_partitioning.sh $PROJECT_NAME


#--------------------------------------------------------------------------------#
# Option OLAP
#--------------------------------------------------------------------------------#

reports_olap.sh $PROJECT_NAME

#--------------------------------------------------------------------------------#
# Option Datamining
#--------------------------------------------------------------------------------#

reports_data_mining.sh


#-------------------------------------------------------------------------------
# Option Spatial/Locator
#-------------------------------------------------------------------------------

reports_spatial.sh $PROJECT_NAME

#-------------------------------------------------------------------------------
# Option Active Data Guard
#-------------------------------------------------------------------------------

export ACTIVE_DG_FEATURES="'%Active Data Guard%'"

reports_active_dg.sh $PROJECT_NAME

#-------------------------------------------------------------------------------
# Option Tuning Pack
#-------------------------------------------------------------------------------

export TUNING_PACK_FEATURES="'SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile'"
export TUNING_PACK_FEATURES=$TUNING_PACK_FEATURES",'SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)','Tuning Pack'"
export TUNING_PACK_FEATURES=$TUNING_PACK_FEATURES",'Real-Time SQL Monitoring'"

reports_tuning.sh $PROJECT_NAME



#-------------------------------------------------------------------------------
# Option Diagnostics Pack
#-------------------------------------------------------------------------------

export DIAG_PACK_FEATURES="'ADDM','Automatic Database Diagnostic Monitor'"
export DIAG_PACK_FEATURES=$DIAG_PACK_FEATURES",'Automatic Workload Repository','AWR Baseline','AWR Report','Active Session History'"
export DIAG_PACK_FEATURES=$DIAG_PACK_FEATURES",'Diagnostic Pack','EM Performance Page','Active Session History','EM Notification'"

reports_diagnostics.sh $PROJECT_NAME

#-------------------------------------------------------------------------------
# l'option : Advanced Compression, les composants à vérfier
# 	- SecureFiles (user) 
#	- SecureFile Deduplication (user)
#	- SecureFile Compression (user)
#-------------------------------------------------------------------------------
export ADV_COMP_FEATURES="'SecureFiles (user)','SecureFile Deduplication (user)','SecureFile Compression (user)','Backup BZIP2 Compression'"

reports_adv_compression.sh $PROJECT_NAME

#-------------------------------------------------------------------------------
# Advanced Security
#-------------------------------------------------------------------------------

export ADV_SECURITY_FEATURES="'Transparent Data Encryption','Backup Encryption','SecureFile Encryption (user)'"

reports_adv_security.sh $PROJECT_NAME


#-------------------------------------------------------------------------------
# Real Application Testing
#-------------------------------------------------------------------------------

export RAT_FEATURES="'Database Replay: Workload Capture','Database Replay: Workload Capture','SQL Performance Analyzer'"

reports_rat.sh $PROJECT_NAME

#-------------------------------------------------------------------------------

# fermeture du fichier XML
print_xml_footer $XML_FILE

echo "-------------------------------------------------------------------------------"
echo "Fichier texte : $(pwd)/$TXT_FILE"
echo "Fichier à ouvrir dans Excel : $(pwd)/$XML_FILE"
echo "-------------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# FIN
#-------------------------------------------------------------------------------
