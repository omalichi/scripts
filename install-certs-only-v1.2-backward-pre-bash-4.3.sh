#!/bin/bash

# alpine ca-bundle file: /etc/ssl/cert.pem
# alpine pip pkg name:  apk add py2-pip
# alpine python ca bundle: /usr/lib/python2.7/site-packages/pip/_vendor/certifi/cacert.pem
# alpine npm ca bundle (directory): /usr/share/ca-certificates/mozilla
# note that npm installation process also creates the ca-bundle: /etc/ssl/certs/ca-certificates.crt
# note 2: there is a binary file called "update-ca-certificates" that does not seem to be doing what it supposed to do 

# centos8 ca-bundle file: /etc/ssl/certs/ca-bundle.crt
# centos8 pip pkg names:  yum install python2-pip python3-pip
# centos8 python2 ca bundle: /usr/lib/python2.7/site-packages/pip/_vendor/certifi/cacert.pem
# centos8 python3 ca bundle: /usr/lib/python3.6/site-packages/pip/_vendor/certifi/cacert.pem
# not verified: centos8 npm ca bundle file: /etc/ssl/certs/ca-bundle.crt
# centos8 npm pkg names:  yum install npm

# debian ca-bundle dir: /etc/ssl/certs
# debian pip pkg name:  apt install python-pip
# debian python ca bundle: /etc/ssl/certs/ca-certificates.crt
# not verified: debian npm ca bundle (directory): /usr/share/ca-certificates/mozilla
# debian npm pkg name:  apt install npm


##################################################################
# Pre-flight checks
##################################################################
# Since ash shell or sh shell - do not support arrays, before using them we need to switch to bash
# if no bash is found and an Alpine Linux was detected, bash will be added dynamically. 
# if no bash is found this script will call itself again using bash.

##################################################################
# SETTINGS
##################################################################

CERTS_BUNDLE_STORES_TO_UPDATE="/etc/ssl/cert.pem /etc/ssl/certs/ca-bundle.crt /usr/lib/python2.7/site-packages/pip/_vendor/certifi/cacert.pem /usr/lib/python3.6/site-packages/pip/_vendor/certifi/cacert.pem /usr/lib/python3.9/site-packages/pip/_vendor/certifi/cacert.pem /usr/lib/python3/dist-packages/certifi/cacert.pem /etc/ssl/cert.pem /usr/local/lib/python2.7/dist-packages/certifi/cacert.pem /etc/ssl/certs/ca-certificates.crt /cygdrive/c/Program@@@@@Files/Python39/Lib/site-packages/pip/_vendor/certifi/cacert.pem /usr/ssl/certs/ca-bundle.crt /usr/lib/python3.6/site-packages/pip/_vendor/certifi/cacert.pem /usr/local/lib/python3.6/site-packages/pip/_vendor/certifi/cacert.pem"

CERTS_FOLDERS_TO_UPDATE="/usr/local/share/ca-certificates"


RAW_CERTS_ARR=
"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"


DEFAULT_BACKUP_FILE_SUFFIX='backed-up-by-'$(basename $0)'-script'
DEFAULT_ADDED_CONTENT_BY_SCRIPT_LINE='# added-content-by-'$(basename $0)'-script'
DEFAULT_CREATED_CONTENT_BY_SCRIPT_LINE='# created-content-by-'$(basename $0)'-script'
DEFAULT_ADDED_BY_PREFIX='added-by-'$(basename $0)'-script'

##################################################################
# FUNCTIONS
##################################################################

backupFile()
{
	# function params:
    	# $1 = file to backup
	# $2 = backup file name suffix
	
	if ! [ -z "$1" ]; then
		local fileToBackup=$1
	fi
	
	if ! [ -z "$2" ]; then
		local backupFileSuffix=$2
	fi
	
	if ! [ -z "$fileToBackup" ]; then
		if [ -z "$backupFileSuffix" ]; then
			backupFileSuffix=$DEFAULT_BACKUP_FILE_SUFFIX
		fi
		
		cp -v $fileToBackup $fileToBackup.$DEFAULT_BACKUP_FILE_SUFFIX
	fi
}

addPrefixAndSuffixForCerts()
{
	# function params:
    	# $1 = array of certs to work on
	
	CERT_PREFIX='\n-----BEGIN@@@@@CERTIFICATE-----\n'
	CERT_SUFFIX='\n-----END@@@@@CERTIFICATE-----\n'
	
	local rawCertsArr="$1"
	
	for i in $rawCertsArr
	do
		ready_certs="$CERT_PREFIX$i$CERT_SUFFIX $ready_certs "
	done
}

addCerts()
{
	# function params:
    	# $1 = array of certs to add
	# $2 = array of list of bundles to work on
	# $3 = array of list of certs folders to work on
	
	local certsArr="$1"
	local bundlesArr="$2"
	local foldersArr="$3"
	
	CERT_SERIAL_NUMBER=1
  
	for i in $bundlesArr
	do
		CURRENT_BUNDLE=$(echo $i | sed 's/@@@@@/\ /g')

		if [ -s "$CURRENT_BUNDLE" ]; then
			if ! [ -s "$CURRENT_BUNDLE.$DEFAULT_BACKUP_FILE_SUFFIX" ]; then
				echo "Backing up bundle file '$CURRENT_BUNDLE' ..."
				backupFile $CURRENT_BUNDLE
				
				echo "Size before update:"
				ls -lh $CURRENT_BUNDLE
				
				echo "Adding new certificates ..."

				for j in $certsArr
				do
					echo -e $j >> $CURRENT_BUNDLE
				done

				sed -i 's/@@@@@/\ /g' $CURRENT_BUNDLE
				
				echo "Size after update:"
                                ls -lh $CURRENT_BUNDLE
			else
				echo "File '$CURRENT_BUNDLE' was updated already."
			fi
		else
			echo "File '$CURRENT_BUNDLE' was not found."
		fi
	done
	
	
	#if [ "${#foldersArr[@]}" -gt 0 ]; then
		for i in $foldersArr
		do
			if [ -d "$i" ]; then
				ls $i | grep $DEFAULT_ADDED_BY_PREFIX &>/dev/null
			
				if ! [ "$?" -eq 0 ]; then
					cd $i
					
					for j in "$certsArr"
					do
						echo -e $j > ${DEFAULT_ADDED_BY_PREFIX}_${CERT_SERIAL_NUMBER}.crt
						sed -i 's/@@@@@/\ /g' $j						

						let "CERT_SERIAL_NUMBER=CERT_SERIAL_NUMBER+1"
					done
					
					let "CERT_SERIAL_NUMBER=0"
				else
					echo "Folder '$i' was updated already."
				fi
			fi
		done
		
		if [ -s "/usr/sbin/update-ca-certificates" ]; then
			/usr/sbin/update-ca-certificates --fresh
		fi
	#fi
	
	#echo ${certsArr[@]}
	#echo ${bundlesArr[@]}
	#echo ${foldersArr[@]}
}

showAllSettings()
{
	# function params:
	# $1 = array of list of bundles
	# $2 = array of dirs with certs
	
	local bundlesArr=$1
	local certsDirsArr=$2	
		
	if [ -z "$4" ]; then
		local backupFileSuffix=$DEFAULT_BACKUP_FILE_SUFFIX
	else
		local backupFileSuffix=$4
	fi	
  
	echo "========================================================"
	echo "Cert bundles and files:"
	echo "========================================================"
	echo ""
	echo ""
	
	for i in $bundlesArr
	do
		CURRENT_BUNDLE=$(echo $i | sed 's/@@@@@/\ /g')

		echo "Currently checking bundle file '$CURRENT_BUNDLE' ..."

		if [ -s "$CURRENT_BUNDLE" ]; then
			if [ -s "$CURRENT_BUNDLE.$backupFileSuffix" ]; then
				echo "========================================================"
				echo "$CURRENT_BUNDLE:"
				echo "========================================================"
				ls -l $CURRENT_BUNDLE
				ls -l $CURRENT_BUNDLE.$backupFileSuffix
				echo ""
				echo ""				
			fi
		fi
	done

	for i in $certsDirsArr
	do
		CURRENT_DIR=$(echo $i | sed 's/@@@@@/\ /g')

		echo "Currently checking certs dir '$CURRENT_DIR' ..."

		if [ -d "$CURRENT_DIR" ]; then
			ls $CURRENT_DIR | grep $DEFAULT_ADDED_BY_PREFIX &>/dev/null
			
			if [ "$?" -eq 0 ]; then
				echo "========================================================"
				echo "$CURRENT_DIR:"
				echo "========================================================"
				ls $CURRENT_DIR | grep $DEFAULT_ADDED_BY_PREFIX
				echo ""
				echo ""
			fi
		fi
	done
}

##################################################################
# MAIN PROGRAM
##################################################################

#echo ${RAW_CERTS_ARR[*]}

declare -a ready_certs

addPrefixAndSuffixForCerts "${RAW_CERTS_ARR[@]}"

#echo ${ready_certs[*]}

addCerts "$ready_certs" "$CERTS_BUNDLE_STORES_TO_UPDATE" "$CERTS_FOLDERS_TO_UPDATE"

showAllSettings "$CERTS_BUNDLE_STORES_TO_UPDATE" "$CERTS_FOLDERS_TO_UPDATE"



