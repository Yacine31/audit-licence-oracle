#!/bin/bash

# Inclusion des fonctions
# REP_COURANT="/home/merlin/lms_scripts"
. ${REP_COURANT}/fonctions.sh
. ${REP_COURANT}/fonctions_xml.sh

#--------------------------------------------------------------------------------#
# Option Partitioning
#--------------------------------------------------------------------------------#
echo "
#--------------------------------------------------------------------------------#
# Option Partitioning
#--------------------------------------------------------------------------------#
"


DEBUG=0

#--- tous les serveurs et tous les OS :
echo "Liste des serveurs, instances et propriétaire des objets partitionés"
export SQL_NOT_IN="('SYS','SYSTEM','SYSMAN','MDSYS')"
echo "Les comptes $SQL_NOT_IN ne sont pas pris en compte"

export SQL="select distinct c.physical_server, s.host_name, s.instance_name, s.owner
from $tSegments s left join $tCPU c on c.host_name=s.host_name
where s.owner not in $SQL_NOT_IN
order by c.physical_server, s.host_name, s.instance_name;
"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL"

export SHEET_NAME=Part
# ouverture d'une feuille Excel
open_xml_sheet
# export des données
export_to_xml

#--- tableau pour le calcul des processeurs, serveurs non AIX

#--------- Calcul des processeurs : OS != AIX

echo "Calcul des processeurs Oracle par serveur physique (OS=AIX) :"

export SQL="select distinct c.physical_server, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket, '' as Total_Cores, '' as Core_Factor, '' as Proc_Oracle
FROM $tSegments s left join $tCPU c on s.Host_Name=c.Host_Name
where c.os not like '%AIX%' and s.owner not in $SQL_NOT_IN 
group by c.physical_server
having count(s.Host_Name) > 0
order by c.physical_server;
"
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
FROM $tSegments s left join $tCPU c on s.Host_Name=c.Host_Name
where c.os like '%AIX%' and s.owner not in $SQL_NOT_IN 
order by c.physical_server;"

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
(select distinct physical_server, s.host_name, Partition_Mode,
Partition_Type, Active_Physical_CPUs, Entitled_Capacity, Active_CPUs_in_Pool, Online_Virtual_CPUs, Processor_Type,
Core_Count, Core_Factor, CPU_Oracle
FROM $tSegments s left join $tCPU c on s.Host_Name=c.Host_Name
where c.os like '%AIX%' and s.owner not in $SQL_NOT_IN 
order by PHYSICAL_SERVER) r
group by physical_server;

select * from proc_oracle;"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

export SQL="select sum(Proc_Oracle_Calcules) from proc_oracle"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
echo "Somme des processeurs Oracle pour les serveurs AIX :" $(mysql -s -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL")

# export des données
export_to_xml
# fermeture de la feuille
close_xml_sheet
