PROJECT_NAME="cma"
tDB=$PROJECT_NAME"_db"      # table qui contient les donnees db
tCPU=$PROJECT_NAME"_cpu"    # table qui contient les donnees des serveurs
tSegments=$PROJECT_NAME"_segments"  # table qui contient les objets partitionés
tDbaFeatures=$PROJECT_NAME"_dba_feature"  # table qui contient les options et packs utilisés
tVersion=$PROJECT_NAME"_version"  # table qui contient les versions
tCPUAIX=$PROJECT_NAME"_cpu_aix"   # table pour le calcul des CPUs Oracle pour les serveurs AIX
tRAC=$PROJECT_NAME"_rac"        # table avec les données RAC : nodes_count != 1
tSQLP=$PROJECT_NAME"_sqlprofiles"       # table avec les données SQL PROFILES


function print_proc_oracle {

echo $@
export FROM=$(echo $@ | cut -d'|' -f1)
export WHERE=$(echo $@ | cut -d'|' -f2)

echo "WHERE=$WHERE"
echo "FROM=$FROM"


exit 

# echo "Calcul des processeurs Oracle par serveur physique :"
echo "WHERE=$WHERE"

mysql -uroot -proot --local-infile --database=$DB -e "
drop table if exists $tCPUAIX;
create table $tCPUAIX as

select distinct physical_server, Partition_Mode,
Partition_Type, Active_Physical_CPUs, Entitled_Capacity, Active_CPUs_in_Pool, Online_Virtual_CPUs, Processor_Type,
        case Partition_Mode
                when 'Uncapped' then @Core_Count := least(cast(Active_CPUs_in_Pool as signed), cast(Online_Virtual_CPUs as signed))
                when 'Capped' then @Core_Count := cast(Entitled_Capacity as decimal(3,1))
                when 'Donating' then @Core_Count := cast(Entitled_Capacity as decimal(3,1))
        end
        as Core_Count,
        case left(reverse(Processor_Type),1)
                when 5 then @Core_Factor := 0.75
                when 6 then @Core_Factor := 1
                when 7 then @Core_Factor := 1
        end
        as Core_Factor,
        CEILING(cast(@Core_Count as decimal(4,2))* cast(@Core_Factor as decimal(4,2))) as CPU_Oracle
from $tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name
where $WHERE;
--
-- Ensuite on calcul le nombre de processeurs Oracle par Serveur Physique
--
drop table if exists cpu_oracle;
create table cpu_oracle as
select
        physical_server,
        sum(CPU_Oracle) 'Total_Proc',
        Core_Factor,
        Active_Physical_CPUs,
        if (sum(CPU_Oracle)<Active_Physical_CPUs,sum(CPU_Oracle),Active_Physical_CPUs) 'Proc_Oracle_Calcules'
from $tCPUAIX
group by physical_server;

select * from cpu_oracle;"

}

# Base de données en Enterprise Edition : calcul des processeurs
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="db.DB_Edition='Enterprise' and cpu.os='AIX'"
print_proc_oracle $FROM'|'$WHERE



