<?php
function ListIn($dir, $prefix = '') {
  $dir = rtrim($dir, '\\/');
  $result = array();

    foreach (array_diff(scandir($dir), array('..', '.')) as $f) {
      if (is_dir("$dir/$f")) {
          $result = array_merge($result, ListIn("$dir/$f", "$prefix$f/"));
        } else {
          $result[] = $prefix.$f;
        }
     }

  return $result;
}

// variables
$wls_home="";
$host_name="";

$files = ListIn('.');
foreach($files as $file){
// parcourir tous les fichiers a la recherche de registry.xml
// ensuite extraire les informations suivante : Hostname, Home ou est installé Weblo, Nom du produit, Version
// si une installation de Java est présente, alors le nom est affiché
    if( strstr($file, '/registry.xml' )){
	// echo "Nom de fichier = " . $file . "\n";
	$xml = simplexml_load_file($file);

	foreach($xml->host as $host){
	    print "========\n";
	    print "Hostname=" . $host['name'] . "\n";
	    print "Home=" . $host['home'] . "\n";
	    $wls_home = $host['home'];
	    $host_name = $host['name'];
	    // print ",Java=" . $host->product->release['JavaHome'];
	    foreach($host->product->release->component as $component){
		if ($component['name'] == 'WebLogic Server'){
		    print "Product name=" . $component['name'] . "\n";
		    print "Version=" . $component['version'] . "\n";
		}
	    }
	    print "========\n";
	}

	foreach($xml->host->{'java-installation'} as $java){
	    if ($java)	print "Java Name=" . $java['Name'];
	}
	print "\n";
    
        // on parcour le home pour rechercher le fichier ou les fichiers config.xml des différents domaines	
	// on supprime le premier / du nom du home et on commence la recherche
	// print "WLS_HOME = " . substr($wls_home,'1') . "\n";
	$working_dir = dirname(realpath($file));
	// print "Working Directory = " . $working_dir . "\n";
        $config_files = ListIn(dirname(realpath($file)));
	foreach($config_files as $config_file){
	    if(strstr($config_file, 'user_projects') && strstr($config_file, 'config/config.xml' )){
		// print "Fichier config xml = " . $working_dir . "/" . $config_file . "\n" ;
		$xml = simplexml_load_file($working_dir . "/" . $config_file);
		// domain
		print "--------\ndomain name = ".$xml->name . "\n--------\n";

		foreach($xml->server as $server){
		    print "server name = ".$server->name . "\t\t" . "server machine = ".$server->machine . "\t\t" . "cluster = " . $server->cluster . "\n";
		}

		foreach($xml->cluster as $cluster){
		    print "cluster name = ".$cluster->name . "\t" . "cluster adress = ".$cluster->{'cluster-address'} . "\n";
		}

		// on cherche les instances migrables :
		foreach($xml->{'migratable-target'} as $migratable){
		//    print $migratable->name . "\t" . $migratable->cluster . "\n";
		}
		// on recherhce si WLDF est actif, valeur autre que NONE implique EE
		if ($xml->server->{'server-diagnostic-config'}){
			print "--------\n";
			print "Si WLDF est autre que NONE, alors EE \n";
			print "--------\n";
			print "wldf-diagnostic-volume = " . $xml->server->{'server-diagnostic-config'}->{'wldf-diagnostic-volume'} . "\n";
		}
	    }
	}

    }
}
?>
