#!/bin/bash

. ${SCRIPTS_DIR}/fonctions.sh
. ${SCRIPTS_DIR}/fonctions_xml.sh

#-------------------------------------------------------------------------------
# Option Real Application Testing
#-------------------------------------------------------------------------------


export SQL="select c.physical_server, d.host_name, d.instance_name, d.name, d.version, 
d.detected_usages, d.last_usage_date
-- , banner
from $tVersion v, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name
where d.host_name=v.host_name and d.instance_name=v.instance_name
and name in ($RAT_FEATURES)
and locate('Enterprise', banner) > 0
order by c.physical_server, d.host_name, d.instance_name, d.name"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then

	if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
	echo $YELLOW
	echo "#-------------------------------------------------------------------------------"
	echo "# Option Real Application Testing"
	echo "#-------------------------------------------------------------------------------"
	echo $NOCOLOR
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

	export SHEET_NAME=RAT
	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml

	#-------------------------------------------------------------------------------
	#--------- Calcul des processeurs : OS != AIX
	#-------------------------------------------------------------------------------

	export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, Core_Factor, Total_Cores*Core_Factor as Proc_Oracle"
	export FROM="$tVersion v, $tDbaFeatures d left join $tCPU c on d.host_name=c.host_name"
	export WHERE="d.host_name=v.host_name and d.instance_name=v.instance_name
	and name in ($RAT_FEATURES)
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
	and name in ($RAT_FEATURES)
	and locate('Enterprise', banner) > 0
	and c.os like '%AIX%'"
    
	export SQL="select $SELECT from $FROM where $WHERE order by c.physical_server"

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then

		if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
		echo "Calcul des processeurs Oracle par serveur physique (OS=AIX) :"
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

		# export des données
		export_to_xml

		# calcul des processeurs par regroupement des serveurs physiques
		print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE

	fi
	# fermeture de la feuille
	close_xml_sheet
	
fi
