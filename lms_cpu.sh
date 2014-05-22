#!/bin/bash 
# 18/07/2013 - bcp de chose fonctionnent, reste a faire AIX
# 18/07/2013 - ajout de la partie AIX avec tous les param�tres des partitions AIX
# 14/11/2013 - correction du calcul des coeurs et processeurs pour les machines Windows
# 28/11/2013 - reecriture pour plus de lisibilit� et initialisation des variables a chaque boucle
# 05/12/2013 - correction sur AIX : les caract�re accentues posent pb : Mod�le est transform� en Mod\350le
#		la commande sed -n 'l' NOMFICHIER => permet d'afficher ces caract�re et un sed permet de les remplacer
# 06/05/2014 - reorganisation du script, les noms des variables, les entetes, ....
# 19/05/2014 - adaptation du script pour qu'il soit appel� depuis le script parincipal extract.sh
# 22/05/2014 - extraction de Node Name, Partition Name et Partition Number pour les serveurs AIX

:<<README
Postulat de depart :
- collecte des donn�es : 
  + tous les fichiers sont dans le m�me r�pertoire et portent le nom XXXXX-lms_cpuq.txt
- le script suivant va parcourir tous les fichier g�n�rer un fichier csv
README

# DATE_JOUR=`date +%Y.%m.%d-%H.%M.%S`
# OUTPUT_FILE="cpuq_"${DATE_JOUR}".csv"

[ "$1" = "" ] && echo "Usage : $0 OUTPUT_CSV_FILE" && exit 1

OUTPUT_FILE=$1

function print_header {
	# insertion des entetes dans le fichier de sortie :
	echo -e "Host Name;\
	OS;\
	Marque;\
	Model;\
	Virtuel;\
	Processor Type;\
	Socket;\
	Cores per Socket;\
	Total Cores;\
	Node Name;\
	Partition Name;\
	Partition Number;\
	Partition Type;\
	Partition Mode;\
	Entitled Capacity;\
	Active CPUs in Pool;\
	Online Virtual CPUs" >> $OUTPUT_FILE
}

function init_variables {
	HNAME=""
	OS=""
	RELEASE=""
	MARQUE=""
	MODEL=""
	VIRTUEL=""
	TYPE_PROC=""
	NB_SOCKETS=""
	NB_COEURS=""
	NB_COEURS_TOTAL=""
	Node_Name=""
	Partition_Name=""
	Partition_Number=""
	Partition_Type=""
	Partition_Mode=""
	Entitled_Capacity=""
	Active_CPUs_in_Pool=""
	Online_Virtual_CPUs=""
}

function get_hostname {
	HNAME=`cat $1 | grep '^Machine Name' | sort | uniq | cut -d'=' -f2 | sed 's/\\r//'`
	# HNAME=`sed -n 'l' $1 | grep '^Machine Name' | sort | uniq | cut -d'=' -f2 | sed 's/\r//'`
        # sinon on est en pr�sence de Windows
        if [ ! "$HNAME" ]; then
                HNAME=`cat $1 | grep '^Computer Name: ' | sort | uniq | sed 's/Computer Name: //' | sed 's/\\r//'`
        fi
}

function get_os {
	# cette ligne marche pour les Unix et Linux, SunOS, AIX
	OS=`cat $1 | grep '^Operating System Name' | sort | uniq | cut -d'=' -f2 `

	# pour les Unix on r�cup�re aussi la release
	RELEASE=`cat $f | grep "^Operating System Release=" | sort | uniq | cut -d'=' -f2`
	
	# si la chaine de caract�re est vide, alors on cherche un Windows francais 2008
	if [ ! "$OS" ]; then
		OS=`cat $1 | grep "d'exploitation" | cut -d' ' -f3-`
	fi

	# sinon c 'est un windows anglais 
	if [ ! "$OS" ]; then
		OS=`cat $1 | grep "^Operating System" -A1 | grep "Caption: " | tr -s ' ' | sed 's/ Caption: //' | sed 's/\\r//'`
	fi
}

function get_marque {
	# cette ligne marche pour Linux
	MARQUE=`cat $f | grep -v 'grep' | grep -i 'System Information' -A1 | grep -i 'Manufacturer' | cut -d':' -f2 |  sed 's/^ *//g' | head -1`
	
	# windows 2003, 2008
	if [ ! "$MARQUE" ]; then
		MARQUE=`cat $f | grep -i '^System$' -A2 | grep -i 'Manufacturer:' | sed 's/  Manufacturer: //' | head -1`
	fi
}

function get_modele {
	# cette linux marche pour linux
	MODEL=`cat $f | grep -v 'grep' | grep -i 'System Information' -A2 | grep -i 'Product Name:' | cut -d':' -f2 |  sed 's/^ *//g' | head -1`
	
	# model pour HP-UX
	if [ ! "$MODEL" ]; then
		MODEL=`cat $f | grep -v 'grep' | grep -i 'MACHINE_MODEL' -A1 | grep -v 'MACHINE_MODEL' | grep -v '\-\-' | sort | uniq`
	fi

	# modele pour windows 2003
	if [ ! "$MODEL" ]; then
		MODEL=`cat $f | grep -i '^System$' -A2 | grep -i 'Model:' | sed 's/  Model: //' | head -1`
	fi
	
	# modele pour SunOS
	if [ ! "$MODEL" ]; then
		MODEL=`cat $f | grep -i '/usr/sbin/prtdiag' -A1 | tail -1 | cut -d':' -f2 |  sed 's/^ *//g' | head -1`
	fi

	# MODEL pour Aix
	if [ ! "$MODEL" ]; then
		MODEL=`cat $f | grep -A1 '/usr/sbin/prtconf' | tail -1 | cut -d':' -f2 | sed 's/^ //'| head -1`
		# la ligne suivante ne marche pas en cas de systeme francais � cause des caracteres accentues
		# MODEL=`cat $f | grep -i '^System Model:' | tail -1 | sed 's/^System Model: //g'`
	fi
}

function get_processor_type {

	case $OS in
		'SunOS' )
			case $RELEASE in
				'5.10' )
					TYPE_PROC=`cat $f | grep -A1 "^The physical processor has" | tail -1 | awk '{print $1}'`
				;;
				'SunOS 5.9' )
					TYPE_PROC=`cat $f | grep -A2 "^CPU" | tail -1 | awk '{print $5}'`
				;;
			esac
		;;

		* )
			TYPE_PROC="----"
		;;
	esac

	# cette ligne marche pour linux
	TYPE_PROC=`cat $f | grep -i '^model name' | sort | uniq | cut -d':' -f2 |  sed 's/^ *//g'`
	
	# windows 2003 et 2008
	if [ ! "$TYPE_PROC" ]; then
		TYPE_PROC=`cat $f | grep -i '^Processors$' -A1 | grep -i 'CPU Name:' | sed 's/  CPU Name: //'`
	fi
	# TYPE PROC pour HP-UX B.11.31
	if [ "$OS" == "HP-UX" ]; then
		if [ "$RELEASE" == "B.11.31" ]; then
			TYPE_PROC=`cat $f | grep '^CPU info:' -A1 | tail -1 | sed 's/^ *//g'`
			#  | tr -s ' ' | cut -d' ' -f3-`
		elif [ "$RELEASE" == "B.11.23" ]; then
			TYPE_PROC=`cat $f | grep 'processor model:' | cut -d':' -f2 | tr -s ' ' | cut -d' ' -f3-`
		fi
	fi

	# TYPE PROC pour AIX
        if [ ! "$TYPE_PROC" ]; then
                # TYPE_PROC=`cat $f | grep -i '^Processor Type:' | tail -1 | sed 's/^Processor Type: //g'`
                TYPE_PROC=`cat $f | grep -A3 '/usr/sbin/prtconf' | tail -1 | cut -d':' -f2 | sed 's/^ //'`
        fi
	
	# cette commande supprime les espaces dans la chaine de caracteres
	TYPE_PROC=$(echo $TYPE_PROC | tr -s '  ')
}

function get_sockets_number {
	#---
	# Si serveur virtuel, pas de calcul
	#---
	if [ "$VIRTUEL" == "Oui" ] 
	then 
		NB_SOCKETS="ND VIRTUEL"
		return
	fi

	case $OS in 
		*Windows* )
	                NB_SOCKETS=`cat $f | grep -i '^System$' -A3 | grep -i 'NumberOfProcessors:' | sed 's/  NumberOfProcessors: //'`
		;;

		HP-UX )
			# NB_SOCKETS : HP-UX
			if [ "$OS" == "HP-UX" ]; then 
				# si ia64 on applique cette formule :
				v_ia64=`echo $MODEL | grep 'ia64'`
				if [ "$v_ia64" ]; then 
					NB_SOCKETS=`cat $f | grep '^CPU info:' -A1 | tail -1 | tr -s ' ' | cut -d' ' -f2`
				else
					NB_SOCKETS=`cat $f |  grep '^processor' | wc -l`
				fi
				# si release  B.11.23 alors c est cette commande
				if [ "$RELEASE" == "B.11.23" ]; then
					NB_SOCKETS=`cat $f | grep 'Number of enabled sockets =' | cut -d'=' -f2 | sed 's/^ *//g'`
					# NB_SOCKETS=`cat $f | grep "^+ /usr/contrib/bin/machinfo" -A6 | tail -1 | egrep -o [0-9]`
				fi
			fi
		;;

		AIX )
			# nombre de processeurs et coeurs pour AIX
			if [ "$OS" == "AIX" ]; then
				NB_SOCKETS=`cat $f | egrep -i '^Number Of Processors:|^Nombre de processeurs' | tail -1 | cut -d':' -f2`
			fi
		;;

		'SunOS' )
			case $RELEASE in 
				'5.9' )
					NB_SOCKETS=`cat $f | grep "^Status of processor" | wc -l`
				;;
				'5.10' )
					NB_SOCKETS=`cat $f | grep "^The physical processor has" | wc -l`
				;;
			esac
		;;
		
		Linux )
			# pour linux les infos sont dans le fichier apr�s la commande dmidecode --type processor
			# si ID est different de 00 00 00 00 00 00 alors le PROC existent bien et on le compte
			NB_SOCKETS=`cat $f | grep "ID:" | grep -v "00 00 00 00 00 00 00 00" | wc -l`
		;;

		* )
			NB_SOCKETS="---"
		;;
	esac
}

function get_core_number {
	#---
	# Si serveur virtuel, pas de calcul
	#---
	if [ "$VIRTUEL" == "Oui" ] 
	then 
		NB_COEURS="ND VIRTUEL"
		return
	fi

	case $OS in 
		*Windows* )
	                NB_COEURS=`cat $f | grep -i '^  CPU NumberOfCores:' | sed 's/  CPU NumberOfCores: //'`
			NB_COEURS=${NB_COEURS:0:2}
			# cette chaine retourne le nombre de coeurs ou "PA" pour PATCH NOT AVAILABLE
			if [ $NB_COEURS == "PA" ]; then NB_COEURS="ND PATCH ERROR"; fi
		;;

		HP-UX )
			# si release  B.11.23 alors c est cette commande
			if [ "$RELEASE" == "B.11.23" ]; then
				NB_COEURS=`cat $f | grep 'Cores per socket =' | cut -d'=' -f2 | sed 's/^ *//g'`
				# NB_COEURS=`cat $f | grep "^+ /usr/contrib/bin/machinfo" -A7 | tail -1 | awk '{print $1}'`
				# NB_COEURS_TOTAL marche pour toutes les versions Unix, 
				export NB_COEURS_TOTAL=`expr $NB_COEURS \* $NB_SOCKETS`
				# pas besoin de cette commande specifique
				# NB_COEURS_TOTAL=`cat $f | grep 'Number of enabled CPUs' | cut -d'=' -f2 | sed 's/^ *//g'`
			fi
		;;

		AIX )
			# pour AIX en general ce sont des partitions LPAR, voir les parametres supplementaires
			NB_COEURS="ND AIX"
		;;

		'SunOS' )
			NB_COEURS=`cat $f | grep "^The physical processor has" | head -1 | egrep -o '[0-9]' | head -1`
		;;
		
		Linux )
			# pour linux les infos sont dans le fichier apr�s la commande dmidecode --type processor
			NB_COEURS=`cat $f | grep "^cpu cores" | sort | uniq | cut -d':' -f2 | egrep -o '[0-9]'`
		;;

		* )
			NB_COEURS="ND OS_CASE"
		;;
	esac
}

function get_aix_params {

	# parametres pecifique AIX 
	if [ "$OS" == "AIX" ]; then
		Node_Name=`cat $f | grep /usr/bin/lparstat -A1 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Name=`cat $f | grep /usr/bin/lparstat -A2 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Number=`cat $f | grep /usr/bin/lparstat -A3 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Type=`cat $f | grep /usr/bin/lparstat -A4 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Mode=`cat $f | grep /usr/bin/lparstat -A5 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Entitled_Capacity=`cat $f | grep /usr/bin/lparstat -A6 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Active_CPUs_in_Pool=`cat $f | grep /usr/bin/lparstat -A21 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Online_Virtual_CPUs=`cat $f | grep /usr/bin/lparstat -A9 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
	fi
}

function print_data {
   # ajout d'une ligne dans le fichier OUTPUT_FILE
	echo -e "$HNAME;\
	$OS $RELEASE;\
	$MARQUE;\
	$MODEL;\
	$VIRTUEL;\
	$TYPE_PROC;\
	$NB_SOCKETS;\
	$NB_COEURS;\
	$NB_COEURS_TOTAL;\
	$Node_Name;\
	$Partition_Name;\
	$Partition_Number;\
	$Partition_Type;\
	$Partition_Mode;\
	$Entitled_Capacity;\
	$Active_CPUs_in_Pool;\
	$Online_Virtual_CPUs" >> $OUTPUT_FILE
}

function get_virtuel {

	#---
	# pour la virtualisation VMware, on regarde la marque 
	#---
	v_VMWARE=`echo $MARQUE | grep -i vmware`
	VIRTUEL=Non
	if [ "$v_VMWARE" ]; then VIRTUEL=Oui; fi
}

echo "Debut du traitement : fichier de sortie $OUTPUT_FILE"

#------
# est ce qu'il faut sp�cifier la profondeur de recherche ??!!
#------
# premiere chose � faire, dos2unix du fichier, sinon resultat tres aleatoire
# echo "Conversion des fichiers text par dos2unix ..."
# dos2unix *-lms_cpuq.txt 2>/dev/null

print_header

find -type f -iname "*-lms_cpuq.txt" | while read f
do
	echo "Traitement du fichier : $f"
	dos2unix $f 2>/dev/null
	init_variables
	get_hostname $f
	get_os $f
	get_marque $f
	get_modele $f
	get_virtuel $f
	get_processor_type $f
	get_sockets_number $f
	get_core_number $f
	get_aix_params $f
	print_data 
done
# mise en forme du fichier de sortie
# suppression des tabulations caus�es par les commandes echo 
sed -i "s/\t//g" $OUTPUT_FILE
# suppression des lignes vides
sed -i "/^;/d" $OUTPUT_FILE
# suppression des \r qui existent dans certains fichiers
sed -i "s/\\r//g" $OUTPUT_FILE


echo
echo "Fin du traitement des fichiers XXXXX-lms_cpuq"
echo "Fichier de sortie $OUTPUT_FILE"
echo 

# cat $OUTPUT_FILE