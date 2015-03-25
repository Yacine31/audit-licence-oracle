#!/bin/bash

# Inclusion des fonctions
REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

#-------------------------------------------------------------------------------
# Option Diagnostics Pack
#-------------------------------------------------------------------------------
DEBUG=0

export SQL="select c.physical_server, d.host_name, d.instance_name, d.name, d.version, 
d.detected_usages, d.last_usage_date, banner
from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=a.host_name and d.instance_name=a.instance_name
and name in ($DIAG_PACK_FEATURES)
and locate('Enterprise', banner) = 0
order by c.physical_server, d.host_name, d.instance_name, d.name"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
	if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
	echo "#-------------------------------------------------------------------------------"
	echo "# Option Diagnostics Pack : Standard Edition"
	echo "#-------------------------------------------------------------------------------"
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

	export SHEET_NAME=Diag_SE
	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml
	# fermeture de la feuille
	close_xml_sheet
fi

export SQL="select c.physical_server, d.host_name, d.instance_name, d.name, d.version, 
d.detected_usages, d.last_usage_date, banner
from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=a.host_name and d.instance_name=a.instance_name
and name in ($DIAG_PACK_FEATURES)
and locate('Enterprise', banner) > 0
order by c.physical_server, d.host_name, d.instance_name, d.name"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
	if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
	echo "#-------------------------------------------------------------------------------"
	echo "# Option Diagnostics Pack : Enterprise Edition"
	echo "#-------------------------------------------------------------------------------"
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
	export SHEET_NAME=Diag_EE
	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml

	#-------------------------------------------------------------------------------
	#--------- Calcul des processeurs : OS != AIX
	#-------------------------------------------------------------------------------


	export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, Core_Factor, Total_Cores*Core_Factor as Proc_Oracle"
	export FROM="$tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name"
	export WHERE="d.host_name=a.host_name and d.instance_name=a.instance_name
	and name in ($DIAG_PACK_FEATURES)
	and locate('Enterprise', banner) > 0
	and c.os not like '%AIX%'"
	export GROUPBY="c.physical_server"
	export ORDERBY="c.physical_server"

        SQL="select $SELECT_NON_AIX from $FROM where $WHERE group by $GROUPBY order by $ORDERBY"
        if [ "$DEBUG" == "1" ]; then echo "[DEBUG - $0 ] - $SQL"; fi

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
                # affichage du tableau pour le calcul du nombre de processeur
                print_proc_oracle $SELECT_NON_AIX'|'$FROM'|'$WHERE

		# echo "Calcul des processeurs Oracle par serveur physique (OS!=AIX) :"
		# mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

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
	and name in ($DIAG_PACK_FEATURES)
	and locate('Enterprise', banner) > 0
	and c.os like '%AIX%'"

	export SQL="select $SELECT from $FROM where $WHERE order by c.physical_server;"

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then

		if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
		echo "Caracteristiques des serveurs AIX et calcul des processeurs Oracle :"
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

		# export des données
		export_to_xml

		# calcul des processeurs par regroupement des serveurs physiques
		print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE

	fi
	#-------------------------------------------------------------------------------
	# Ici ce sont les serveurs qui utilisent Tuning mais pas Diagnostics 
	# Donc il ne sont pas comptés dans les licences Diagnostics Pack 
	# Il faut les ajouter au comptage des licences Diagnostics Pack
	#-------------------------------------------------------------------------------

	export SQL="select distinct physical_server, d.host_name, c.os, d.instance_name, d.name, d.version, banner 
	from $tVersion a, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name 
	where d.host_name=a.host_name and d.instance_name=a.instance_name 
	and d.name in ($TUNING_PACK_FEATURES)
	and d.host_name not in (select f.host_name from $tDbaFeatures f where f.name in ($DIAG_PACK_FEATURES) )
	order by c.physical_server, d.host_name, d.instance_name, d.name"

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
		if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
		echo "-----"
		echo "Ici ce sont les serveurs qui utilisent Tuning mais pas Diagnostics "
		echo "Donc il ne sont pas comptés dans les licences Diagnostics Pack"
		echo "Il faut les ajouter au comptage des licences Diagnostics Pack"
		echo "-----"
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

		# export des données
		export_to_xml
	fi
	# fermeture de la feuille
	close_xml_sheet
fi
