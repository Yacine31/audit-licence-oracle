#!/bin/bash

# Inclusion des fonctions
REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

DEBUG=0

#-------------------------------------------------------------------------------
# Option Spatial/Locator
# en Standard Edition
#-------------------------------------------------------------------------------

export SQL="select distinct physical_server, s.host_name, s.instance_name, s.owner, banner, concat(o.parameter,' = ', o.value) as 'Spatial Installed'
from $tVersion v, $tVoption o, $tSpatial s left join $tCPU c on s.host_name=c.host_name 
where o.host_name=v.host_name and o.instance_name=v.instance_name
and o.parameter='Spatial'
and s.host_name=v.host_name and s.instance_name=v.instance_name
and count_nbr not in ('0','-942') 
and owner not in ('', 'SYS', 'SYSTEM')
and locate('Enterprise', banner) = 0
order by physical_server, s.host_name, s.instance_name, s.owner"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then

	echo "#-------------------------------------------------------------------------------"
	echo "# Option Spatial/Locator en Standard Edition"
	echo "#-------------------------------------------------------------------------------"
	echo "Liste des serveurs avec option SPATIAL/LOCATOR en Standard Edition"
	echo "Pour ces serveurs, vérifier si c'est SPATIAL est FALSE c'est donc LOCATOR qui est mis en oeuvre"

	if [ "$DEBUG" == "1" ]; then echo "[DEBUG $0] - $SQL"; fi
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

	export SHEET_NAME=Locator_SE
	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml
	# femeture de la feuille de calcul
	close_xml_sheet

fi

#-------------------------------------------------------------------------------
# Option Spatial/Locator
# en Enterprise Edition
#-------------------------------------------------------------------------------

export SQL="select distinct physical_server, s.host_name, s.instance_name, s.owner, banner, concat(o.parameter,' = ', o.value) as 'Spatial Installed'
from $tVersion v, $tVoption o, $tSpatial s left join $tCPU c on s.host_name=c.host_name 
where o.host_name=v.host_name and o.instance_name=v.instance_name
and o.parameter='Spatial'
and s.host_name=v.host_name and s.instance_name=v.instance_name
and count_nbr not in ('0','-942') 
and owner not in ('', 'SYS', 'SYSTEM')
and locate('Enterprise', banner) > 0
order by physical_server, s.host_name, s.instance_name, s.owner"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then

	if [ "$DEBUG" == "1" ]; then echo "[DEBUG $0] - $SQL"; fi
	echo "#-------------------------------------------------------------------------------"
	echo "# Option Spatial/Locator en Enterprise Edition"
	echo "#-------------------------------------------------------------------------------"
	echo "Liste des serveurs avec option SPATIAL/LOCATOR en Enterprise Edition"
	echo "Pour ces serveurs, vérifier si c'est SPATIAL est TRUE sinon c'est donc LOCATOR qui est mis en oeuvre"
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

	export SHEET_NAME=Spatial_SE
	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml

	#-------------------------------------------------------------------------------
	#--------- Calcul des processeurs : OS != AIX
	#-------------------------------------------------------------------------------


	export SQL="select distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket,
	 c.Total_Cores, Core_Factor, Total_Cores*Core_Factor as Proc_Oracle
	from $tVersion v, $tVoption o, $tSpatial s left join $tCPU c on s.host_name=c.host_name 
	where o.host_name=v.host_name and o.instance_name=v.instance_name
	and o.parameter='Spatial'
	and s.host_name=v.host_name and s.instance_name=v.instance_name
	and count_nbr not in ('0','-942') 
	and owner not in ('', 'SYS', 'SYSTEM')
	and locate('Enterprise', banner) > 0
	and c.os not like '%AIX%'
	group by c.physical_server
	order by physical_server" 

        export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, Core_Factor, Total_Cores*Core_Factor as Proc_Oracle"

	export FROM="$tVersion v, $tVoption o, $tSpatial s left join $tCPU c on s.host_name=c.host_name"
	export WHERE="o.host_name=v.host_name and o.instance_name=v.instance_name
	and o.parameter='Spatial'
	and s.host_name=v.host_name and s.instance_name=v.instance_name
	and count_nbr not in ('0','-942') 
	and owner not in ('', 'SYS', 'SYSTEM')
	and locate('Enterprise', banner) > 0
	and c.os not like '%AIX%'"
	export GROUPBY="c.physical_server order by physical_server" 

        SQL="select $SELECT_NON_AIX from $FROM where $WHERE group by $GROUPBY"
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
	export FROM=" $tVersion a, $tVoption o, $tSpatial s left join $tCPU c on s.host_name=c.host_name "
	export WHERE=" o.host_name=a.host_name and o.instance_name=a.instance_name
	and o.parameter='Spatial'
	and s.host_name=a.host_name and s.instance_name=a.instance_name
	and count_nbr not in ('0','-942') 
	and owner not in ('', 'SYS', 'SYSTEM')
	and locate('Enterprise', banner) > 0
	and c.os like '%AIX%'"

	export SQL="select $SELECT from $FROM where $WHERE order by physical_server" 

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
		if [ "$DEBUG" == "1" ]; then echo "[DEBUG $0] - $SQL"; fi
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

		# export des données
		export_to_xml

		print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE
	fi
	# femeture de la feuille de calcul
	close_xml_sheet
fi 
