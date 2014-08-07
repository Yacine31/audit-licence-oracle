#!/bin/bash
# import CSV file
# 23/05/2014 : première version

# MYSQL_ARGS="--defaults-file=/etc/mysql/debian.cnf"
DB="test"
DELIM=";"

CSV="$1"
TABLE="$2"

[ "$CSV" = "" -o "$TABLE" = "" ] && echo "Syntax: $0 csvfile tablename" && exit 1

# mysql $MYSQL_ARGS $DB -e "
mysql -uroot -proot --local-infile --database=test -e "
LOAD DATA LOCAL INFILE '$(pwd)/$CSV' INTO TABLE $TABLE
FIELDS TERMINATED BY '$DELIM'
IGNORE 1 LINES
;
"
