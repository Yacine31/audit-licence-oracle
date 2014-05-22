#!/bin/bash
# le script va organiser la récupération des informations
# la creation des tables, la creation d'une synthse et la generation d'un rapport

# le script prend en paramètre un nom de projet, il servira de base 
# pour créer l'ensemble des fichiers et des tables

# ajouter la vérification du paramètre passé

#---
# Les différentes variables :
# nom du fichier CSV pour les bases
# nom du fichier CSV pour les serveurs
# noms des deux tables
#---
# répartoir courant pour les différents scripts
export D_DATE=`date +%Y.%m.%d-%H.%M.%S`

export SCRIPTS_DIR=/home/merlin/lms_scripts

# nom du projet qui servira de base pour la créations des fichiers de sortie, des tables et du fichier de rapport
[ "$1" = "" ] && echo "Syntax: $0 PROJECT_NAME" && exit 1

export PROJECT_NAME=$1
export DB_CSV="db_"${D_DATE}".out"
export CPU_CSV="cpu_"${D_DATE}".out"
export DB_TABLE=${PROJECT_NAME}"_db"
export CPU_TABLE=${PROJECT_NAME}"_cpu"

# modification du path
export PATH=$SCRIPTS_DIR:$PATH

# appeler la consolidation des fichiers lms_cpu
$SCRIPTS_DIR/lms_cpu.sh $CPU_CSV

# intégrer les données à la base mysql
echo "Création et import des données serveurs dans MySQL ..."
$SCRIPTS_DIR/mktable.sh $CPU_CSV $CPU_TABLE 2>/dev/null

# appeler le script de consolidation des données reviewlite
$SCRIPTS_DIR/lms_db.sh $DB_CSV 2>/dev/null

# intégrer les données à la base mysql
echo "Création et import des données database dans MySQL ..."
$SCRIPTS_DIR/mktable.sh $DB_CSV $DB_TABLE 2>/dev/null

# générer les données sur le partitioning 
$SCRIPTS_DIR/partitions.sh $PROJECT_NAME

# générer le rapport
# $SCRIPTS_DIR/reports_1.5.sh $DB_TABLE $CPU_TABLE
$SCRIPTS_DIR/reports.sh $PROJECT_NAME
