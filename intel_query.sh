#!/bin/bash
# interroger le site intel pour avoir les infos sur un processeur
# syntaxe : script.sh E5620

# 16/08/2014 - création


# Fonction usage
function usage {
	echo "#--------------------------------------------------------------------------------#"
	echo "# usage : $0 REF_PROC"
	echo "# exemple : $0 E5620"
	echo "#--------------------------------------------------------------------------------#"
}


#--------------------------------------------------------------------------------#
# vérification de la syntaxe
#--------------------------------------------------------------------------------#

if [[ "$@" == "" ]]; then usage; exit 1; fi

# la chaine de caractère en entrée ressemble généralement à 
# Intel(R) Xeon(R) CPU E5420 @ 2.50GHz
# on va extraire le 4ème champs
proc=$(echo "$@" | cut -d' ' -f4)

# requête auprès du serveur intel
wget -q http://ark.intel.com/search?q=$proc -O $proc.html > /dev/null

# conversion du html en text et recherche des mots Cores et Thread
html2text $proc.html > $proc.txt
nb_coeurs=$(grep '# of Cores' $proc.txt  | egrep -o '([0-9])+$')
nb_threads=$(grep '# of Threads' $proc.txt  | egrep -o '([0-9])+$')

if [[ ("$nb_coeurs" != "") ]]; then
	out="Processeur $proc : ($nb_coeurs) coeurs par socket"
fi

if [[ ("$nb_threads" != "") ]]; then
	out=$out" et ($nb_threads) threads par sockets"
fi

if [[ "$out" != "" ]]; then echo $out; fi

# rm -f $proc.html $proc.txt >/dev/null
