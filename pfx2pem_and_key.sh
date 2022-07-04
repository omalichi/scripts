#!/bin/bash

if [ "$1" == "" -o "$2" == "" ]; then
	echo Extracts pem and key files from a pfx certificate \(Windows to Linux certificate converter\)
	echo ERROR: Wrong Input.
	echo Usage: $0 \<pfx_file_name_to_work_on\> \<name_for_new_certs\> [optional - \<path_to_save_certs_in\>]
else
	if ! [ -a "$1" ]; then
		echo ERROR: '$1' is not a valid file. Aborting...
	else
		DIR=`dirname "$1"`
		
		if ! [ "$DIR" == "." ]; then
			cd $DIR
			$DIR=""
		fi

		if ! [ "$3" == "" ]; then
			if ! [ -d "$3" ]; then
				echo WARNING: '$3' is not a valid path. Ignoring . Will work in `pwd` instead.
			else
				DIR=$3
			fi
		fi

		FILE=`basename "$1"`	
		
		echo Generating Linux certs...	
		openssl pkcs12 -in $FILE -out $2.key -nocerts -nodes
		openssl rsa -in $2.key -out $2.key.no_pwd
		rm $2.key
		mv $2.key.no_pwd $2.key
		openssl pkcs12 -in $FILE -out $2.pem -nokeys -clcerts
		echo Done.
				
		if ! [ "$DIR" == "" ]; then
			mv $2.key $DIR
			mv $2.pem $DIR
			cd $DIR
		fi
		
		pwd
		ls
	fi
fi

