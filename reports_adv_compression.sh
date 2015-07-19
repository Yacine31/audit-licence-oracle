#!/bin/bash

# Inclusion des fonctions
#export SCRIPTS_DIR="/home/merlin/lms_scripts"
. ${SCRIPTS_DIR}/fonctions.sh
. ${SCRIPTS_DIR}/fonctions_xml.sh

#-------------------------------------------------------------------------------
# Option Advanced Compression
#-------------------------------------------------------------------------------
# l'option : Advanced Compression, les composants à vérfier
#       - SecureFiles (user)
#       - SecureFile Deduplication (user)
#       - SecureFile Compression (user)
#	- Backup BZIP2 Compression
#	- Oracle Utility Datapump (Export)
#-------------------------------------------------------------------------------

DEBUG=0

export XML_BUFFER
# on utilise la variable RESULT pour savoir si la requete retourne qq chose avant de passer à l'affichage
export RESULT=""
export NOTIN="('SYSMAN')"

export SQL="select c.physical_server, d.host_name, d.instance_name, d.name, d.version, 
d.detected_usages, d.last_usage_date, banner
from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=a.host_name and d.instance_name=a.instance_name
and name in ($ADV_COMP_FEATURES)
and locate('Enterprise', banner) = 0
order by c.physical_server, d.host_name, d.instance_name, d.name"


RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo $YELLOW
    echo "#-------------------------------------------------------------------------------"
    echo "# Option Advanced Compression : Standard Edition"
    echo $RED
    echo "# ATTENTION : les bases suivantes sont en Standard Edition et utilisent Advanced Compression"
    echo $YELLOW
    echo "# les informations suivantes viennent de la vue dba_feature_usage_statistics"
    echo "#-------------------------------------------------------------------------------"
    echo $NOCOLOR
    
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"
    echo
    export SHEET_NAME=AdvComp_SE
    # ouverture d'une feuille Excel
    open_xml_sheet

    # export des données
    print_to_xml "Option Advanced Compression : Standard Edition"
    print_to_xml "ATTENTION : les bases suivantes sont en Standard Edition et utilisent Advanced Compression"
    print_to_xml "les informations suivantes viennent de la vue dba_feature_usage_statistics"
    export_to_xml

    # list des objets pour vérifier si ce n'est pas SYSMAN qui utilise l'option
    SQL="select Host_Name, Instance_Name, table_name, table_Owner, compression, compression_for from $tAdvCompression order by 1, 2, 3;"

    echo ""
    echo $RED
    echo "# Standard Edition - SecureFiles(user): list des objets pour vérifier si ce n'est pas SYSMAN qui utilise l'option"
    echo $NOCOLOR
    echo ""
 
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"
    echo

    # export des données
    print_to_xml "Standard Edition - SecureFiles(user): list des objets pour vérifier si ce n'est pas SYSMAN qui utilise l'option"
    export_to_xml
    # fermeture de la feuille
    close_xml_sheet
fi

export ADV_SEC_FEATURES_1="('SecureFile Deduplication (user)','SecureFile Compression (user)','Backup BZIP2 Compression','Oracle Utility Datapump (Export)')"
export ADV_SEC_FEATURES_2="'SecureFiles (user)'"
export NOT_IN="'SYSMAN'"

# pour l'option SecureFiles (user) : le compte SYSMAN n'est pas pris en compte, même si l'entrée est reportées dans la vue dba_feature (bug Oracle)
# d'où la syntaxe sql avec union de deux blocs

export SQL="select c.physical_server, d.host_name, d.instance_name, d.name, d.version,
d.detected_usages, d.last_usage_date, banner
from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=a.host_name and d.instance_name=a.instance_name
and name in $ADV_SEC_FEATURES_1
and locate('Enterprise', banner) > 0
union
select c.physical_server, d.host_name, d.instance_name, d.name, d.version,
d.detected_usages, d.last_usage_date, banner
from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=a.host_name and d.instance_name=a.instance_name
and name = $ADV_SEC_FEATURES_2
and locate('Enterprise', banner) > 0
and $NOT_IN not in (select table_owner from $tAdvCompression where host_name=d.host_name and instance_name=d.instance_name)
order by physical_server, host_name, instance_name, name"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG - $0 ] - $SQL"; fi
RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo $YELLOW
    echo "Liste des bases qui utilisent Advanced Compression et qui sont en Enterprise Edition"
    echo "#-------------------------------------------------------------------------------"
    echo "# Option Advanced Compression : Enterprise Edition"
    echo "# les informations suivantes viennent de la vue dba_feature_usage_statistics"
    echo "#-------------------------------------------------------------------------------"
    echo $NOCOLOR

    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

    export SHEET_NAME=AdvComp_EE
    # ouverture d'une feuille Excel
    open_xml_sheet
    print_to_xml "Liste des bases qui utilisent Advanced Compression et qui sont en Enterprise Edition"
    print_to_xml "Option Advanced Compression : Enterprise Edition"
    print_to_xml "les informations suivantes viennent de la vue dba_feature_usage_statistics"

    # list des objets pour vérifier si ce n'est pas SYSMAN qui utilise l'option
    SQL="select Host_Name, Instance_Name, table_name, table_Owner, compression, compression_for from $tAdvCompression order by 1, 2, 3;"

    echo ""
    echo $RED
    echo "# Enterprise Edition - SecureFiles(user): list des objets pour vérifier si ce n'est pas SYSMAN qui utilise l'option"
    echo $NOCOLOR
    echo ""

    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"
    echo

    # export des données
    print_to_xml "Enterprise Edition - SecureFiles(user): list des objets pour vérifier si ce n'est pas SYSMAN qui utilise l'option"
    # export des données
    export_to_xml

    #-------------------------------------------------------------------------------
    #--------- Calcul des processeurs : OS != AIX
    #-------------------------------------------------------------------------------
    export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, 
    c.Cores_per_Socket, c.Total_Cores, Core_Factor, Total_Cores*Core_Factor as Proc_Oracle"

    FROM="$tCPU c"
    WHERE="c.physical_server in (
    select c.physical_server
    from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
    where d.host_name=a.host_name and d.instance_name=a.instance_name
    and name in $ADV_SEC_FEATURES_1
    and locate('Enterprise', banner) > 0
    union
    select c.physical_server
    from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
    where d.host_name=a.host_name and d.instance_name=a.instance_name
    and name = $ADV_SEC_FEATURES_2
    and locate('Enterprise', banner) > 0
    and $NOT_IN not in (select table_owner from $tAdvCompression where host_name=d.host_name and instance_name=d.instance_name)
    )
    and os not like '%AIX%'"

    SQL="select $SELECT_NON_AIX from $FROM where $WHERE"

    if [ "$DEBUG" == "1" ]; then echo "[DEBUG - $0 ] - $SQL"; fi

    RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
    if [ "$RESULT" != "" ]; then
	# affichage du tableau pour le calcul du nombre de processeur
        print_proc_oracle $SELECT_NON_AIX'|'$FROM'|'$WHERE
	
	# echo "Calcul des processeurs Oracle par serveur physique (OS!=AIX) :"
	# mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

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

    FROM="$tCPU c"
    WHERE="c.physical_server in (
    select c.physical_server
    from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
    where d.host_name=a.host_name and d.instance_name=a.instance_name
    and name in $ADV_SEC_FEATURES_1
    and locate('Enterprise', banner) > 0
    union
    select c.physical_server
    from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
    where d.host_name=a.host_name and d.instance_name=a.instance_name
    and name = $ADV_SEC_FEATURES_2
    and locate('Enterprise', banner) > 0
    and $NOT_IN not in (select table_owner from $tAdvCompression where host_name=d.host_name and instance_name=d.instance_name)
    )
    and os like '%AIX%'"

    SQL="select $SELECT from $FROM where $WHERE"

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

exit
#-------------------------------------------------------------------------------
# afficher les informations liées aux bug Oracle à propos de la detection des options dans dba_features
#-------------------------------------------------------------------------------

#--------
# Pour les bases suivantes, vérifier si SecureFile (user) ne concerne pas uniquement le compte SYSMAN
#--------

export SQL="select c.physical_server, d.host_name, d.instance_name, d.table_Owner, d.table_name, d.compression, d.compression_for, banner
from $tVersion v, $tAdvCompression d left join $tCPU c on d.host_name=c.host_name
where d.host_name=v.host_name and d.instance_name=v.instance_name
-- and d.table_Owner not in $NOTIN
and locate('Enterprise', banner) > 0
order by c.physical_server, d.host_name, d.instance_name, d.table_Owner"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
    echo $CYAN
    echo "#-------------------------------------------------------------------------------"
    echo "Liste des comptes qui utilisent l'option SecureFile (user)"
    echo "Le compte SYSMAN ne doit pas être pris en compte, bug Oracle"
    echo "#-------------------------------------------------------------------------------"
    echo $NOCOLOR
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"
fi
