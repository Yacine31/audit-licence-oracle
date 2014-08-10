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
# 10/08/2014 - export vers XML au format Excel

# MYSQL_ARGS="--defaults-file=/etc/mysql/debian.cnf"
DB="test"
PROJECT_NAME="$1"

[ "$PROJECT_NAME" = "" ] && echo "Syntax: $0 PROJECT_NAME" && exit 1

tDB=$PROJECT_NAME"_db"      # table qui contient les donnees db
tCPU=$PROJECT_NAME"_cpu"    # table qui contient les donnees des serveurs
tSegments=$PROJECT_NAME"_segments"  # table qui contient les objets partitionés
tDbaFeatures=$PROJECT_NAME"_dba_feature"  # table qui contient les options et packs utilisés
tVersion=$PROJECT_NAME"_version"  # table qui contient les versions
tCPUAIX=$PROJECT_NAME"_cpu_aix"	  # table pour le calcul des CPUs Oracle pour les serveurs AIX
tCPUNONAIX=$PROJECT_NAME"_cpu_non_aix"	  # table pour le calcul des CPUs Oracle pour les serveurs AIX
tRAC=$PROJECT_NAME"_rac"	# table avec les données RAC : nodes_count != 1
tSQLP=$PROJECT_NAME"_sqlprofiles"	# table avec les données SQL PROFILES

export DATE_JOUR=`date +%Y%m%d-%H%M%S`
export TMP_FILE=${PROJECT_NAME}.tmp
export XML_FILE=${PROJECT_NAME}_${DATE_JOUR}.xml

#-----------------------------------
# les fonction suivantes permettent d'écrire le fichier XML
# qui sera lu par Excel
#-----------------------------------

# entete du fichier xml 
function print_xml_header {
echo "
<?xml version=\"1.0\"?>
<?mso-application progid=\"Excel.Sheet\"?>
<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"
 xmlns:o=\"urn:schemas-microsoft-com:office:office\"
 xmlns:x=\"urn:schemas-microsoft-com:office:excel\"
 xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\"
 xmlns:html=\"http://www.w3.org/TR/REC-html40\">
 <DocumentProperties xmlns=\"urn:schemas-microsoft-com:office:office\">
  <Version>14.00</Version>
 </DocumentProperties>
 <OfficeDocumentSettings xmlns=\"urn:schemas-microsoft-com:office:office\">
  <AllowPNG/>
 </OfficeDocumentSettings>
 <Styles>
  <Style ss:ID=\"Default\" ss:Name=\"Normal\">
   <Alignment ss:Vertical=\"Bottom\"/>
   <Font ss:FontName=\"Calibri\" x:Family=\"Swiss\" ss:Size=\"10\" ss:Color=\"#000000\"/>
  </Style>
 <Style ss:ID=\"TableauTexte\">
   <Borders>
    <Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
   </Borders>
  </Style>
  <Style ss:ID=\"TableauEntete\">
   <Alignment ss:Horizontal=\"Center\" ss:Vertical=\"Bottom\"/>
   <Borders>
    <Border ss:Position=\"Bottom\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Left\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Right\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
    <Border ss:Position=\"Top\" ss:LineStyle=\"Continuous\" ss:Weight=\"1\"/>
   </Borders>
   <Font ss:FontName=\"Calibri\" x:Family=\"Swiss\" ss:Size=\"11\" ss:Color=\"#000000\" ss:Bold=\"1\"/>
   <Interior ss:Color=\"#92D050\" ss:Pattern=\"Solid\"/>
  </Style>
  </Styles>" >> $XML_FILE
}

# dernière balise : fin du fichier xml
function print_xml_footer {
	echo "</Workbook>" >> $XML_FILE
}

# à partir d'un fichier csv on insère dans le fichier XML : balise Worksheet
# 3 paramètres : nom de la feuille, fichier csv source et fichier xml destination

function print_xml_sheet {

# remplacer le séparateur par défaut \t par |
sed -ie 's/\t/|/g' $TMP_FILE

echo " <Worksheet ss:Name=\"$SHEET_NAME\">
  <Table>" >> $XML_FILE

# ss:ExpandedRowCount=\"8\" x:FullColumns=\"1\"
#   x:FullRows=\"1\" ss:DefaultColumnWidth=\"60\" ss:DefaultRowHeight=\"15\">
#   <Column ss:Width=\"80.25\" ss:Span=\"2\"/>
# " >> $XML_FILE

# insertion de l'entete d'abord : les noms des colonnes
echo "<Row>"    >> $XML_FILE
head -1 $TMP_FILE | tr '|' '\n' | while read c
do
        echo "<Cell ss:StyleID=\"TableauEntete\"><Data ss:Type=\"String\">$c</Data></Cell>"  >> $XML_FILE
done

# fin du header
echo "</Row>"   >> $XML_FILE

# insertion des données  : sed '1d' supprime la ligne qui contient l'entete
cat $TMP_FILE | sed '1d' | while read line
do
        echo "<Row>"  >> $XML_FILE
        # pour chaque ligne on va lire les champs et les insérer
        echo $line | tr '|' '\n' | while read c
        do
                echo "<Cell ss:StyleID=\"TableauTexte\"><Data ss:Type=\"String\">$c</Data></Cell>"   >> $XML_FILE
        done
        echo "</Row>"   >> $XML_FILE
done
echo "</Table>
</Worksheet>" >> $XML_FILE

}

#----------------------
#
#----------------------

function export_to_xml {
# export du résulat pour Excel
#export TMP_FILE=${PROJECT_NAME}.tmp
#export XML_FILE=${PROJECT_NAME}.xml
rm -f $TMP_FILE 2>/dev/null

mysql -uroot -proot --local-infile --database=$DB -e "$SQL" >> $TMP_FILE

# insertion des données de la requête dans le fichier XML
print_xml_sheet $SHEET_NAME $TMP_FILE $XML_FILE

}

#-----------------------------------
# Cette fonction est pour les autres serveurs non AIX
# Elle calcul le nombre de processeurs Oracle en fontion
# du type du processeur
#-----------------------------------

function print_proc_oracle {

export FROM=$(echo $@ | cut -d'|' -f1)
export WHERE=$(echo $@ | cut -d'|' -f2)

echo "Calcul des processeurs Oracle par serveur physique :"

mysql -uroot -proot --local-infile --database=$DB -e "
drop table if exists $tCPUAIX;
create table $tCPUNONAIX as

select distinct physical_server,Processor_Type,Socket,Cores_per_Socket,
	case Cores_per_Socket
		when 1 then @Core_Factor := 1
        end
	as Core_Factor,
	case left(reverse(Processor_Type),1)
        	when 5 then @Core_Factor := 0.75
	        when 6 then @Core_Factor := 1
        	when 7 then @Core_Factor := 1
	end 
	as Core_Factor,
	CEILING(@Core_Count * @Core_Factor) as CPU_Oracle
-- from $tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name
from $FROM
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

select * from cpu_oracle;
"

mysql -ss -uroot -proot --local-infile --database=$DB -e "
select concat('Total des processeurs Oracle : ', sum(Proc_Oracle_Calcules)) from cpu_oracle;
"
}
#-----------------------------------
# Cette fonction est spécifique au serveurs AIx,
# Elle calcul le nombre de processeurs Oracle en fontion
# du type de la partition LPAR
#-----------------------------------

function print_proc_oracle_aix {

export FROM=$(echo $@ | cut -d'|' -f1)
export WHERE=$(echo $@ | cut -d'|' -f2)

echo "Calcul des processeurs Oracle par serveur physique :"

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
	CEILING(@Core_Count * @Core_Factor) as CPU_Oracle
-- from $tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name
from $FROM
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

select * from cpu_oracle;
"

mysql -ss -uroot -proot --local-infile --database=$DB -e "
select concat('Total des processeurs Oracle : ', sum(Proc_Oracle_Calcules)) from cpu_oracle;
"
}


# les clauses SQL communes à certaines requêtes :
export ORDERBY="c.physical_server, d.host_name"

export SELECT_EE_AIX="SELECT distinct
c.physical_server 'Physical Server',
-- c.Host_Name Host,
d.Host_Name Host,
c.Model,
c.OS,
c.Processor_Type 'Proc Type',
c.Partition_Number 'Part Nbr',
c.Partition_Type 'Part Type',
c.Partition_Mode 'Part Mode',
c.Entitled_Capacity 'EC',
c.Active_CPUs_in_Pool 'Act CPU',
c.Online_Virtual_CPUs 'OV CPU',
c.Active_Physical_CPUs 'Act Phy CPU'
"

export SELECT_EE_NON_AIX="
SELECT distinct
c.physical_server, d.Host_Name, c.Marque, c.Model, c.OS, c.Processor_Type,
c.Socket, c.Cores_per_Socket 
-- ,  c.Total_Cores
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
mysql -ss -uroot -proot --local-infile --database=$DB -e "
select '----------------------------------' from dual;
select concat('Nombre de serveurs traités : ', count(*)) from $tCPU;
select '----------------------------------' from dual;
select 'Répartition des serveurs par OS   : ' from dual;

select count(*), os from $tCPU group by os;

select '----------------------------------' from dual;
select concat('Nombre de base de données  : ', count(*)) from $tDB;
select '----------------------------------' from dual;
select 'Les bases par editions et par version : ' from dual;

select count(*), DB_EDITION, DB_VERSION_MAJ from $tDB group by DB_EDITION, DB_VERSION_MAJ;
select '----------------------------------' from dual;
"


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

export SELECT=" distinct c.physical_server, v.Host_Name, c.Marque, c.Model, c.Processor_Type, c.OS, c.Socket "
export WHERE=" v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and c.os not like '%AIX%' "
export ORDERBY=" c.physical_server, c.Host_Name, c.os "

SQL="SELECT $SELECT
FROM $tVersion v left join $tCPU c on c.Host_Name=v.Host_Name
where $WHERE order by $ORDERBY
;
"

mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# export du résulat pour Excel
#export TMP_FILE=${PROJECT_NAME}.tmp
#export XML_FILE=${PROJECT_NAME}.xml
#rm -f $TMP_FILE $XML_FILE 2>/dev/null

# insertion du header du fichier xml :
print_xml_header $XML_FILE

mysql -uroot -proot --local-infile --database=$DB -e "$SQL" >> $TMP_FILE

# insertion des données de la requête dans le fichier XML
# fonction : "Nom de la feuille (sans espace)" "fichier CSV" "fichier XML"
export SHEET_NAME=SE
export_to_xml 

export WHERE=" v.banner like '%Oracle%' and v.banner not like '%Enterprise%' and c.os like '%AIX%' "

mysql -uroot -proot --local-infile --database=$DB -e "
SELECT $SELECT
FROM $tVersion v left join $tCPU c
on c.Host_Name=v.Host_Name
where $WHERE
order by $ORDERBY
;
"

#-------------------------------------------------------------------------------
# Base de données en Enterprise Edition
#-------------------------------------------------------------------------------
echo "Les serveurs en Enterprise Edition"

export SELECT_NON_AIX="distinct c.physical_server, d.Host_Name, c.Marque, c.Model, c.OS, c.Processor_Type, c.Socket, c.Cores_per_Socket "
export WHERE="d.DB_Edition='Enterprise' and c.os not like '%AIX%'"
export ORDERBY="c.physical_server, c.Host_Name, c.os"

export SQL="select $SELECT_NON_AIX
FROM $tDB d left join $tCPU c 
on c.Host_Name=d.Host_Name
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# insertion des données de la requête dans le fichier XML
export SHEET_NAME=EE
export_to_xml

echo "--> Les serveur AIX avec le même numéro de série sont sur le même chassis : à valider avec le client"

export SELECT_AIX="distinct c.physical_server 'Physical Server',
d.Host_Name Host,
c.Model,
c.OS,
c.Processor_Type 'Proc Type',
c.Partition_Number 'Part Nbr',
c.Partition_Type 'Part Type',
c.Partition_Mode 'Part Mode',
c.Entitled_Capacity 'EC',
c.Active_CPUs_in_Pool 'Act CPU',
c.Online_Virtual_CPUs 'OV CPU',
c.Active_Physical_CPUs 'Act Phy CPU'
"

export WHERE="d.DB_Edition='Enterprise' and c.os like '%AIX%'"

SQL="select $SELECT_AIX
FROM $tDB d left join $tCPU c
on c.Host_Name=d.Host_Name
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# insertion des données de la requête dans le fichier XML
export SHEET_NAME=EE_AIX
export_to_xml

# Base de données en Enterprise Edition : calcul des processeurs
export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="d.DB_Edition='Enterprise' and c.os='AIX'"

print_proc_oracle_aix $FROM'|'$WHERE

# fnPrintLegende 

#-------------------------------------------------------------------------------
# Option RAC 
#-------------------------------------------------------------------------------
echo "Les serveurs avec option RAC en Enterprise Edition"

export SQL="$SELECT_EE_NON_AIX
FROM $tDB d left join $tCPU c 
on c.Host_Name=d.Host_Name
where d.DB_Edition='Enterprise' and d.v_opt_rac not in ('FALSE','') and c.os not like '%AIX%'
order by c.Marque, c.os, c.Host_Name;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# insertion des données de la requête dans le fichier XML
export SHEET_NAME=RAC
export_to_xml

# TODO : vérifier le résultat à afficher, la colonne OS pose pb avec la valeur NULL

echo "------------------- NOUVEAU CALCUL ----------------"
echo "--- Les lignes avec NULL comme valeur, indiquent des serveurs sans le résultats LMS_CPUQ "
echo "---------------------------------------------------"

export SQL="select distinct 
c.physical_server 'Physical Server',
c.Host_Name 'Host Name',
r.node_name 'Node name',
-- r.instance_name, 
d.db_edition 'Edition',
c.Model,
c.OS,
c.Processor_Type 'Proc Type'
from $tRAC r left join $tCPU c 
	left join $tDB d on c.host_name=d.host_name 
	on r.node_name=c.host_name 
where r.nodes_count!=1
order by d.db_edition, c.physical_server, r.node_name;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# insertion des données de la requête dans le fichier XML
export SHEET_NAME=RAC2
export_to_xml

# Option RAC : calcul des processeurs
export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="d.DB_Edition='Enterprise' and d.v_opt_rac not in ('FALSE','') and c.os='AIX'"

print_proc_oracle_aix $FROM'|'$WHERE


#-------------------------------------------------------------------------------
# Option Partitioning
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option PARTITIONING en Enterprise Edition"
export SQL_NOT_IN="('SYS','SYSTEM','SYSMAN','MDSYS')"
echo "Les comptes $SQL_NOT_IN ne sont pas pris en compte"

# jointure avec la table des objets partionnés
# serveurs non AIX
export SQL="$SELECT_EE_NON_AIX
FROM $tCPU c, $tSegments seg, $tDB d
where c.Host_Name=d.Host_Name
and c.Host_Name=seg.Host_Name 
and d.DB_Edition='Enterprise' 
and c.os not like '%AIX%'
and seg.owner not in $SQL_NOT_IN 
group by seg.Host_Name, c.Marque, c.Model, c.OS, c.Processor_Type, 
c.Socket, c.Cores_per_Socket
-- ,  c.Total_Cores
having count(seg.Host_Name) > 0
order by c.Marque, c.Host_Name, c.os
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# insertion des données de la requête dans le fichier XML
export SHEET_NAME=PART
export_to_xml

# serveurs AIX
export SQL="$SELECT_EE_AIX
FROM $tCPU c, $tSegments seg, $tDB d
where c.Host_Name=d.Host_Name
and c.Host_Name=seg.Host_Name 
and d.DB_Edition='Enterprise' 
and c.os like '%AIX%'
and seg.owner not in $SQL_NOT_IN
-- and d.Partitioning!='0' 
group by seg.Host_Name, c.Marque, c.Model, c.OS, c.Processor_Type, 
c.Socket, c.Cores_per_Socket
-- ,  c.Total_Cores
having count(seg.Host_Name) > 0
order by c.Machine_Serial_Number, c.Marque, c.Host_Name, c.os
;
"

mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# insertion des données de la requête dans le fichier XML
export SHEET_NAME=PART_AIX
export_to_xml

# Option Partitioning : calcul des processeurs
export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="d.DB_Edition='Enterprise' and d.V_OPT_PART!=0 and c.os='AIX'"

print_proc_oracle_aix $FROM'|'$WHERE

#-------------------------------------------------------------------------------
# Option OLAP
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option OLAP en Enterprise Edition"

export SQL="$SELECT_EE_NON_AIX
FROM $tCPU c, $tDB d
where c.Host_Name=d.Host_Name and d.DB_Edition='Enterprise' and c.os not like '%AIX%'
and d.OLAP_Installed='TRUE' and (d.OLAP_Cubes not in ('','0','-942') or d.Analytic_Workspaces not in ('0','','-942'))
order by c.Marque, c.Host_Name, c.os;
"

mysql -uroot -proot --local-infile --database=$DB -e "$SQL"

# insertion des données de la requête dans le fichier XML
export SHEET_NAME=OLAP
export_to_xml

export SQL="$SELECT_EE_AIX
FROM $tCPU c left join $tDB d
on c.Host_Name=d.Host_Name 
where d.DB_Edition='Enterprise' and c.os like '%AIX%'
and d.OLAP_Installed='TRUE' and (d.OLAP_Cubes not in ('','0','-942') or d.Analytic_Workspaces not in ('0','','-942'))
order by c.Machine_Serial_Number, c.Marque, c.Host_Name, c.os;
"

mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=OLAP_AIX
export_to_xml

# Option OLAP : calcul des processeurs
export WHERE="d.DB_Edition='Enterprise' and c.os='AIX'"
export WHERE=$WHERE" and d.OLAP_Installed='TRUE' and (d.OLAP_Cubes not in ('','0','-942') or d.Analytic_Workspaces not in ('0','','-942'))"
export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"

print_proc_oracle_aix $FROM'|'$WHERE


#-------------------------------------------------------------------------------
# Option Datamining
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option DATAMINING en Enterprise Edition"

export FROM="$tCPU c left join $tDB d on c.Host_Name=d.Host_Name"
export WHERE="d.DB_Edition='Enterprise' and c.os not like '%AIX%' and d.v_opt_dm!=''"
export ORDERBY="c.Marque, c.Host_Name, c.os"

export SQL="$SELECT_EE_NON_AIX
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=DataMining
export_to_xml

export WHERE="d.DB_Edition='Enterprise' and c.os='AIX' and d.v_opt_dm!=''"

export SQL="$SELECT_EE_AIX
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=DataMining_AIX
export_to_xml

# Option OLAP : calcul des processeurs
export WHERE="d.DB_Edition='Enterprise' and c.os='AIX' and d.v_opt_dm!=''"
export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"

print_proc_oracle_aix $FROM'|'$WHERE

#-------------------------------------------------------------------------------
# Option Spatial/Locator
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option SPATIAL/LOCATOR en Enterprise Edition"

export FROM="$tCPU c left join $tDB d on c.Host_Name=d.Host_Name"
export WHERE="d.DB_Edition='Enterprise' and (c.os not like '%AIX%' or c.os is null) and d.v_opt_spatial!=''"



export SQL="$SELECT_EE_NON_AIX
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=SPATIAL
export_to_xml

# export WHERE="d.DB_Edition='Enterprise' and (c.os like '%AIX%' or c.os is null) and d.v_opt_spatial!=''"
export WHERE="d.DB_Edition='Enterprise' and c.os='AIX' and d.v_opt_spatial!=''"

export SQL="$SELECT_EE_AIX
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=SPATIAL_AIX
export_to_xml

# Option OLAP : calcul des processeurs
export FROM="$tDB d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="d.DB_Edition='Enterprise' and c.os='AIX' and d.v_opt_spatial!=''"

print_proc_oracle_aix $FROM'|'$WHERE


#-------------------------------------------------------------------------------
# Option Active Data Guard
#-------------------------------------------------------------------------------
echo "Liste des serveurs avec option Active Data Guard en Enterprise Edition"

export SQL="$SELECT_EE_NON_AIX
FROM $tDbaFeatures d left join $tCPU c on c.Host_Name=d.Host_Name 
where 
-- d.DB_Edition='Enterprise' and 
(c.os not like '%AIX%' or c.os is null)
and d.name like 'Active Data Guard%'
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=ActiveDG
export_to_xml

export SQL="$SELECT_EE_AIX, d.version
FROM $tDbaFeatures d left join $tCPU c on c.Host_Name=d.Host_Name 
where 
-- d.DB_Edition='Enterprise' and 
(c.os like '%AIX%' or c.os is null) 
and d.name like 'Active Data Guard%'
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=ActiveDG_AIX
export_to_xml


# Option Active Data Guard : calcul des processeurs
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name like '%Active Data Guard%'"

print_proc_oracle_aix $FROM'|'$WHERE

#-------------------------------------------------------------------------------
# Option Tuning Pack
#-------------------------------------------------------------------------------
echo "Liste des serveurs qui utilisent TUNING PACK"

export TUNING_PACK_FEATURES="'SQL Access Advisor','SQL Monitoring and Tuning pages','SQL Performance Analyzer','SQL Profile'"
export TUNING_PACK_FEATURES=$TUNING_PACK_FEATURES",'SQL Tuning Advisor','SQL Tuning Set','SQL Tuning Set (user)'"

export FROM="$tCPU c, $tDB d"
export WHERE="c.Host_Name=d.Host_Name and c.os not like '%AIX%' and d.Tuning_Pack_Used!='0'"
export ORDERBY="d.db_edition, c.physical_server, c.host_name"

export SQL="$SELECT_EE_NON_AIX, d.DB_Edition
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=Tuning
export_to_xml

export WHERE="c.Host_Name=d.Host_Name and c.os='AIX' and d.Tuning_Pack_Used!='0'"

export SQL="$SELECT_EE_AIX, d.DB_Edition
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=Tuning_AIX
export_to_xml

# Option Tuning Pack : calcul des processeurs
# print_proc_oracle_aix $WHERE
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in ($TUNING_PACK_FEATURES)"

print_proc_oracle_aix $FROM'|'$WHERE


#-------------------------------------------------------------------------------
# Option Diagnostics Pack
#-------------------------------------------------------------------------------
echo "Liste des serveurs qui utilisent DIAGNOSTICS PACK"

export DIAG_PACK_FEATURES="'ADDM','Automatic Database Diagnostic Monitor','Automatic Maintenance - SQL Tuning Advisor'"
export DIAG_PACK_FEATURES=$DIAG_PACK_FEATURES",'Automatic Workload Repository','AWR Baseline','AWR Report','Active Session History'"
export DIAG_PACK_FEATURES=$DIAG_PACK_FEATURES",'EM Performance Page'"

export FROM="$tCPU c, $tDB d"
export WHERE="c.Host_Name=d.Host_Name and c.os not like '%AIX%' and d.Diag_Pack_Used!='0'"
# export ORDERBY="d.db_edition, c.physical_server, c.host_name"
export ORDERBY="c.physical_server, c.host_name"

export SQL="$SELECT_EE_NON_AIX, d.db_edition
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=Diag
export_to_xml

export WHERE="c.Host_Name=d.Host_Name and c.os='AIX' and d.Diag_Pack_Used!='0'"

export SQL="$SELECT_EE_AIX, d.db_edition
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=DIAG_AIX
export_to_xml

# Option Diagnostics Pack : calcul des processeurs
# print_proc_oracle_aix $WHERE
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in ($DIAG_PACK_FEATURES)"

print_proc_oracle_aix $FROM'|'$WHERE

echo "Liste des serveurs qui doivent être licenciés en DIAGNOSTICS PACK car ils utilisent TUNING PACK"
:<<COMM
export FROM="$tCPU c, $tDB d"
export WHERE="c.Host_Name=d.Host_Name and c.os not like '%AIX%' and d.Tuning_Pack_Used!='0' and d.Diag_Pack_Used='0'"
export ORDREBY="d.db_edition, c.physical_server, c.host_name"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_NON_AIX, d.db_edition
FROM $FROM
where $WHERE
order by $ORDERBY
;
"

export WHERE="c.Host_Name=d.Host_Name and c.os='AIX' and d.Tuning_Pack_Used!='0' and d.Diag_Pack_Used='0'"

mysql -uroot -proot --local-infile --database=$DB -e "
$SELECT_EE_AIX, d.db_edition
FROM $FROM
where $WHERE
order by $ORDERBY
;"
COMM

# Option Diagnostics Pack : calcul des processeurs
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in ($TUNING_PACK_FEATURES)"
export WHERE=$WHERE" and name not in ($DIAG_PACK_FEATURES)"

print_proc_oracle_aix $FROM'|'$WHERE

#-------------------------------------------------------------------------------
# TDE : 
#-------------------------------------------------------------------------------
echo "----------------------------------------------------------------------------------"
echo " Les serveurs qui utilisent des fonctionnalités du pack Oracle Advanced Security :"
echo ""

export ADVANCED_SEC_FEATURES="'Transparent Data Encryption%'"

export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in ($ADVANCED_SEC_FEATURES)"
# export ORDERBY="c.physical_server, c.host_name"

export SQL="$SELECT_EE_NON_AIX
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=AdvancedSec
export_to_xml

# SErveurs AIX
export SQL="$SELECT_EE_AIX
FROM $FROM
where $WHERE
order by $ORDERBY
;
"
mysql -uroot -proot --local-infile --database=$DB -e "$SQL"
# insertion des données de la requête dans le fichier XML
export SHEET_NAME=AdvancedSecAix
export_to_xml

# Option Diagnostics Pack : calcul des processeurs
# print_proc_oracle_aix $WHERE
export FROM="$tDbaFeatures d left join $tCPU c on d.HOST_NAME=c.Host_Name"
export WHERE="name in ($ADVANCED_SEC_FEATURES)"


print_proc_oracle_aix $FROM'|'$WHERE




:<<COMMSQLP
#-------------------------------------------------------------------------------
# SQL Profiles
#-------------------------------------------------------------------------------
echo "SQL PROFILES : les serveurs qui n utilisent pas Tuning mais seulement SQL Profiles"
echo "Si des noms de serveurs sont renvoyés, il faut les ajouter dans le calcul des licences Tuning Pack"
mysql -uroot -proot --local-infile --database=$DB -e "
select distinct d.host_name 
from $tDB d, $tSQLP s 
where 
  s.instance_name=d.instance_name 
  and d.Tuning_Pack_Used=0 
  and s.name is not null order by 1;
"

echo "SQL PROFILES : les serveurs qui n utilisent NI Tuning NI DIAG, mais seulement SQL Profiles"
echo "Si des noms de serveurs sont renvoyés, il faut les ajouter dans le calcul des licences Diag ET Tuning Pack"
mysql -uroot -proot --local-infile --database=$DB -e "
select distinct d.host_name 
from $tDB d, $tSQLP s 
where 
  s.instance_name=d.instance_name 
  and d.Tuning_Pack_Used=0 
  and d.diag_pack_used=0
  and s.name is not null order by 1;
"

# Option Tuning Pack : calcul des processeurs
print_proc_oracle_aix $WHERE

COMMSQLP
print_xml_footer $XML_FILE

#-------------------------------------------------------------------------------
# FIN
#-------------------------------------------------------------------------------
