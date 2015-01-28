#!/bin/bash

# Inclusion des fonctions
REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

#--------------------------------------------------------------------------------#
# Option OLAP
#--------------------------------------------------------------------------------#


DEBUG=0

#--------------------------------------------------------------------------------#
# detail de toutes les bases qui utilisent OLAP
#--------------------------------------------------------------------------------#

export SQL="select physical_server, o.host_name, o.instance_name, o.owner, o.aw_name, o.aw_number, o.count_nbr, o.pagespaces
from $tOLAP o left join $tCPU c on o.host_name=c.host_name
where owner != 'SYS' and count_nbr not in ('','0','-942')
order by physical_server, o.host_name, o.instance_name, o.owner" 

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then

	echo "#--------------------------------------------------------------------------------#"
	echo "# Option OLAP"
	echo "#--------------------------------------------------------------------------------#"

	echo "Liste des serveurs avec option OLAP en Enterprise Edition"
	if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

	export SHEET_NAME=OLAP
	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml

	#--------------------------------------------------------------------------------#
	#--- tableau pour le calcul des processeurs, serveurs non AIX
	#--------------------------------------------------------------------------------#

	export SQL="select distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, '' as Core_Factor, '' as Proc_Oracle
	from $tOLAP o left join $tCPU c on o.host_name=c.host_name
	where c.os not like '%AIX%' and owner != 'SYS' and count_nbr not in ('','0','-942')
	group by c.physical_server
	order by physical_server" 

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
		if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
		echo "Calcul des processeurs Oracle par serveur physique (OS=AIX) :"
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"


		# export des données
		export_to_xml
	fi

	#--------------------------------------------------------------------------------#
	#--------- Calcul des processeurs : OS == AIX
	#--------------------------------------------------------------------------------#
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
	export FROM=" $tOLAP a left join $tCPU c on a.host_name=c.host_name"
	export WHERE=" c.os like '%AIX%' and owner != 'SYS' and count_nbr not in ('','0','-942')"

	export SQL="select $SELECT from $FROM where $WHERE order by physical_server" 

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
		if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

		# export des données
		export_to_xml

		print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE
	fi
	# fermeture de la feuille
	close_xml_sheet
fi
