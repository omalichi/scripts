#!/bin/bash

if [ "$1" == "" ]; then
	echo ERROR: Wrong Input. 
	echo Usage: $0 \<password_length\>
else
	RAND_CMD="cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $1 | head -1"

	PASSWORD=`echo $RAND_CMD | sh`

	echo $PASSWORD | grep "[0-9]" | grep "[A-Z]" | grep "[a-z]" > /dev/nul

	while ! [ "$?" == "0" ]
	do
		PASSWORD=`echo $RAND_CMD | sh`

		echo $PASSWORD | grep "[0-9]" | grep "[A-Z]" | grep "[a-z]" > /dev/nul
	done

	echo $PASSWORD
fi


