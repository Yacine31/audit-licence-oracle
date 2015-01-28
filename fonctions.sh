#!/bin/bash

# ---------------------------------
# 15/08/2014 - Création
# ---------------------------------

#--------------------------------------------------------------------------------#
# Les constantes 
#--------------------------------------------------------------------------------#

MYSQL_DB="test"
MYSQL_USER="root"
MYSQL_PWD="root"

#--------------------------------------------------------------------------------#
# les clauses SQL communes à certaines requêtes :
#--------------------------------------------------------------------------------#
export ORDERBY="c.physical_server, d.host_name"

export SELECT_EE_AIX="distinct c.physical_server,
a.Host_Name Host,
-- c.Model,
-- c.OS,
c.Processor_Type ,
-- c.Partition_Number,
c.Partition_Type,
c.Partition_Mode,
c.Entitled_Capacity EC,
c.Active_CPUs_in_Pool ACiP,
c.Online_Virtual_CPUs OVC,
c.Active_Physical_CPUs APC,
Core_Count,
Core_Factor
-- CPU_Oracle
"

export SELECT_EE_NON_AIX="distinct
c.physical_server, d.Host_Name, c.Marque, c.Model, c.OS, c.Processor_Type,
c.Socket, c.Cores_per_Socket 
-- ,  c.Total_Cores
"

#--------------------------------------------------------------------------------#
# Cette fonction est pour les autres serveurs non AIX
# Elle calcul le nombre de processeurs Oracle en fontion
# du type du processeur
#--------------------------------------------------------------------------------#
function print_proc_oracle {

export SELECT=$(echo $@ | cut -d'|' -f1)
export FROM=$(echo $@ | cut -d'|' -f2)
export WHERE=$(echo $@ | cut -d'|' -f3)

echo "Calcul des processeurs Oracle par serveur physique (OS!=AIX) :"

#export SQL="select distinct physical_server,Processor_Type,Socket,Cores_per_Socket, '' as 'Total Cores', '' as 'Core Factor', '' as 'Proc Oracle'
export SQL="select $SELECT from $FROM where $WHERE
group by c.physical_server
order by c.physical_server
;"

# echo "FLAG - $SQL"

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

# insertion des données de la requête dans le fichier XML
# export_to_xml
}

#--------------------------------------------------------------------------------#
# Cette fonction est spécifique au serveurs AIx,
# Elle calcul le nombre de processeurs Oracle en fontion
# du type de la partition LPAR
#--------------------------------------------------------------------------------#
function print_proc_oracle_aix {

export SELECT=$(echo $@ | cut -d'|' -f1)
export FROM=$(echo $@ | cut -d'|' -f2)
export WHERE=$(echo $@ | cut -d'|' -f3)

echo "Calcul des processeurs Oracle par serveur physique (OS=AIX) :"

export SQL="
drop table  if exists proc_oracle;

create table proc_oracle as
select
    r.physical_server,
    if(sum(r.Core_Count)<r.Active_Physical_CPUs,sum(r.Core_Count),r.Active_Physical_CPUs) 'Total_Cores',
    r.Core_Factor,
    r.Active_Physical_CPUs 
from
(select distinct physical_server, a.host_name, Partition_Mode,
Partition_Type, Active_Physical_CPUs, Entitled_Capacity, Active_CPUs_in_Pool, Online_Virtual_CPUs, Processor_Type,
Core_Count, Core_Factor
from $FROM where $WHERE
order by PHYSICAL_SERVER) r
group by physical_server;

select *, ceiling(Total_Cores * Core_Factor) 'Proc_Oracle_Calcules' from proc_oracle;"

# echo ==========
# echo $SQL
# echo ==========

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

# insertion des données de la requête dans le fichier XML
export_to_xml

export SQL="select sum(ceiling(Total_Cores * Core_Factor)) 'Sum_Proc_Oracle' from proc_oracle"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG] - $SQL"; fi
echo "Somme des processeurs Oracle pour les serveurs AIX :" $(mysql -s -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL")

# insertion des données de la requête dans le fichier XML
# export_to_xml
}


#--------------------------------------------------------------------------------#
# Impression d'une légende pour les caractéristiques AIX
#--------------------------------------------------------------------------------#
function fnPrintLegende {
echo '----------- LEGENDE --------------------------'
echo '     Part Nbr = Partition Number' 
echo '    Part Type = Partition Type'
echo '    Part Mode = Partition Mode'
echo '           EC = Entitled Capacity'
echo '      Act CPU = Active CPUs in Pool'
echo '       OV CPU = Online Virtual CPUs'
echo '  Act Phy CPU = Active Physical CPUs in system'
echo '----------------------------------------------'
}
