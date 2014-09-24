#!/bin/bash

# Inclusion des fonctions
# REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh


#--------------------------------------------------------------------------------#
# Option RAC 
#--------------------------------------------------------------------------------#
echo "
#--------------------------------------------------------------------------------#
# Option RAC 
#--------------------------------------------------------------------------------#
"
DEBUG=0

#--- tous les serveurs et tous les OS :
echo "Les serveurs avec option RAC en Enterprise Edition"

export SELECT="distinct 
c.physical_server 'Physical Server',
r.node_name 'Node name',
r.database_name 'Database Name',
r.rac_instance 'Instance Name',
if(locate('Enterprise', banner)>0, 'Enterprise', 'Standard') Edition,
r.node_id 'Node ID', 
c.Model,
c.OS,
c.Processor_Type"
export FROM="$tVersion v, $tRAC r left join $tCPU c on r.node_name=c.host_name"
export WHERE="r.node_name=v.host_name and r.nodes_count > 1 and locate('Enterprise', banner)>0"
export ORDERBY="c.physical_server, r.database_name, r.instance_name, r.node_name"

export SQL="select $SELECT from $FROM where $WHERE order by $ORDERBY;"


if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

export SHEET_NAME=RAC
# ouverture d'une feuille Excel
open_xml_sheet
# export des données
export_to_xml

# insertion des données de la requête dans le fichier XML
export WHERE="r.node_name=v.host_name and r.nodes_count > 1 and locate('Enterprise', banner)>0 and c.os not like '%AIX%'"
export SQL="select $SELECT from $FROM where $WHERE order by $ORDERBY;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

# export des données
export_to_xml

#--------- Calcul des processeurs : OS != AIX
export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, '' as Total_Cores, '' as Core_Factor, '' as Proc_Oracle"
export FROM="$tVersion v, $tRAC r left join $tCPU c on r.node_name=c.host_name"
export WHERE="r.node_name=v.host_name and r.nodes_count > 1 and locate('Enterprise', banner)>0 and c.os not like '%AIX%'"
export ORDERBY="c.physical_server"

# affichage du tableau pour le calcul du nombre de processeur
print_proc_oracle $SELECT_NON_AIX'|'$FROM'|'$WHERE

# export des données
export_to_xml



# ---- Les serveurs OS == 'AIX' :
export SELECT="distinct 
c.physical_server 'Physical Server',
c.Host_Name 'Host Name',
r.node_name 'Node name',
if(locate('Enterprise', banner)>0, 'Enterprise', 'Standard') Edition,
-- c.Model,
c.OS,
c.Processor_Type 'Proc Type',
c.Partition_Type 'Partition Type',
c.Partition_Mode 'Partition Mode',
c.Entitled_Capacity 'EC',
c.Active_CPUs_in_Pool 'ACiP',
c.Online_Virtual_CPUs 'OVC',
c.Active_Physical_CPUs 'APC',
c.Core_Count ,
c.Core_Factor ,
c.CPU_Oracle"

export FROM="$tVersion v, $tRAC r left join $tCPU c on r.node_name=c.host_name"
export WHERE="r.node_name=v.host_name and r.nodes_count > 1 and locate('Enterprise', banner)>0 and c.os like '%AIX%'"
export ORDERBY="c.physical_server, r.node_name;"

export SQL="select $SELECT from $FROM where $WHERE order by $ORDERBY;"
if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

# Option RAC : calcul des processeurs
# export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"
# export WHERE="d.DB_Edition='Enterprise' and d.v_opt_rac!=0 and c.os='AIX'"

# Base de données en Enterprise Edition : calcul des processeurs pour serveurs AIX
print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE
# export des données
export_to_xml
# fermeture de la feuille
close_xml_sheet
