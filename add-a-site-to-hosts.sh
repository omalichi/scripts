#!/bin/bash

if [ "$1" == "" ]; then
	echo "ERROR! Wrong input."
	echo "Usage: $0 <site_dir_or_url_without_protocol>"
	exit 1
else
	#IP_ADDRESS=`ifconfig | grep inet | awk -F: '{print $2}' | awk -F" " '{print $1}' | grep "16[0-9]"`

	SERVER_IPS=(`ip addr | grep inet | grep -v host | awk '{print \$2}' | awk -F/ '{print \$1}' | grep -v ":"`)

	IP_ADDRESS=${SERVER_IPS[0]}

	if [ -d "$1" ]; then	
		HOST_TO_ADD=`basename $1`
	else
		HOST_TO_ADD=$1
	fi

	cat /etc/hosts | grep $HOST_TO_ADD > /dev/null

	if [ "$?" == 0 ]; then
		#echo "WARNING: This host already exists."
		#echo "Ignoring request ..."

		echo $HOST_TO_ADD

		exit 0
	else
		if ! [ "$IP_ADDRESS $HOST_TO_ADD" == "" -a "$HOST_TO_ADD" == "" ]; then
			# we only add the first item of the array
			echo $IP_ADDRESS $HOST_TO_ADD >> /etc/hosts

			#echo "Newly added site to hosts file:"

			#cat /etc/hosts | grep $HOST_TO_ADD

			echo $HOST_TO_ADD
		
			exit 0
		else
			echo "Error!"
			exit 1
		fi
	fi
fi
