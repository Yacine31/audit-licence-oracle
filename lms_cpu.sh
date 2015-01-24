#!/bin/bash 
# 18/07/2013 - bcp de chose fonctionnent, reste a faire AIX
# 18/07/2013 - ajout de la partie AIX avec tous les paramètres des partitions AIX
# 14/11/2013 - correction du calcul des coeurs et processeurs pour les machines Windows
# 28/11/2013 - reecriture pour plus de lisibilité et initialisation des variables a chaque boucle
# 05/12/2013 - correction sur AIX : les caractère accentues posent pb : Modèle est transformé en Mod\350le
#		la commande sed -n 'l' NOMFICHIER => permet d'afficher ces caractère et un sed permet de les remplacer
# 06/05/2014 - reorganisation du script, les noms des variables, les entetes, ....
# 19/05/2014 - adaptation du script pour qu'il soit appelé depuis le script parincipal extract.sh
# 22/05/2014 - extraction de Node Name, Partition Name et Partition Number pour les serveurs AIX
# 22/07/2014 - ajout du némero de série de la machine AIX : permet de savoir si les LPAR sont sur le même chassis ou pas
#            - ajout du maximum CPU in system pour les machines AIX : Active Physical CPUs in system
# 03/08/2014 - ajout de la colonne physical_server : pour AIX=n° de serie, pour les autres cas = nom du serveur sinon VMWARE si VM
# 16/01/2015 - get_processor_type corrigée pour les machine SunOS
# 24/01/2015 - windows : calcul des sockets et coeurs corrigé 


:<<README
Postulat de depart :
- collecte des données : 
  + tous les fichiers sont dans le même répertoire et portent le nom XXXXX-lms_cpuq.txt
- le script suivant va parcourir tous les fichier générer un fichier csv
README

# DATE_JOUR=`date +%Y.%m.%d-%H.%M.%S`
# OUTPUT_FILE="cpuq_"${DATE_JOUR}".csv"

[ "$1" = "" ] && echo "Usage : $0 OUTPUT_CSV_FILE" && exit 1

OUTPUT_FILE=$1

function print_header {
	# insertion des entetes dans le fichier de sortie :
	echo -e "Physical Server;\
	Host Name;\
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
	Online Virtual CPUs;\
	Machine Serial Number;\
	Active Physical CPUs" >> $OUTPUT_FILE
}

function init_variables {
	PHYSICAL_SERVER=""
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
	Machine_Serial_Number=""
	Active_Physical_CPUs=""
}


function get_hostname {
	HNAME=`cat "$@" | grep '^Machine Name' | sort | uniq | cut -d'=' -f2 | sed 's/\\r//'`
	# HNAME=`sed -n 'l' $1 | grep '^Machine Name' | sort | uniq | cut -d'=' -f2 | sed 's/\r//'`
        # sinon on est en présence de Windows
        if [ ! "$HNAME" ]; then
                HNAME=`cat "$@" | grep '^Computer Name: ' | sort | uniq | sed 's/Computer Name: //' | sed 's/\\r//'`
        fi
}

function get_os {
	# cette ligne marche pour les Unix et Linux, SunOS, AIX
	OS=`cat "$@" | grep '^Operating System Name' | sort | uniq | cut -d'=' -f2 `

	# pour les Unix on récupère aussi la release
	RELEASE=`cat "$@" | grep "^Operating System Release=" | sort | uniq | cut -d'=' -f2`
	
	# si la chaine de caractère est vide, alors on cherche un Windows francais 2008
	if [ ! "$OS" ]; then
		OS=`cat "$@" | grep "d'exploitation" | cut -d' ' -f3-`
	fi

	# sinon c 'est un windows anglais 
	if [ ! "$OS" ]; then
		OS=`cat "$@" | grep "^Operating System" -A1 | grep "Caption: " | tr -s ' ' | sed 's/ Caption: //' | sed 's/\\r//'`
	fi
	
	# quelque soit l'OS on prend juste le premier mot (Microsoft souvent suivi de plusieurs informations
	# OS=$(echo $OS | cut -d' ' -f1)

}

function get_marque {

    case $OS in
	*Microsoft* )
	    # windows 2003, 2008
	    if [ ! "$MARQUE" ]; then
		MARQUE=`cat "$@" | grep -i '^System' -A2 | grep -i 'Manufacturer:' | sed 's/  Manufacturer: //' | head -1`
	    fi
	;;

	Linux )
	    # cette ligne marche pour Linux
	    MARQUE=`cat "$@" | grep -v 'grep' | grep -i 'System Information' -A1 | grep -i 'Manufacturer' | cut -d':' -f2 |  sed 's/^ *//g' | head -1`
	;;
	
	SunOS )
	    MARQUE=`cat "$@" | grep -i '/usr/sbin/prtconf' -A1 | tail -1 | cut -d':' -f2 |  sed 's/^ *//g' | head -1`
	;;

	* )
	    MARQUE="OS NOT DEF."
	;;
    esac
}

function get_modele {

	case $OS in
	    SunOS )
		# modele pour SunOS
		MODEL=`cat "$@" | grep -i '/usr/sbin/prtdiag' -A1 | tail -1 | cut -d':' -f2 |  sed 's/^ *//g' | head -1`
		# cette information n'as pas d'intérêt dans le cas des serveurs SUN
		# MODEL="NA"
	    ;;
		
	    Linux )
		# cette linux marche pour linux
		MODEL=`cat "$@" | grep -v 'grep' | grep -i 'System Information' -A2 | grep -i 'Product Name:' | cut -d':' -f2 |  sed 's/^ *//g' | head -1`
		;;

	    *Microsoft* )
		# modele pour windows 2003
		MODEL=`cat "$@" | grep -i '^System' -A3 | grep -i 'Model:' | sed 's/  Model: //' | head -1`
		;;

	    AIX )
		# MODEL pour Aix
		MODEL=`cat "$@" | grep -A1 '/usr/sbin/prtconf' | tail -1 | cut -d':' -f2 | sed 's/^ //'| head -1`
		# la ligne suivante ne marche pas en cas de systeme francais à cause des caracteres accentues
		# MODEL=`cat "$@" | grep -i '^System Model:' | tail -1 | sed 's/^System Model: //g'`
		;;

	    HP-UX )
		# model pour HP-UX
		MODEL=`cat "$@" | grep -v 'grep' | grep -i 'MACHINE_MODEL' -A1 | grep -v 'MACHINE_MODEL' | grep -v '\-\-' | sort | uniq`
		;;
		
		* )
			TYPE_PROC="----"
		;;
	esac

	MODEL=$(echo $MODEL | sed 's/System Model: //g')
}

function get_processor_type {

	case $OS in
		SunOS )
			case $RELEASE in
				'5.10' )
					TYPE_PROC=`cat "$@" | egrep -A1 "^The physical processor has|^Le processeur physique a" | tail -1 | awk '{print $1}'`
				;;
				'5.9' )
					TYPE_PROC=`cat "$@" | grep -A2 "^CPU" | tail -1 | awk '{print $5}'`
				;;
				'5.8' )
					TYPE_PROC=`cat "$@" | grep "processor has" | tail -1 | awk '{print $2}'`
				;;
			esac
		;;

		
		Linux )
		    # cette ligne marche pour linux
		    TYPE_PROC=`cat "$@" | grep -i '^model name' | sort | uniq | cut -d':' -f2 |  sed 's/^ *//g'`
		;;

		*Microsoft* )
		    # windows 2003 et 2008
		    # TYPE_PROC=`cat "$@" | grep -i '^Processors' -A1 | grep -i 'CPU Name:' | sed 's/  CPU Name: //'`
		    TYPE_PROC=`cat "$@" | grep ProcessorNameString | sort | head -1 | cut -d'=' -f2 | tr -d '"' | tr -s '  ' ' '`
		;;

		AIX )
                    # TYPE_PROC=`cat "$@" | grep -i '^Processor Type:' | tail -1 | sed 's/^Processor Type: //g'`
	            TYPE_PROC=`cat "$@" | grep -A3 '/usr/sbin/prtconf' | tail -1 | cut -d':' -f2 | sed 's/^ //'`
		;;

		HP-UX )
		    # TYPE PROC pour HP-UX B.11.31
		    if [ "$RELEASE" == "B.11.31" ]; then
			TYPE_PROC=`cat "$@" | grep '^CPU info:' -A1 | tail -1 | sed 's/^ *//g'`
			#  | tr -s ' ' | cut -d' ' -f3-`
		    elif [ "$RELEASE" == "B.11.23" ]; then
			TYPE_PROC=`cat "$@" | grep 'processor model:' | cut -d':' -f2 | tr -s ' ' | cut -d' ' -f3-`
		    fi
		;;
		
		* )
			TYPE_PROC="----"
		;;
	esac

	
	
	# cette commande supprime les espaces dans la chaine de caracteres
	TYPE_PROC=$(echo $TYPE_PROC | tr -s '  ')
}

function get_sockets_number {
	#---
	# Si serveur virtuel, pas de calcul
	#---
	if [ "$VIRTUEL" == "TRUE" ] 
	then 
		NB_SOCKETS="ND VIRTUEL"
		return
	fi

	case $OS in 
		*Microsoft* )
	        # NB_SOCKETS=`cat "$@" | grep -i 'NumberOfProcessors:' | tail -1 | cut -d: -f2 | tr -d ' '`
	        # NB_SOCKETS=`cat "$@" | grep -v objTextFile.WriteLine | grep -i 'NumberOfProcessors:' | egrep -o '([0-9])*'`
	        NB_SOCKETS=`cat "$@" | grep -v objTextFile.WriteLine | grep -i 'NumberOfProcessors:' | egrep -o '([0-9])*'`
		;;

		HP-UX )
			# NB_SOCKETS : HP-UX
			if [ "$OS" == "HP-UX" ]; then 
				# si ia64 on applique cette formule :
				v_ia64=`echo $MODEL | grep 'ia64'`
				if [ "$v_ia64" ]; then 
					NB_SOCKETS=`cat "$@" | grep '^CPU info:' -A1 | tail -1 | tr -s ' '`
					NB_SOCKETS=${NB_SOCKETS:1:1}
				else
					NB_SOCKETS=`cat "$@" |  grep '^processor' | wc -l`
				fi
				# si release  B.11.23 alors c est cette commande
				if [ "$RELEASE" == "B.11.23" ]; then
					NB_SOCKETS=`cat "$@" | grep 'Number of enabled sockets =' | cut -d'=' -f2 | sed 's/^ *//g'`
					# NB_SOCKETS=`cat "$@" | grep "^+ /usr/contrib/bin/machinfo" -A6 | tail -1 | egrep -o [0-9]`
				fi
			fi
		;;

		AIX )
			# nombre de processeurs et coeurs pour AIX
			if [ "$OS" == "AIX" ]; then
				NB_SOCKETS=`cat "$@" | egrep -i '^Number Of Processors:|^Nombre de processeurs' | tail -1 | cut -d':' -f2 | tr -d ' '`
			fi
		;;

		SunOS )
			case $RELEASE in 
				'5.9' )
					NB_SOCKETS=`cat "$@" | grep "^Status of processor" | wc -l`
				;;
				'5.10' )
					NB_SOCKETS=`cat "$@" | egrep "^The physical processor has|^Le processeur physique a" | wc -l`
				;;
			esac
		;;
		
		Linux )
			# pour linux les infos sont dans le fichier après la commande dmidecode --type processor
			# si ID est different de 00 00 00 00 00 00 alors le PROC existent bien et on le compte
			# sur certaines machine IBM, il faut supprimer les lignes UUID:
			NB_SOCKETS=`cat "$@" | grep "ID:" | grep -v UUID | grep -v "00 00 00 00 00 00 00 00" | wc -l`
		;;

		* )
			NB_SOCKETS="OS NOT DEF."
		;;
	esac
}

function get_core_number {
	#---
	# Si serveur virtuel, pas de calcul
	#---
	if [ "$VIRTUEL" == "TRUE" ] 
	then 
		NB_COEURS="ND VIRTUEL"
		return
	fi

	case $OS in 
		*Microsoft* )
		    # cette chaine retourne le nombre de coeurs ou "PATCH" pour PATCH NOT AVAILABLE
		    NB_COEURS=$(cat "$@" | grep -v objTextFile.WriteLine | grep -i 'CPU NumberOfCores:' | awk '{ print $3 }' | head -1)
		    
		    if [ $NB_COEURS == "PATCH" ] 
		    then
			# si $NB_COEURS="PATH", alors la valeur de NumberOfProcessors = nombre de coeurs ou nb_coeurs * 2 si processeur multithreadé
			NB_COEURS="ND PATCH ERROR" 
			NB_SOCKETS="ND PATCH ERROR"
			NB_COEURS_TOTAL=$(cat "$@" | grep -v objTextFile.WriteLine | grep -i 'NumberOfProcessors:' | grep -o '[0-9]*')
		    else
			# Si NB_COEURS retourne un entier au lieu de PATCH EROOR, alors :
			NB_SOCKETS=$(cat "$@" | grep -v objTextFile.WriteLine | grep -i 'NumberOfProcessors:' | grep -o '[0-9]*')
			NB_COEURS=$(cat "$@" | grep -v objTextFile.WriteLine | grep -i 'CPU NumberOfCores:' | head -1 | grep -o '[0-9]*')
			if [[ "$NB_COEURS" && "$NB_SOCKETS" ]]
			    then NB_COEURS_TOTAL=$(expr $NB_SOCKETS \* $NB_COEURS)
			fi
		    fi
		    # NB_COEURS_TOTAL=`cat "$@" | grep '\\CentralProcessor\\' | wc -l`
		;;

		HP-UX )
			# si release  B.11.23 alors c est cette commande
			if [ "$RELEASE" == "B.11.23" ]; then
				NB_COEURS=`cat "$@" | grep 'Cores per socket =' | cut -d'=' -f2 | sed 's/^ *//g'`
				# NB_COEURS=`cat "$@" | grep "^+ /usr/contrib/bin/machinfo" -A7 | tail -1 | awk '{print $1}'`
				# NB_COEURS_TOTAL marche pour toutes les versions Unix, 
				export NB_COEURS_TOTAL=`expr $NB_COEURS \* $NB_SOCKETS`
				# pas besoin de cette commande specifique
				# NB_COEURS_TOTAL=`cat "$@" | grep 'Number of enabled CPUs' | cut -d'=' -f2 | sed 's/^ *//g'`
			fi
		;;

		AIX )
			# pour AIX en general ce sont des partitions LPAR, voir les parametres supplementaires
			NB_COEURS="ND AIX"
		;;

		SunOS )
			NB_COEURS="ND SunOS"
			NB_COEURS_TOTAL=0
			# cat "$@" | egrep "^The physical processor has|^Le processeur physique a" | egrep -o ' [0-9] ' > /tmp/SunOS.tmp
			cat "$@" | egrep -o "physical processor has [0-9]+ |processeur physique a [0-9]+ " | egrep -o ' [0-9]+ ' > /tmp/SunOS.tmp
			while read n
			do
			    (( NB_COEURS_TOTAL = NB_COEURS_TOTAL + n ))
			    # NB_COEURS_TOTAL=$(expr ${NB_COEURS_TOTAL} + $n)
			done < /tmp/SunOS.tmp
			# NB_COEURS=`cat "$@" | grep "^The physical processor has" | head -1 | egrep -o '[0-9]' | head -1`
		;;
		
		Linux )
			# pour linux les infos sont dans le fichier après la commande dmidecode --type processor
			NB_COEURS=`cat "$@" | grep "^cpu cores" | sort | uniq | cut -d':' -f2 | egrep -o '[0-9]'`
			if [[ "$NB_COEURS" && "$NB_SOCKETS" ]]
			    then NB_COEURS_TOTAL=$(expr $NB_SOCKETS \* $NB_COEURS)
			fi
		;;

		* )
			NB_COEURS="OS NOT DEF."
			NB_COEURS_TOTAL="OS NOT DEF."
		;;
	esac
}

function get_aix_params {

	# parametres pecifique AIX 
	if [ "$OS" == "AIX" ]; then
		Node_Name=`cat "$@" | grep /usr/bin/lparstat -A1 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Name=`cat "$@" | grep /usr/bin/lparstat -A2 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Number=`cat "$@" | grep /usr/bin/lparstat -A3 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Type=`cat "$@" | grep /usr/bin/lparstat -A4 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Partition_Mode=`cat "$@" | grep /usr/bin/lparstat -A5 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		# Entitled_Capacity=`cat "$@" | grep /usr/bin/lparstat -A6 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'| sed 's/\./,/g'`
		Entitled_Capacity=`cat "$@" | grep /usr/bin/lparstat -A6 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Active_CPUs_in_Pool=`cat "$@" | grep /usr/bin/lparstat -A21 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Online_Virtual_CPUs=`cat "$@" | grep /usr/bin/lparstat -A9 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		Machine_Serial_Number=`cat "$@" | grep /usr/sbin/prtconf -A2 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`
		# pour certains serveur Lorsque Serial Number retourne "Not Available", il manque un retour chariot
		# la ligne suivante est collée au résulat ce qui donne : Not AvailableProcessor Type
		# On remplace donc "Not Available" et "Not AvailableProcessor Type" par "NA"
		Serial=${Machine_Serial_Number:0:3}
		# if [ "$Serial" == "Not" ]; then Machine_Serial_Number="NA"; fi
		# voir si la ligne "LPAR Virtual Serial Adapter" peut remplacer le Serial Number = Not Available
		if [ "$Serial" == "Not" ]; then
			Machine_Serial_Number=`cat "$@" | grep "LPAR Virtual Serial Adapter" | awk '{print $3}' | cut -d'-' -f1 | cut -d'.' -f3`
		fi

		Active_Physical_CPUs=`cat "$@" | grep /usr/bin/lparstat -A20 | tail -1 | cut -d':' -f2 | sed 's/^ *//g'`

		if [ $(echo $Partition_Type | grep -i "Dedicated|Donat") ]; then VIRTUEL="FALSE"; else VIRTUEL="TRUE"; fi
	fi
}

function print_data {
   # ajout d'une ligne dans le fichier OUTPUT_FILE
	## $OS  => cette ligne est remplacé par $OS seulement au lieu de $OS $RELEASE;\
	echo -e "$PHYSICAL_SERVER;\
	$HNAME;\
	$OS;\
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
	$Online_Virtual_CPUs;\
	$Machine_Serial_Number;\
	$Active_Physical_CPUs" >> $OUTPUT_FILE
}

function get_virtuel {
	# initialisation : par defaut le serveur n'est pas virtuel et le serveur physique = host_name
	VIRTUEL="FALSE"
	PHYSICAL_SERVER=$HNAME

	# ensuite on regarde le cas de certains OS
	case $OS in
		AIX* )
			#---
			# pour les serveurs AIX on regarde le type de la partition 
			#---
			pType=$(echo $Partition_Type | grep -i "Dedicated")
			# if [[ "$pType" == "" ]]; then
				VIRTUEL="TRUE"
				PHYSICAL_SERVER=$Machine_Serial_Number
			# fi
			;;
		* )
			#---
			# pour la virtualisation VMware, on regarde la marque 
			#---
			v_VMWARE=$(echo $MARQUE | grep -i vmware)
			if [[ "$v_VMWARE" != "" ]]; then
				VIRTUEL="TRUE"
				PHYSICAL_SERVER="VMWARE"
			fi
			;;
	esac
}

echo "Debut du traitement : fichier de sortie $OUTPUT_FILE"

#------
# est ce qu'il faut spécifier la profondeur de recherche ??!!
#------
# premiere chose à faire, dos2unix du fichier, sinon resultat tres aleatoire
# echo "Conversion des fichiers text par dos2unix ..."
# dos2unix *-lms_cpuq.txt 2>/dev/null

# initialisation de variables 


print_header

find -type f -iname "*-lms_cpuq.txt" | while read f
do
	echo "Traitement du fichier : $f"
	dos2unix $f 2>/dev/null
	init_variables
	get_hostname "$f"
	get_os "$f"
	get_marque "$f"
	get_virtuel "$f"
	get_modele "$f"
	get_processor_type "$f"
	get_sockets_number "$f"
	get_core_number "$f"
	get_aix_params "$f"
	# le paramètre virtuel est calculé en dernier car il se base sur plusieurs paramètres
	# qui sont calculés avant : OS, PARAMS AIX, MARQUE
	get_virtuel "$f"
	print_data 
done
# mise en forme du fichier de sortie
# suppression des tabulations causées par les commandes echo 
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
