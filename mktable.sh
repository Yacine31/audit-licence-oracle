#!/bin/bash
# create table and import CSV file
# 2014-05-14 : remplacer les espaces dans les noms des champs par underscore
# 2014-05-19 : le script est appelé maintenant depuis extract.sh

# MYSQL_ARGS="--defaults-file=/etc/mysql/debian.cnf"
DB="test"
DELIM=";"

CSV="$1"
#TABLE=`echo $1 | cut -d'.' -f1 `
TABLE="$2"

[ "$CSV" = "" -o "$TABLE" = "" ] && echo "Syntax: $0 csvfile tablename" && exit 1

FIELDS=$(head -1 "$CSV" | sed 's/ /_/g' | sed -e 's/'$DELIM'/` varchar(255),\n`/g' -e 's/\r//g')
FIELDS='`'"$FIELDS"'` varchar(255)'

#echo "$FIELDS" && exit
# echo "create table $TABLE ($FIELDS);"
# exit 0

# mysql $MYSQL_ARGS $DB -e "
mysql -uroot -proot --local-infile --database=test -e "
DROP TABLE IF EXISTS $TABLE;
CREATE TABLE $TABLE ($FIELDS);

LOAD DATA LOCAL INFILE '$(pwd)/$CSV' INTO TABLE $TABLE
FIELDS TERMINATED BY '$DELIM'
IGNORE 1 LINES
;
"
