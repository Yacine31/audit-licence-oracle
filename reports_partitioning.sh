#!/bin/bash

# Inclusion des fonctions
REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

#--------------------------------------------------------------------------------#
# Option Partitioning
#--------------------------------------------------------------------------------#

DEBUG=0

#--------------------------------------------------------------------------------#
#--- tous les serveurs et tous les OS :
#--------------------------------------------------------------------------------#
export SQL_NOT_IN="('SYS','SYSTEM','SYSMAN','MDSYS')"

export SQL="select distinct c.physical_server, a.host_name, a.instance_name, a.owner
from $tSegments a left join $tCPU c on c.host_name=a.host_name
where a.owner not in $SQL_NOT_IN
order by c.physical_server, a.host_name, a.instance_name;
"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
	if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
	echo "#--------------------------------------------------------------------------------#"
	echo "# Option Partitioning"
	echo "#--------------------------------------------------------------------------------#"

	echo "Liste des serveurs, instances et propriétaire des objets partitionés"
	echo "Les comptes $SQL_NOT_IN ne sont pas pris en compte"
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

	export SHEET_NAME=Part
	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml

	#--------------------------------------------------------------------------------#
	#--- tableau pour le calcul des processeurs, serveurs non AIX
	#--------- Calcul des processeurs : OS != AIX
	#--------------------------------------------------------------------------------#

	export SELECT="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, Core_Factor, Total_Cores*Core_Factor as Proc_Oracle"

	export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, Core_Factor, Total_Cores*Core_Factor as Proc_Oracle"
	export FROM=" $tSegments a left join $tCPU c on a.Host_Name=c.Host_Name"
	export WHERE="c.os not like '%AIX%' and a.owner not in $SQL_NOT_IN" 
	export GROUPBY="c.physical_server having count(a.Host_Name) > 0 order by c.physical_server;"

	SQL="select $SELECT from $FROM where $WHERE group by $GROUPBY"
	if [ "$DEBUG" == "1" ]; then echo "[DEBUG - $0 ] - $SQL"; fi

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
                # affichage du tableau pour le calcul du nombre de processeur
                print_proc_oracle $SELECT'|'$FROM'|'$WHERE

		# echo "Calcul des processeurs Oracle par serveur physique (OS != AIX) :"
		# mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

		# export des données
		export_to_xml
	fi

	#--------------------------------------------------------------------------------#
	#--------- Calcul des processeurs : OS == AIX
	#--------------------------------------------------------------------------------#
	export SELECT="distinct 
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
	export FROM=" $tSegments a left join $tCPU c on a.Host_Name=c.Host_Name"
	export WHERE=" c.os like '%AIX%' and a.owner not in $SQL_NOT_IN"

	export SQL="select $SELECT from $FROM where $WHERE order by c.physical_server;"

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
		if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL"

		# export des données
		export_to_xml

		print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE
	fi
	# fermeture de la feuille
	close_xml_sheet
fi
