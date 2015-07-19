#!/bin/bash
# import CSV file
# 23/05/2014 : première version

# MYSQL_ARGS="--defaults-file=/etc/mysql/debian.cnf"
# Inclusion des fonctions
#export SCRIPTS_DIR="/home/merlin/lms_scripts"
. ${SCRIPTS_DIR}/fonctions.sh

DELIM=";"

CSV="$1"
TABLE="$2"

[ "$CSV" = "" -o "$TABLE" = "" ] && echo "Syntax: $0 csvfile tablename" && exit 1

# mysql $MYSQL_ARGS $DB -e "
mysql -u${MYSQL_USER} -p${MYSQL_PWD} --local-infile --database=${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '$(pwd)/$CSV' INTO TABLE $TABLE
FIELDS TERMINATED BY '$DELIM'
IGNORE 1 LINES
;
"
