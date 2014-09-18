set @features=concat(@features,') ');

-- ('ADDM','Automatic Database Diagnostic Monitor','Automatic Workload Repository','AWR Baseline','AWR Report','Diagnostic Pack','EM Notification','EM Performance Page','EM Report','EM_FU_TEMPLATES')

-- ('Real-Time SQL Monitoring','SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile','SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)')


select distinct c.PHYSICAL_SERVER , -- c.Host_Name, 
d.HOST_NAME, d.INSTANCE_NAME, d.name, c.Processor_Type, c.Partition_Mode, c.Entitled_Capacity 'EC', c.Online_Virtual_CPUs 'OVC', c.Active_CPUs_in_Pool 'ACiP'
-- , c.Active_Physical_CPUs
from cma_dba_feature d left join cma_cpu c on d.HOST_NAME=c.Host_Name 
-- where name in @features
where name not in ('ADDM','Automatic Database Diagnostic Monitor','Automatic Workload Repository','AWR Baseline','AWR Report','Diagnostic Pack','EM Notification','EM Performance Page','EM Report','EM_FU_TEMPLATES')
and name in ('Real-Time SQL Monitoring','SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile','SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)')
order by c.PHYSICAL_SERVER , d.HOST_NAME, d.INSTANCE_NAME
;


select distinct c.PHYSICAL_SERVER , -- c.Host_Name, 
d.HOST_NAME,
-- ,d.INSTANCE_NAME, 
c.Processor_Type, c.Partition_Mode, c.Entitled_Capacity 'EC', c.Online_Virtual_CPUs 'OVC', c.Active_CPUs_in_Pool 'ACiP', c.Active_Physical_CPUs 'APC',
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
        CEILING(@Core_Count * @Core_Factor) as CPU_Oracle

from cma_dba_feature d left join cma_cpu c on d.HOST_NAME=c.Host_Name 
-- where name in @features
where name not in ('ADDM','Automatic Database Diagnostic Monitor','Automatic Workload Repository','AWR Baseline','AWR Report','Diagnostic Pack','EM Notification','EM Performance Page','EM Report','EM_FU_TEMPLATES')
and name in ('Real-Time SQL Monitoring','SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile','SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)')
-- and physical_server is not null
order by c.PHYSICAL_SERVER , d.HOST_NAME, d.INSTANCE_NAME
;



select r.physical_server, r.Processor_Type, r.core_factor, sum(r.CPU_Oracle) 'Total Proc Oracle' from (
select distinct c.PHYSICAL_SERVER , -- c.Host_Name, 
d.HOST_NAME,
-- ,d.INSTANCE_NAME, 
c.Processor_Type, c.Partition_Mode, c.Entitled_Capacity 'EC', c.Online_Virtual_CPUs 'OVC', c.Active_CPUs_in_Pool 'ACiP', c.Active_Physical_CPUs 'APC',
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
        CEILING(@Core_Count * @Core_Factor) as CPU_Oracle

from cma_dba_feature d left join cma_cpu c on d.HOST_NAME=c.Host_Name 
-- where name in @features
where name not in ('ADDM','Automatic Database Diagnostic Monitor','Automatic Workload Repository','AWR Baseline','AWR Report','Diagnostic Pack','EM Notification','EM Performance Page','EM Report','EM_FU_TEMPLATES')
and name in ('Real-Time SQL Monitoring','SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile','SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)')
and physical_server is not null
order by c.PHYSICAL_SERVER , d.HOST_NAME, d.INSTANCE_NAME) r
where r.physical_server is not null
group by r.physical_server
;

-- calcul de la somme des processeurs Oracle
select sum(s.Total_Proc_Oracle) as 'Total Proc Oracle' from (
select r.physical_server, r.Processor_Type, r.core_factor, sum(r.CPU_Oracle) 'Total_Proc_Oracle' from (
select distinct c.PHYSICAL_SERVER , -- c.Host_Name, 
d.HOST_NAME,
-- ,d.INSTANCE_NAME, 
c.Processor_Type, c.Partition_Mode, c.Entitled_Capacity 'EC', c.Online_Virtual_CPUs 'OVC', c.Active_CPUs_in_Pool 'ACiP', c.Active_Physical_CPUs 'APC',
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
        CEILING(@Core_Count * @Core_Factor) as CPU_Oracle

from cma_dba_feature d left join cma_cpu c on d.HOST_NAME=c.Host_Name 
-- where name in @features
where name not in ('ADDM','Automatic Database Diagnostic Monitor','Automatic Workload Repository','AWR Baseline','AWR Report','Diagnostic Pack','EM Notification','EM Performance Page','EM Report','EM_FU_TEMPLATES')
and name in ('Real-Time SQL Monitoring','SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile','SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)')
and physical_server is not null
order by c.PHYSICAL_SERVER , d.HOST_NAME, d.INSTANCE_NAME) r
where r.physical_server is not null
group by r.physical_server) s
;
