#!/bin/bash

# ---------------------------------
# 15/08/2014 - Création
# ---------------------------------

#--------------------------------------------------------------------------------#
# Les couleurs 
#--------------------------------------------------------------------------------#

export BLACK=$(tput setaf 0)
export RED=$(tput setaf 1)
export GREEN=$(tput setaf 2)
export YELLOW=$(tput setaf 3)
export BLUE=$(tput setaf 4)
export MAGENTA=$(tput setaf 5)
export CYAN=$(tput setaf 6)
export WHITE=$(tput setaf 7)
export NOCOLOR=$(tput sgr 0)

#--------------------------------------------------------------------------------#
# Les constantes 
#--------------------------------------------------------------------------------#

MYSQL_DB="test"
MYSQL_USER="root"
MYSQL_PWD="root"

#--------------------------------------------------------------------------------#
# les clauses SQL communes à certaines requêtes :
#--------------------------------------------------------------------------------#
# export ORDERBY="c.physical_server, d.host_name"

export SELECT_EE_AIX="distinct c.physical_server,
a.Host_Name Host,
c.Processor_Type ,
c.Partition_Type,
c.Partition_Mode,
c.Entitled_Capacity EC,
c.Active_CPUs_in_Pool ACiP,
c.Shared_Pool_ID PoolID,
c.Online_Virtual_CPUs OVC,
c.Active_Physical_CPUs APC,
Core_Count,
Core_Factor
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
export SQL="

select $SELECT from $FROM where $WHERE
group by c.physical_server
order by c.physical_server;

-- somme des processeurs pour le meme core factor
select c.core_factor, sum(c.total_cores*c.core_factor) 'Proc Oracle par core factor' from
(
select PHYSICAL_SERVER, Total_Cores, Core_Factor
from $FROM where $WHERE
group by physical_server
) c
group by c.core_factor
;"

# echo "FLAG - $SQL"

mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

# insertion des données de la requête dans le fichier XML
export_to_xml
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
    sum(r.Core_Count) Total_Cores,
    r.Core_Factor,
    r.Shared_Pool_ID, 
    r.Active_CPUs_in_Pool, 
    r.Active_Physical_CPUs 
from
(select distinct physical_server, a.host_name, Partition_Mode,
Partition_Type, Active_Physical_CPUs, Entitled_Capacity, Active_CPUs_in_Pool, Shared_Pool_ID, Online_Virtual_CPUs, Processor_Type,
Core_Count, Core_Factor
from $FROM where $WHERE
order by PHYSICAL_SERVER) r
group by physical_server, Shared_Pool_ID;

-- Si Active CPU in Pool = '-', on replace par Active_Physical_CPUs
-- Pour que la comparaison fonctionne :
update proc_oracle set Active_CPUs_in_Pool=Active_Physical_CPUs where Active_CPUs_in_Pool='-';

select *, 
    if(Total_Cores<Active_CPUs_in_Pool,Total_Cores,Active_CPUs_in_Pool) * Core_Factor 'Proc_Oracle_Calcules'
from proc_oracle
order by physical_server, Shared_Pool_ID;

select  
    Core_Factor,
    sum(if(Total_Cores<Active_CPUs_in_Pool,Total_Cores,Active_CPUs_in_Pool) * Core_Factor) 'Proc Oracle par core factor'
from proc_oracle 
group by Core_Factor
;"

# echo ==========
# echo $SQL
# echo ==========

if [ "$DEBUG" == "1" ]; then echo "[DEBUG $0] - $SQL"; fi
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL" 

# insertion des données de la requête dans le fichier XML
export_to_xml

export SQL="
select  
    ceiling(sum(if(Total_Cores<Active_CPUs_in_Pool,Total_Cores,Active_CPUs_in_Pool) * Core_Factor)) Total_Proc,
from proc_oracle 
group by Core_Factor
"

if [ "$DEBUG" == "1" ]; then echo "[DEBUG $0] - $SQL"; fi
# echo "Somme des processeurs Oracle pour les serveurs AIX :" $(mysql -s -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "$SQL")

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


#--------------------------------------------------------------------------------#
# mise à jour des core factor dans la table cpu
#--------------------------------------------------------------------------------#
function update_core_factor {

SQL="
update $tCPU set core_factor = case 
    when upper(processor_type) like '%SPARC-T3' then 0.25

    when upper(processor_type) like '%AMD%' then 0.5
    when upper(processor_type) like '%INTEL%' then 0.5


    when upper(processor_type) like '%ULTRASPARC-T1' then 0.5
    when upper(processor_type) like '%ULTRASPARC-T2+' then 0.5
    when upper(processor_type) like '%SPARC64-VII+' then 0.5
    when upper(processor_type) like '%SPARC64-X' then 0.5
    when upper(processor_type) like '%SPARC64-T4' then 0.5
    when upper(processor_type) like '%SPARC64-T5' then 0.5
    when upper(processor_type) like '%SPARC64-M5' then 0.5
    when upper(processor_type) like '%SPARC64-M6' then 0.5
    when upper(processor_type) like '%SPARC64-X+' then 0.5
    when upper(processor_type) like '%ITANIUM%93%' then 0.5
    
    -- cas de SunOS virtualisé sur VMware
    when upper(processor_type) = 'x86' then 0.5

    when upper(processor_type) like '%ULTRASPARC-T2' then 0.75
    when upper(processor_type) like '%PA-RISC%' then 0.75
    when upper(processor_type) like '%SPARC64-VI' then 0.75
    when upper(processor_type) like '%SPARC64-VII' then 0.75
    when upper(processor_type) like '%ULTRASPARC-III+' then 0.75
    when upper(processor_type) like '%ULTRASPARC-IV' then 0.75
    when upper(processor_type) like '%ULTRASPARC-IV+' then 0.75
    when upper(processor_type) like '%ULTRASPARC-VI' then 0.75
    when upper(processor_type) like '%ULTRASPARC-VII' then 0.75
    when upper(processor_type) like '%POWER%5%' then 0.75
    when upper(processor_type) like '%POWER%4%' then 0.75

    when upper(processor_type) like '%POWER%6%' then 1 
    when upper(processor_type) like '%POWER%7%' then 1 
    when upper(processor_type) like '%POWER%8%' then 1
    when upper(processor_type) like '%ITANIUM%95%' then 1
    when upper(processor_type) like '%ULTRASPARC-IIi' then 1
    when upper(processor_type) like '%ULTRASPARC-III' then 1
    when upper(processor_type) like '%ULTRASPARC-IIIi' then 1
    when upper(processor_type) like 'SPARC64-V' then 1
    when upper(processor_type) like 'SPARC64-GP' then 1

    -- pour tous les autres, c est coef 1
    else 1

end; 
"
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --database=${MYSQL_DB} -e "$SQL" 

}
