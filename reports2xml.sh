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
export tSpatial=$PROJECT_NAME"_spatial"    # table avec les données OLAP


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

# insertion du header du fichier xml :
print_xml_header $XML_FILE

#--------------------------------------------------------------------------------#
# Infos générales par rapport à l'audit 
#--------------------------------------------------------------------------------#
export SQL="
select '----------------------------------' from dual;
select concat('Nombre de serveurs traités : ', count(*)) from $tCPU;
select '----------------------------------' from dual;
select 'Répartition des serveurs par OS   : ' from dual;

select concat(count(*), ' serveur(s) avec OS : ', left(os, 9)) from $tCPU group by left(os, 9);

select '----------------------------------' from dual;
select concat('Nombre de base de données  : ', count(*)) from $tVersion;
select '----------------------------------' from dual;

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

echo "Les serveurs sans base de données"
export SQL="select Host_Name, os, Marque, Model, Processor_Type 
from $tCPU where host_name not in (SELECT Host_Name FROM $tVersion)
order by Host_Name;
"
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

# export des données 
export_to_xml 

echo "Les serveur sans le résultat de lms_cpuq.sh"
export SQL="SELECT distinct Host_Name FROM $tVersion where Host_Name not in (select Host_Name from $tCPU) order by Host_Name;"

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

# insertion des données de la requête dans le fichier XML
# fonction : "Nom de la feuille (sans espace)" "fichier CSV" "fichier XML"
export_to_xml 
# fermeture de la feuille
close_xml_sheet

#--------------------------------------------------------------------------------#
# Base de données en Standard Edition
#--------------------------------------------------------------------------------#


echo "
#--------------------------------------------------------------------------------#
# Base de données en Standard Edition
#--------------------------------------------------------------------------------#
"

#--------- liste des serveurs avec une instance en SE

echo "Les serveurs en Standard Edition"

export SELECT=" distinct c.physical_server, v.Host_Name, v.instance_name, c.os, c.Marque, c.Model, v.banner"
export FROM="$tVersion v left join $tCPU c on c.Host_Name=v.Host_Name"
export WHERE=" v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%'"
export ORDERBY=" c.physical_server, c.Host_Name, v.instance_name, c.os "

SQL="SELECT $SELECT from $FROM where $WHERE order by $ORDERBY ;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

#--------- insertion des données de la requête dans le fichier XML
export SHEET_NAME=SE
# ouverture d'une feuille Excel
open_xml_sheet
# export des données 
export_to_xml 
# la feuille reste ouverte pour y ajouter le calcul
# la fonction close sera appelée plus tard

#--------- groupement par serveur pour calculer le nombre de sockets

echo "Regroupement par serveur physique pour le calcul des processeurs"

export SELECT=" distinct c.physical_server, c.Marque, c.Model, c.os, c.Processor_Type, c.Socket "
export FROM="$tVersion v left join $tCPU c on c.Host_Name=v.Host_Name"
export WHERE=" v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' "
export GROUPBY=" c.physical_server "
export ORDERBY=" c.physical_server, c.Host_Name, c.os "

SQL="SELECT $SELECT from $FROM where $WHERE group by $GROUPBY order by $ORDERBY ;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

#--------- insertion des données de la requête dans le fichier XML
# feuille déjà ouverte on ajoute le tableau de calcul des sockets
export_to_xml
# fermeture de la feuille
close_xml_sheet

#--------------------------------------------------------------------------------#
# Bases de données en Enterprise Edition
#--------------------------------------------------------------------------------#
echo "
#--------------------------------------------------------------------------------#
# Bases de données en Enterprise Edition
#--------------------------------------------------------------------------------#
"
echo "Les serveurs en Enterprise Edition "

#--------- liste des serveurs avec une instance en SE
export SELECT_EE="distinct c.physical_server, v.Host_Name, v.instance_name, c.OS, c.Processor_Type, v.banner "
export FROM="$tVersion v left join $tCPU c on v.HOST_NAME=c.Host_Name "
export WHERE="v.banner like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' "
export ORDERBY="c.physical_server, c.Host_Name, v.instance_name "

export SQL="select $SELECT_EE from $FROM where $WHERE order by $ORDERBY;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

#--------- insertion des données de la requête dans le fichier XML
export SHEET_NAME=EE
# ouverture d'une feuille Excel
open_xml_sheet
# export des données
export_to_xml

#--------- Calcul des processeurs : OS != AIX
export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, '' as Total_Cores, '' as Core_Factor, '' as Proc_Oracle"
export WHERE="v.banner like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' and c.os not like '%AIX%' "
export ORDERBY="c.physical_server, c.Host_Name, c.os"
# affichage du tableau pour le calcul du nombre de processeur
print_proc_oracle $SELECT_NON_AIX'|'$FROM'|'$WHERE
# export des données
export_to_xml

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

#--------- Calcul des processeurs : OS = AIX
# SELECT_EE_AIX définie plus haut
echo "Caractéristiques des serveurs AIX, la colonne CPU_Oracle correspond au nombre de processeurs Oracle retenus"
export FROM="$tVersion v left join $tCPU c on v.HOST_NAME=c.Host_Name "
export WHERE="v.banner like '%Enterprise%' and v.banner not like '%Personal%' and v.banner not like '%Express%' and c.os like '%AIX%' "

export SQL="select $SELECT_EE_AIX from $FROM where $WHERE order by $ORDERBY ;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

# export des données
export_to_xml

print_proc_oracle_aix $SELECT_EE_AIX'|'$FROM'|'$WHERE

#--------- insertion des données de la requête dans le fichier XML
export_to_xml
# fermeture de la feuille
close_xml_sheet


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
echo "
#--------------------------------------------------------------------------------#
# Option Datamining
#--------------------------------------------------------------------------------#
"
:<<DMCOM
echo "Liste des serveurs avec option DATAMINING en Enterprise Edition"

export FROM="$tCPU c left join $tDB d on c.Host_Name=d.Host_Name"
export WHERE="d.DB_Edition='Enterprise' and c.os not like '%AIX%' and d.v_opt_dm!=''"
export ORDERBY="PHYSICAL_SERVER, c.Host_Name, c.os"

export SQL="select $SELECT_EE_NON_AIX FROM $FROM where $WHERE order by $ORDERBY;"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=DataMining
export_to_xml

export WHERE="d.DB_Edition='Enterprise' and c.os='AIX' and d.v_opt_dm!=''"

export SQL="select $SELECT_EE_AIX FROM $FROM where $WHERE order by $ORDERBY ;"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=DataMining_AIX
export_to_xml

# Option OLAP : calcul des processeurs
export WHERE="d.DB_Edition='Enterprise' and c.os='AIX' and d.v_opt_dm!=''"
export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

export SHEET_NAME=Proc_DM_AIX
print_proc_oracle_aix $SELECT_EE_AIX'|'$FROM'|'$WHERE

DMCOM

#-------------------------------------------------------------------------------
# Option Spatial/Locator
#-------------------------------------------------------------------------------

reports_spatial.sh $PROJECT_NAME

#-------------------------------------------------------------------------------
# Option Active Data Guard
#-------------------------------------------------------------------------------

:<<ADGCOM
echo "
#-------------------------------------------------------------------------------
# Option Active Data Guard
#-------------------------------------------------------------------------------
"
echo "Liste des serveurs avec option Active Data Guard en Enterprise Edition"

export SQL="select $SELECT_EE_NON_AIX
FROM $tDbaFeatures d left join $tCPU c on c.Host_Name=d.Host_Name 
where 
-- d.DB_Edition='Enterprise' and 
(c.os not like '%AIX%' or c.os is null)
and d.name like 'Active Data Guard%'
order by $ORDERBY
;
"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=ActiveDG
export_to_xml

export SQL="select $SELECT_EE_AIX, d.version
FROM $tDbaFeatures d left join $tCPU c on c.Host_Name=d.Host_Name 
where 
-- d.DB_Edition='Enterprise' and 
(c.os like '%AIX%' or c.os is null) 
and d.name like 'Active Data Guard%'
order by $ORDERBY
;
"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=ActiveDG_AIX
export_to_xml


# Option Active Data Guard : calcul des processeurs
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name like '%Active Data Guard%'"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

export SHEET_NAME=Proc_ADG_AIX
print_proc_oracle_aix $SELECT_EE_AIX'|'$FROM'|'$WHERE

ADGCOM

#-------------------------------------------------------------------------------
# Option Tuning Pack
#-------------------------------------------------------------------------------

export TUNING_PACK_FEATURES="'SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile'"
export TUNING_PACK_FEATURES=$TUNING_PACK_FEATURES",'SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)'"

reports_tuning.sh $PROJECT_NAME



#-------------------------------------------------------------------------------
# Option Diagnostics Pack
#-------------------------------------------------------------------------------

export DIAG_PACK_FEATURES="'ADDM','Automatic Database Diagnostic Monitor'"
#,'Automatic Maintenance - SQL Tuning Advisor'"
export DIAG_PACK_FEATURES=$DIAG_PACK_FEATURES",'Automatic Workload Repository','AWR Baseline','AWR Report','Active Session History'"
export DIAG_PACK_FEATURES=$DIAG_PACK_FEATURES",'Diagnostic Pack','EM Performance Page'"

reports_diagnostics.sh $PROJECT_NAME

exit

:<<COMM
export FROM="$tCPU c, $tDB d"
export WHERE="c.Host_Name=d.Host_Name and c.os not like '%AIX%' and d.Tuning_Pack_Used!='0' and d.Diag_Pack_Used='0'"
export ORDREBY="d.db_edition, c.physical_server, c.host_name"

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "
$SELECT_EE_NON_AIX, d.db_edition
FROM $FROM
where $WHERE
order by $ORDERBY
;
"

export WHERE="c.Host_Name=d.Host_Name and c.os='AIX' and d.Tuning_Pack_Used!='0' and d.Diag_Pack_Used='0'"

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "
$SELECT_EE_AIX, d.db_edition
FROM $FROM
where $WHERE
order by $ORDERBY
;"
COMM

# Option Diagnostics Pack : calcul des processeurs
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in ($TUNING_PACK_FEATURES)"
export WHERE=$WHERE" and name not in ($DIAG_PACK_FEATURES) and c.os!='AIX'"

export SHEET_NAME=Proc_Diag2
print_proc_oracle $SELECT_EE_NON_AIX'|'$FROM'|'$WHERE

export WHERE=$WHERE" and name not in ($DIAG_PACK_FEATURES) and c.os='AIX'"

export SHEET_NAME=Proc_Diag2_AIX
print_proc_oracle_aix $SELECT_EE_AIX'|'$FROM'|'$WHERE

#-------------------------------------------------------------------------------
# l'option : Advanced Compression, les composants à vérfier
# 	- SecureFiles (user) 
#-------------------------------------------------------------------------------
echo "
#-------------------------------------------------------------------------------
# l'option : Advanced Compression, les omposants à vérfier
# 	- SecureFiles (user) 
#-------------------------------------------------------------------------------
"
export OAC_FEATURES="('SecureFiles (user)')"
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in $OAC_FEATURES  and c.os!='AIX'"

# Serveurs non AIX
export SQL="select $SELECT_EE_NON_AIX FROM $FROM where $WHERE order by $ORDERBY ;"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=AdvComp
export_to_xml

export SHEET_NAME=Proc_AdvCom
print_proc_oracle $SELECT_EE_NON_AIX'|'$FROM'|'$WHERE

# Serveurs AIX
export WHERE="name in $OAC_FEATURES  and c.os='AIX'"
export SQL="select $SELECT_EE_AIX FROM $FROM where $WHERE order by $ORDERBY;"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=AdvCompAix
export_to_xml

export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in $OAC_FEATURES"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

export SHEET_NAME=Proc_AdvCom_AIX
print_proc_oracle_aix $SELECT_EE_AIX'|'$FROM'|'$WHERE

#-------------------------------------------------------------------------------
# TDE : 
#-------------------------------------------------------------------------------
echo "
#-------------------------------------------------------------------------------
# TDE : 
#-------------------------------------------------------------------------------
"
echo "----------------------------------------------------------------------------------"
echo " Les serveurs qui utilisent des fonctionnalités du pack Oracle Advanced Security :"
echo ""

export ADVANCED_SEC_FEATURES="('Transparent Data Encryption')"

export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in $ADVANCED_SEC_FEATURES"
# export ORDERBY="c.physical_server, c.host_name"

export SQL="select $SELECT_EE_NON_AIX FROM $FROM where $WHERE order by $ORDERBY;"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=AdvSec
export_to_xml

# SErveurs AIX
export SQL="select $SELECT_EE_AIX FROM $FROM where $WHERE order by $ORDERBY;"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=AdvSecAix
export_to_xml

# Option Diagnostics Pack : calcul des processeurs
# print_proc_oracle_aix $WHERE
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in $ADVANCED_SEC_FEATURES"


export SHEET_NAME=Proc_AdvSec_AIX
print_proc_oracle_aix $SELECT_EE_AIX'|'$FROM'|'$WHERE


print_xml_footer $XML_FILE

echo "-------------------------------------------------------------------------------"
echo "Fichier à ouvrir dans Excel : $(pwd)/$XML_FILE"
echo "-------------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# FIN
#-------------------------------------------------------------------------------
