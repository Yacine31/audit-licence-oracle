#!/bin/bash

# Inclusion des fonctions
REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

#-------------------------------------------------------------------------------
# Option Advanced Compression
#-------------------------------------------------------------------------------
# l'option : Advanced Compression, les composants à vérfier
#       - SecureFiles (user)
#       - SecureFile Deduplication (user)
#       - SecureFile Compression (user)
#	- Backup BZIP2 Compression
#-------------------------------------------------------------------------------

DEBUG=0

export XML_BUFFER
# on utilise la variable RESULT pour savoir si la requete retourne qq chose avant de passer à l'affichage
export RESULT=""


export SQL="select c.physical_server, d.host_name, d.instance_name, d.name, d.version, 
d.detected_usages, d.last_usage_date, banner
from $tVersion v, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=v.host_name and d.instance_name=v.instance_name
and name in ($ADV_COMP_FEATURES)
and locate('Enterprise', banner) = 0
order by c.physical_server, d.host_name, d.instance_name, d.name"


RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo "#-------------------------------------------------------------------------------"
    echo "# Option Advanced Compression : Standard Edition"
    echo "# ATTENTION : les bases suivantes sont en Standard Edition et utilisent Advanced  Compression"
    echo "#-------------------------------------------------------------------------------"
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"
    echo
    export SHEET_NAME=AdvComp_SE
    # ouverture d'une feuille Excel
    open_xml_sheet
    # export des données
    export_to_xml
    # fermeture de la feuille
    close_xml_sheet
fi

export SQL="select c.physical_server, d.host_name, d.instance_name, d.name, d.version, 
d.detected_usages, d.last_usage_date, banner
from $tVersion v, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=v.host_name and d.instance_name=v.instance_name
and name in ($ADV_COMP_FEATURES)
and locate('Enterprise', banner) > 0
order by c.physical_server, d.host_name, d.instance_name, d.name"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo "Liste des bases qui utilisent Advanced Compression et qui sont en Enterprise Edition"
    echo "#-------------------------------------------------------------------------------"
    echo "# Option Advanced Compression : Enterprise Edition"
    echo "#-------------------------------------------------------------------------------"
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

    export SHEET_NAME=AdvComp_EE
    # ouverture d'une feuille Excel
    open_xml_sheet
    # export des données
    export_to_xml

    #-------------------------------------------------------------------------------
    #--------- Calcul des processeurs : OS != AIX
    #-------------------------------------------------------------------------------
    export SQL="select distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, '' as Core_Factor, '' as Proc_Oracle
    from $tVersion v, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
    where d.host_name=v.host_name and d.instance_name=v.instance_name
    and name in ($ADV_COMP_FEATURES)
    and locate('Enterprise', banner) > 0
    and c.os not like '%AIX%'
    group by c.physical_server 
    order by c.physical_server"

    RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
    if [ "$RESULT" != "" ]; then
	echo "Calcul des processeurs Oracle par serveur physique (OS!=AIX) :"
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

	# export des données
	export_to_xml
    fi


    #-------------------------------------------------------------------------------
    #--------- Calcul des processeurs : OS == AIX
    #-------------------------------------------------------------------------------
    export SELECT=" distinct 
    c.physical_server 'Physical Server',
    c.Host_Name 'Host Name',
    c.OS,
    c.Processor_Type 'Proc Type',
    c.Partition_Type 'Partition Type',
    c.Partition_Mode 'Partition Mode',
    c.Entitled_Capacity 'EC',
    c.Active_CPUs_in_Pool 'ACiP',
    c.Online_Virtual_CPUs 'OVC',
    c.Active_Physical_CPUs 'APC',
    c.Core_Count ,
    c.Core_Factor"
    export FROM=" $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name"
    export WHERE=" d.host_name=a.host_name and d.instance_name=a.instance_name
    and name in ($ADV_COMP_FEATURES)
    and locate('Enterprise', banner) > 0
    and c.os like '%AIX%'"

    export SQL="select $SELECT from $FROM where $WHERE order by c.physical_server"

    RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
    if [ "$RESULT" != "" ]; then
	echo "Calcul des processeurs Oracle par serveur physique (OS=AIX) :"
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

	# export des données
	export_to_xml

	# calcul des processeurs par regroupement des serveurs physiques
	print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE

    fi
    # fermeture de la feuille
    close_xml_sheet
fi

