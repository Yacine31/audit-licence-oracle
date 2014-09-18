#!/bin/bash

# Inclusion des fonctions
# REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

#--------------------------------------------------------------------------------#
# Option OLAP
#--------------------------------------------------------------------------------#

echo "
#--------------------------------------------------------------------------------#
# Option OLAP
#--------------------------------------------------------------------------------#
"
#--------------------------------------------------------------------------------#
# detail de toutes les bases qui utilisent OLAP
#--------------------------------------------------------------------------------#

echo "Liste des serveurs avec option OLAP en Enterprise Edition"

DEBUG=0

#--- tous les serveurs et tous les OS :
echo "Liste des serveurs, instances et propriétaire des objets partitionés"

export SQL="select physical_server, o.host_name, o.instance_name, o.owner, o.aw_name, o.aw_number, o.count_nbr, o.pagespaces
from $tOLAP o left join $tCPU c on o.host_name=c.host_name
where owner != 'SYS' and count_nbr not in ('','0','-942')
order by physical_server, o.host_name, o.instance_name, o.owner" 


if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"


#--- tableau pour le calcul des processeurs, serveurs non AIX

#--------- Calcul des processeurs : OS != AIX

echo "Calcul des processeurs Oracle par serveur physique (OS=AIX) :"

export SQL="select distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, '' as Total_Cores, '' as Core_Factor, '' as Proc_Oracle
from $tOLAP o left join $tCPU c on o.host_name=c.host_name
where c.os not like '%AIX%' and owner != 'SYS' and count_nbr not in ('','0','-942')
group by c.physical_server
order by physical_server" 

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"


# export des données
export_to_xml


#--------- Calcul des processeurs : OS == AIX

echo
export SQL="select distinct 
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
c.Core_Factor ,
c.CPU_Oracle
from $tOLAP o left join $tCPU c on o.host_name=c.host_name
where c.os like '%AIX%' and owner != 'SYS' and count_nbr not in ('','0','-942')
order by physical_server" 

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

# export des données
export_to_xml


echo "Calcul des processeurs Oracle par serveur physique (OS=AIX) :"

export SQL="
drop table  if exists proc_oracle;

create table proc_oracle as
select
    r.physical_server,
    sum(r.CPU_Oracle) 'Total_Proc',
    r.Core_Factor,
    r.Active_Physical_CPUs,
    if (sum(r.CPU_Oracle)<r.Active_Physical_CPUs,sum(r.CPU_Oracle),r.Active_Physical_CPUs) 'Proc_Oracle_Calcules'
from
(select distinct physical_server, o.host_name, Partition_Mode,
Partition_Type, Active_Physical_CPUs, Entitled_Capacity, Active_CPUs_in_Pool, Online_Virtual_CPUs, Processor_Type,
Core_Count, Core_Factor, CPU_Oracle
from $tOLAP o left join $tCPU c on o.host_name=c.host_name
where c.os like '%AIX%' and owner != 'SYS' and count_nbr not in ('','0','-942')
order by PHYSICAL_SERVER) r
group by physical_server;
select * from proc_oracle;

select * from proc_oracle;"


if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

export SQL="select sum(Proc_Oracle_Calcules) from proc_oracle"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
echo "Somme des processeurs Oracle pour les serveurs AIX :" $(mysql -s -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL")

exit

# export des données
export_to_xml
# fermeture de la feuille
close_xml_sheet
