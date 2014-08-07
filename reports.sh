#!/bin/bash
# interroger les tables pour trouver les infos
# 19/05/2014 - le script est appelé depuis extract.sh
# 20/05/2014 - séparation des affichages pour AIX : les colonnes ne sont pas les mêmes
# 22/05/2014 - modification des jointures (left join) pour prendre en compte les noms des serveurs
#              même si les infos serveurs ne sont pas présentes.
# 23/05/2014 - ajout de MDSYS aux compte exclus du partitioning
#              ajout des listing des bases et serveur par edition
# 22/07/2014 - suppression des détails des bases
#            - le détails est disponible à le demande via le script reports_detail.sh
# 04/08/2014 - ajout du calcul des processeurs pour les serveurs AIX


# MYSQL_ARGS="--defaults-file=/etc/mysql/debian.cnf"
DB="test"
PROJECT_NAME="$1"

[ "$PROJECT_NAME" = "" ] && echo "Syntax: $0 PROJECT_NAME" && exit 1

tDB=$PROJECT_NAME"_db"      # table qui contient les donnees db
tCPU=$PROJECT_NAME"_cpu"    # table qui contient les donnees des serveurs
tSegments=$PROJECT_NAME"_segments"  # table qui contient les objets partitionés
tDbaFeature=$PROJECT_NAME"_dba_feature"  # table qui contient les options et packs utilisés
tVersion=$PROJECT_NAME"_version"  # table qui contient les versions
tCPUAIX=$PROJECT_NAME"_cpu_aix"	  # table pour le calcul des CPUs Oracle pour les serveurs AIX
tRAC=$PROJECT_NAME"_rac"	# table avec les données RAC : nodes_count != 1

#-----------------------------------
# Cette fonction est spécifique au serveurs AIx,
# Elle calcul le nombre de processeurs Oracle en fontion
# du type de la partition LPAR
#-----------------------------------

function print_proc_oracle {

export WHERE=$1

echo "Calcul des processeurs Oracle par serveur physique :"
mysql -uroot -proot --local-infile --database=$DB -e "
drop table if exists $tCPUAIX;
create table $tCPUAIX as

select distinct physical_server, Partition_Mode,
Partition_Type, Active_Physical_CPUs, Entitled_Capacity, Active_CPUs_in_Pool, Online_Virtual_CPUs, Processor_Type,
-- Partition_Type = Shared, Shared-SMT, Shared-SMT-4, Dedicated-SMT
case left(Partition_Type, 6)
        when 'Shared' then
                case Partition_Mode
                        when 'Uncapped' then @Core_Count := least(cast(Active_CPUs_in_Pool as signed), cast(Online_Virtual_CPUs as signed))
                        when 'Capped' then @Core_Count := cast(Entitled_Capacity as decimal(3,1))
                        when 'Donating' then @Core_Count := cast(Entitled_Capacity as decimal(3,1))
                end
        when 'Dedica' then @Core_Count := cast(Entitled_Capacity as decimal(3,1))
end as Core_Count,
-- Processor_Type = PowerPC_POWER5 ou PowerPC_POWER6 ou PowerPC_POWER7
-- on inverse la chaine et on regarde le premier caractère qui correspond au chiffre
case left(reverse(Processor_Type),1)
        when 5 then @Core_Factor := 0.75
        when 6 then @Core_Factor := 0.75
        when 7 then @Core_Factor := 1
end as Core_Factor,
CEILING(@Core_Count * @Core_Factor) as CPU_Oracle
from $tDB db left join $tCPU cpu on cpu.Host_Name=db.Host_Name
where db.DB_Edition='Enterprise' and cpu.os='AIX';
-- where $WHERE;
--
-- Ensuite on calcul le nombre de processeurs Oracle par Serveur Physique
--
drop table if exists cpu_oracle;
create table cpu_oracle as 
select
        physical_server,
        sum(CPU_Oracle) 'Total_Proc_Oracle',
        Active_Physical_CPUs,
        if (sum(CPU_Oracle)<Active_Physical_CPUs,sum(CPU_Oracle),Active_Physical_CPUs) 'Proc_Oracle_Calcules'
from $tCPUAIX
group by physical_server;

select * from cpu_oracle;
"

mysql -ss -uroot -proot --local-infile --database=$DB -e "
select concat('Total des processeurs Oracle : ', sum(Proc_Oracle_Calcules)) from cpu_oracle;
"
}


# les clauses SQL communes à certaines requêtes :
export SELECT_EE_AIX="SELECT distinct
cpu.physical_server 'Physical Server',
cpu.Host_Name Host,
cpu.Model,
left(cpu.OS, 25) OS,
cpu.Processor_Type 'Proc Type',
cpu.Partition_Number 'Part Nbr',
cpu.Partition_Type 'Part Type',
cpu.Partition_Mode 'Part Mode',
cpu.Entitled_Capacity 'EC',
cpu.Active_CPUs_in_Pool 'Act CPU',
cpu.Online_Virtual_CPUs 'OV CPU',
cpu.Active_Physical_CPUs 'Act Phy CPU'
"

export SELECT_EE_NON_AIX="
SELECT distinct
cpu.physical_server, db.Host_Name, cpu.Marque, cpu.Model, left(cpu.OS, 25) OS, cpu.Processor_Type,
cpu.Socket, cpu.Cores_per_Socket,  cpu.Total_Cores
"


# Fontions diverses
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


#-------------------------------------------------------------------------------
# Infos générales 
#-------------------------------------------------------------------------------
echo "Les serveurs sans base de données"
mysql -uroot -proot --local-infile --database=$DB -e "
select Host_Name, os, Marque, Model, Processor_Type 
from $tCPU where host_name not in (SELECT Host_Name FROM $tDB)
order by Host_Name;
"

echo "Les serveur sans le résultat de lms_cpuq.sh"
mysql -uroot -proot --local-infile --database=$DB -e "
SELECT distinct Host_Name FROM $tDB where Host_Name not in (select Host_Name from $tCPU) 
order by Host_Name;
"

#-------------------------------------------------------------------------------
# Base de données en Standard Edition
#-------------------------------------------------------------------------------
echo "Les serveurs en Standard Edition"
mysql -uroot -proot --local-infile --database=$DB -e "
SELECT distinct cpu.physical_server, v.Host_Name, cpu.Marque, cpu.Model, cpu.Processor_Type, left(cpu.OS, 25) OS, cpu.Socket   
FROM $tVersion v left join $tCPU cpu 
on cpu.Host_Name=v.Host_Name 
where v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and cpu.os not like '%AIX%'
order by cpu.physical_server, cpu.Host_Name, cpu.os;
"


mysql -uroot -proot --local-infile --database=$DB -e "
SELECT 
-- distinct cpu.Machine_Serial_Number 'Serial Number', 
cpu.physical_server 'Physical Server', v.Host_Name, cpu.Marque, cpu.Model, cpu.Processor_Type, left(cpu.OS, 25) OS, cpu.Socket
FROM $tVersion v left join $tCPU cpu
on cpu.Host_Name=v.Host_Name
where v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and cpu.os like '%AIX%'
order by 
-- cpu.Machine_Serial_Number, 
cpu.physical_server, cpu.Marque, cpu.Host_Name, cpu.os;
"

#-------------------------------------------------------------------------------
# Base de données en Enterprise Edition
#-------------------------------------------------------------------------------
echo "Les serveurs en Enterprise Edition"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX 
FROM $tDB db left join $tCPU cpu 
on cpu.Host_Name=db.Host_Name
where db.DB_Edition='Enterprise' 
and cpu.os not like '%AIX%' 
order by cpu.physical_server, cpu.Host_Name, cpu.os;
"


echo "--> Les serveur AIX avec le même numéro de série sont sur le même chassis : à valider avec le client"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tDB db left join $tCPU cpu
on cpu.Host_Name=db.Host_Name
where db.DB_Edition='Enterprise' and cpu.os like '%AIX%'
order by cpu.physical_server, cpu.Host_Name, cpu.os;
"

# Base de données en Enterprise Edition : calcul des processeurs
export WHERE="db.DB_Edition='Enterprise' and cpu.os='AIX'"
print_proc_oracle $WHERE


# fnPrintLegende 


#-------------------------------------------------------------------------------
# Option RAC 
#-------------------------------------------------------------------------------
echo "Les serveurs avec option RAC en Enterprise Edition"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tDB db left join $tCPU cpu 
on cpu.Host_Name=db.Host_Name
where db.DB_Edition='Enterprise' and db.v_opt_rac not in ('FALSE','') and cpu.os not like '%AIX%'
order by cpu.Marque, cpu.os, cpu.Host_Name;
"
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tDB db left join $tCPU cpu 
on cpu.Host_Name=db.Host_Name
where db.DB_Edition='Enterprise' and db.v_opt_rac not in ('FALSE','') and cpu.os like '%AIX%'
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os;
"
# TODO : vérifier le résultat à afficher, la colonne OS pose pb avec la valeur NULL

echo "------------------- NOUVEAU CALCUL ----------------"
echo "--- Les lignes avec NULL comme valeur, indique des serveurs sans le résultats LMS_CPUQ "
echo "---------------------------------------------------"
mysql -uroot -proot --local-infile --database=$DB -e "
SELECT distinct
cpu.physical_server, r.node_name, cpu.Marque, cpu.Model, OS, cpu.Processor_Type,
cpu.Socket, cpu.Cores_per_Socket,  cpu.Total_Cores 
from  $tRAC r left join  $tCPU cpu
on r.node_name=cpu.host_name
where nodes_count!=1 
and (OS!='AIX' or OS is null)
order by r.node_name;
"
mysql -uroot -proot --local-infile --database=$DB -e "
SELECT distinct
cpu.physical_server 'Physical Server',
cpu.Host_Name 'Host Name',
r.node_name 'Node name',
cpu.Model,
OS,
cpu.Processor_Type 'Proc Type'
-- cpu.Partition_Number 'Part Nbr',
-- cpu.Partition_Type 'Part Type',
-- cpu.Partition_Mode 'Part Mode',
-- cpu.Entitled_Capacity 'EC',
-- cpu.Active_CPUs_in_Pool 'Act CPU',
-- cpu.Online_Virtual_CPUs 'OV CPU',
-- cpu.Active_Physical_CPUs 'Act Phy CPU'
from  $tRAC r left join  $tCPU cpu
on r.node_name=cpu.host_name
where nodes_count!=1 
-- and (OS='AIX' or OS is null)
order by r.node_name;
"

# Option RAC : calcul des processeurs
# export WHERE="db.DB_Edition='Enterprise' and db.v_opt_rac not in ('FALSE','') and cpu.os like '%AIX%'"
# print_proc_oracle $WHERE

#-------------------------------------------------------------------------------
# Option Partitioning
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option PARTITIONING en Enterprise Edition"
export SQL_NOT_IN="('SYS','SYSTEM','SYSMAN','MDSYS')"
echo "Les comptes $SQL_NOT_IN ne sont pas pris en compte"

# jointure avec la table des objets partionnés
# serveurs non AIX
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tCPU cpu, $tSegments seg, $tDB db
where cpu.Host_Name=db.Host_Name
and cpu.Host_Name=seg.Host_Name 
and db.DB_Edition='Enterprise' 
and cpu.os not like '%AIX%'
and seg.owner not in $SQL_NOT_IN 
group by seg.Host_Name, cpu.Marque, cpu.Model, cpu.OS, cpu.Processor_Type, 
cpu.Socket, cpu.Cores_per_Socket,  cpu.Total_Cores
having count(seg.Host_Name) > 0
order by cpu.Marque, cpu.Host_Name, cpu.os
;
"

# serveurs AIX
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tCPU cpu, $tSegments seg, $tDB db
where cpu.Host_Name=db.Host_Name
and cpu.Host_Name=seg.Host_Name 
and db.DB_Edition='Enterprise' 
and cpu.os like '%AIX%'
and seg.owner not in $SQL_NOT_IN
-- and db.Partitioning!='0' 
group by seg.Host_Name, cpu.Marque, cpu.Model, cpu.OS, cpu.Processor_Type, 
cpu.Socket, cpu.Cores_per_Socket,  cpu.Total_Cores
having count(seg.Host_Name) > 0
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os
;
"

#-------------------------------------------------------------------------------
# Option OLAP
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option OLAP en Enterprise Edition"
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and db.DB_Edition='Enterprise' and cpu.os not like '%AIX%'
and db.OLAP_Installed='TRUE' and (db.OLAP_Cubes not in ('','0','-942') or db.Analytic_Workspaces not in ('0','','-942'))
order by cpu.Marque, cpu.Host_Name, cpu.os;
"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and db.DB_Edition='Enterprise' and cpu.os like '%AIX%'
and db.OLAP_Installed='TRUE' and (db.OLAP_Cubes not in ('','0','-942') or db.Analytic_Workspaces not in ('0','','-942'))
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os;
"

#-------------------------------------------------------------------------------
# Option Datamining
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option DATAMINING en Enterprise Edition"
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and db.DB_Edition='Enterprise' and cpu.os not like '%AIX%'
and db.v_opt_dm!=''
order by cpu.Marque, cpu.Host_Name, cpu.os;
"
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and db.DB_Edition='Enterprise' and cpu.os like '%AIX%'
and db.v_opt_dm!=''
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os;
"

#-------------------------------------------------------------------------------
# Option Spatial/Locator
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option SPATIAL/LOCATOR en Enterprise Edition"
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and db.DB_Edition='Enterprise' and cpu.os not like '%AIX%'
and db.v_opt_spatial!=''
order by cpu.Marque, cpu.Host_Name, cpu.os;
"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and db.DB_Edition='Enterprise' and cpu.os like '%AIX%'
and db.v_opt_spatial!=''
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os;
"

#-------------------------------------------------------------------------------
# Option Tuning Pack
#-------------------------------------------------------------------------------
echo "Liste des serveurs qui utilisent TUNING PACK"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and cpu.os not like '%AIX%'
-- and db.DB_Edition='Enterprise'
and db.Tuning_Pack_Used!='0'
order by cpu.Marque, cpu.os, cpu.Host_Name;
"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and cpu.os like '%AIX%'
-- and db.DB_Edition='Enterprise'
and db.Tuning_Pack_Used!='0'
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os;
"

#-------------------------------------------------------------------------------
# Option Diagnostics Pack
#-------------------------------------------------------------------------------
echo "Liste des serveurs qui utilisent DIAGNOSTICS PACK"
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and cpu.os not like '%AIX%'
-- and db.DB_Edition='Enterprise'
-- and db.Tuning_Pack_Used='0' 
and db.Diag_Pack_Used!='0'
order by cpu.Marque, cpu.Host_Name, cpu.os;
"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and cpu.os like '%AIX%'
-- and db.DB_Edition='Enterprise'
-- and db.Tuning_Pack_Used='0'
and db.Diag_Pack_Used!='0'
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os;
"

echo "Liste des serveurs qui doivent être licenciés en DIAGNOSTICS PACK car ils utilisent TUNING PACK"
mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and cpu.os not like '%AIX%'
-- and db.DB_Edition='Enterprise'
and db.Tuning_Pack_Used!='0'
and db.Diag_Pack_Used='0'
order by cpu.Marque, cpu.os, cpu.Host_Name;
"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX
FROM $tCPU cpu, $tDB db
where cpu.Host_Name=db.Host_Name and cpu.os like '%AIX%'
-- and db.DB_Edition='Enterprise'
and db.Tuning_Pack_Used!='0'
and db.Diag_Pack_Used='0'
order by cpu.Machine_Serial_Number, cpu.Marque, cpu.Host_Name, cpu.os;
"
#-------------------------------------------------------------------------------
# FIN
#-------------------------------------------------------------------------------
