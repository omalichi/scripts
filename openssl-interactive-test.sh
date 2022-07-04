#!/bin/bash

VHOSTS_DIR=/opt/v

OPENSSL_BIN=`which openssl 2>/dev/null`
CURL_BIN=`which curl`

PATH_TO_ADD_A_SITE_TO_HOSTS_SCRIPT=/root/scripts/add-a-site-to-hosts.sh

if [ "$OPENSSL_BIN" == "" ]; then
	echo "ERROR! 'openssl' was not found on the server!"
	echo "Aborting ..."
	exit 1
fi

if [ "$CURL_BIN" == "" ]; then
	echo "ERROR! 'curl' was not found on the server!"
	echo "Aborting ..."
	exit 1
fi

if ! [ -d "$VHOSTS_DIR" ]; then
	echo "ERROR! '$VHOSTS_DIR' is not a valid dir."
	echo "Aborting ..."
	exit 1
fi

if ! [ -s "$PATH_TO_ADD_A_SITE_TO_HOSTS_SCRIPT" ]; then
	NO_ADD_TO_HOSTS_SCRIPT=yes
fi


COUNTER=1

ls $VHOSTS_DIR/ssl*.conf 1>&2 2>/dev/null

if [ "$?" == 0 ]; then
	for i in $(cat $VHOSTS_DIR/ssl*.conf | grep -v \# | grep "ServerName\|ServerAlias" | awk '{print $2}'); do
		URLS_ARR[$COUNTER]=$i
		
		COUNTER=$(expr $COUNTER + 1)
	done

	if ! [ "$1" == "" ]; then
		if [ "$1" -eq "$1" ] 2>/dev/null
		then
			echo "Running the command '$OPENSSL_BIN s_client -servername ${URLS_ARR[$1]} -connect ${URLS_ARR[$1]}:443' ..."
	
			echo "$OPENSSL_BIN s_client -servername ${URLS_ARR[$1]} -connect ${URLS_ARR[$1]}:443" | sh
		else
			echo "ERROR! Invalid input."
			echo "Aborting ..."
			exit 1	
		fi
	else

		COUNTER=1

		echo -e "\nPlease pick a site to test with openssl:\n"

		for i in "${URLS_ARR[@]}"; do
			echo $COUNTER\) ${URLS_ARR[$COUNTER]}

			COUNTER=$(expr $COUNTER + 1)
		done

		echo q\) quit

		echo -e "\nYour Choice: "

		read NUM

		if [ "$NUM" == "q" ]; then
			echo "Exiting on user's request. Goodbye."
		else
			if [ "$NUM" -eq "$NUM" ] 2>/dev/null
			then
				echo "Running the command '$OPENSSL_BIN s_client -servername ${URLS_ARR[$NUM]} -connect ${URLS_ARR[$NUM]}:443' ..."
			
				$CURL_BIN -I ${URLS_ARR[$NUM]} &>/dev/null
			
				if ! [ "$?" == "0" ]; then
					if ! [ "$NO_ADD_TO_HOSTS_SCRIPT" == "yes" ]; then
						SITE_TO_ADD=${URLS_ARR[$NUM]}							
						#echo $SITE_TO_ADD
					
						TOKENS_ARR=(${SITE_TO_ADD//\/\// })

						TOKENS_ARR=(`echo ${TOKENS_ARR[@]} | tr " " "\n"`)

						#echo ${TOKENS_ARR[0]}
						#echo ${TOKENS_ARR[1]}

						$PATH_TO_ADD_A_SITE_TO_HOSTS_SCRIPT ${TOKENS_ARR[1]}
					fi
				fi

				$OPENSSL_BIN s_client -servername ${URLS_ARR[$NUM]} -connect ${URLS_ARR[$NUM]}:443
			else
				echo "ERROR! Invalid Input."
			fi
		fi
	fi
else
	echo "No SSL sites were found on this server."
fi

