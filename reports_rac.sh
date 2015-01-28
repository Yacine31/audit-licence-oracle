#!/bin/bash 

# Inclusion des fonctions
REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh


#--------------------------------------------------------------------------------#
# Option RAC 
#--------------------------------------------------------------------------------#
DEBUG=0

#--- tous les serveurs et tous les OS :

export SELECT="distinct
c.physical_server 'Physical Server',
r.node_name 'Node name',
r.database_name 'Database Name',
r.rac_instance 'Instance Name',
r.nodes_count 'Nodes Count',
r.node_id 'Node ID',
if(locate('Enterprise', banner)>0, 'Enterprise', if(locate('Standard', banner)>0,'Standard','ND')) Edition ,
c.Model,
c.OS,
c.Processor_Type"

export FROM="$tCPU c left join $tRAC r left join $tVersion v on r.node_name=v.host_name on c.host_name=r.node_name"
export WHERE="r.nodes_count > 1"
export ORDERBY="c.physical_server, r.database_name, r.node_name, r.rac_instance"

export SQL="select $SELECT from $FROM where $WHERE order by $ORDERBY;"

RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
if [ "$RESULT" != "" ]; then
	echo "#--------------------------------------------------------------------------------#"
	echo "# Option RAC "
	echo "#--------------------------------------------------------------------------------#"
	echo "Les serveurs avec option RAC en Enterprise Edition"

	if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
	mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

	export SHEET_NAME=RAC

	# ouverture d'une feuille Excel
	open_xml_sheet
	# export des données
	export_to_xml

	# insertion des données de la requête dans le fichier XML
	export WHERE="r.nodes_count > 1 and c.os not like '%AIX%'"
	export SQL="select $SELECT from $FROM where $WHERE order by $ORDERBY;"

	if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi

	# export des données
	export_to_xml

	#--------- Calcul des processeurs : OS != AIX
	export SELECT_NON_AIX="distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, c.Total_Cores, '' as Core_Factor, '' as Proc_Oracle"
	export FROM="$tCPU c left join $tRAC r left join $tVersion v on r.node_name=v.host_name on c.host_name=r.node_name"
	export WHERE="r.nodes_count > 1 and c.os not like '%AIX%'"
	export ORDERBY="c.physical_server"

	SQL="select $SELECT from $FROM where $WHERE order by $ORDERBY;"

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
		# affichage du tableau pour le calcul du nombre de processeur
		print_proc_oracle $SELECT_NON_AIX'|'$FROM'|'$WHERE

		# export des données
		export_to_xml
	fi


	# ---- Les serveurs OS == 'AIX' :
	export SELECT="distinct 
	b.physical_server 'Physical Server',
	b.Host_Name 'Host Name',
	c.node_name 'Node name',
	if(locate('Enterprise', banner)>0, 'Enterprise', 'Standard') Edition,
	-- c.Model,
	b.OS,
	b.Processor_Type 'Proc Type',
	b.Partition_Type 'Partition Type',
	b.Partition_Mode 'Partition Mode',
	b.Entitled_Capacity 'EC',
	b.Active_CPUs_in_Pool 'ACiP',
	b.Online_Virtual_CPUs 'OVC',
	b.Active_Physical_CPUs 'APC',
	b.Core_Count ,
	b.Core_Factor"

	export FROM="$tCPU b left join $tRAC c left join $tVersion a on c.node_name=a.host_name on b.host_name=c.node_name"
	export WHERE="c.nodes_count > 1 and b.os like '%AIX%'"
	export ORDERBY="b.physical_server, c.database_name, c.node_name, c.rac_instance"
	# export ORDERBY="r.database_name, r.rac_instance, r.node_name, c.physical_server"

	SQL="select $SELECT from $FROM where $WHERE order by $ORDERBY;"

	RESULT=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL")
	if [ "$RESULT" != "" ]; then
		if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
		mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"
	
		# export des données
		export_to_xml

		# Option RAC : calcul des processeurs
		# export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"
		# export WHERE="d.DB_Edition='Enterprise' and d.v_opt_rac!=0 and c.os='AIX'"

		# Base de données en Enterprise Edition : calcul des processeurs pour serveurs AIX
		print_proc_oracle_aix $SELECT'|'$FROM'|'$WHERE
	fi
	# export des données
	# fermeture de la feuille
	close_xml_sheet
fi
