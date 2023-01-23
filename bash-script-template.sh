#!/bin/bash

# function examples

function printToLogAndConsole()
{
	# params:
	# $1 - data to print
	# $2 - log file to print to
	
	if [ -n "$1" ]; then
		CURRNET_DATE=$(echo $DATE_FORMAT | bash)
		
		echo "$CURRNET_DATE $1" | tee -a $2
	fi
}

printToLogAndConsole "ERROR! This script requires root privileges!" $LOG_FILE_SPEC


function returnSomethingWithParam()
{
	echo "something with param $1"
}

RESULT=$(returnSomething "myParam")



# get data from the user
read -p "name:" name;echo "hello $name"


# check if number using regex

re='^[0-9]+$'

if ! [[ $yournumber =~ $re ]] ; then
	echo "NOT a number!"
fi


# work with arguments
# use -o for "or" and -a for "and"

if [ "$1" == "" -o "$2" == "" ]; then
	echo "ERROR! Wrong Input."
	echo "Usage: $0 <tar.gz_archive_file_to_check> <extra-flag>"
else
	
fi


# select case

case $1 in

	"$PROD_ENV_NAME") WORKING_ENV=prod
	;;
	"$TEST_ENV_NAME") WORKING_ENV=test
	;;
	*) WORKING_ENV=
esac


# dates

# for files - format example: "-2022-08-18_10-21-49"
date +-%Y-%m-%d_%H-%M-%S

# general - format example: "10:20:09 18/08/2022"
date "+%H:%M:%S %d/%m/%Y"

# for logs - format example: "18/08/2022 10:23:44"
date "+%d/%m/%Y %H:%M:%S"


# ignore errors
cmd 2>/dev/null


# working with grep

# grep -q does not return any found data
# check error codes with it:
# 0 = match found
# 1 = no match found
# 2 = file not found (file to work on)
# be sure to adjust your logic when using grep - sometimes "found" is good, sometimes it is not ...
# e.g.
grep -q "search for that" in_this_file 2>/dev/null

if [ "$?" -eq 1 ]; then
	echo "no match!"
fi

if [ "$?" -eq 2 ]; then
	echo "file not found!"
fi

# ref a variable via string using the special pattern '${!ref}':

var1="this is the real value"
ref="var1"
echo "${!ref}" # outputs 'this is the real value'


# Getting a sub string from a string

STR="a-string-to-check"

# get only last 2 chars
echo "${STR:${#STR}-2}"

# get all but last 2 chars
echo "${STR:0:${#STR}-2}"

# get all but 2 first chars
echo "${STR:2}"

# get only 2 first chars
echo ${STR:0:2}

# get number of tokens in a string (the delimiter is space)

ARR='some string with words'

ARR=($ARR)

echo ${#ARR[@]}
 

# Get script location
echo `dirname ${BASH_SOURCE[0]}`


# Run a command on a find result list

find . -name "settings.php" -exec grep ^\$conf.*base_url.* {} \;


# Run a set of commands via loop based on a bash command result

# Example 1

for i in $(ls); do 
	echo $i
	mv $i /tmp
done

# Example 2

for i in $(find . -name "$DRUPAL_SETTINGS_FILE"); do 
	echo $i
	cp $i /tmp
done

# Example 3

TOKENS="/dir1 /dir2"

for i in $(echo "$TOKENS"); do
	echo $i
done


# Example 4

TOKENS="/dir1 /dir2"

for i in $TOKENS; do
	echo $i
done

	
# Conditions:
# ! = not
# "-a" = checks if a file exists
# "-d" = checks if a dir exists
# "-h" = check if a symbolic link exists
# "-s" = checks if a file exists and not empty
# "-z" = checks if a STRING is empty
# "-n" = checks if a STRING is NOT empty
# "$?" = reffers to the last error code [make sure you use it RIGHT AFTER the cmd to test]
# The SPACES are a MUST since the signs [ and ] are files!

# double negate
if [ "$?" != 0 -a "$1" != "" ]; then

if ! [ -s /etc/init.d/httpd ]; then
else
fi

if ! [ -z "$SOME_VAR" ]; then
else
fi

if [ -d "dir_to_check" ]; then
fi

if ! [ -h "symbolic_link_to_check" ]; then
fi

# Check a status of a last command. "0" means succes!

# Your command goes here before the condition.

cp a b

if ! [ "$?" == "0" ]; then
	echo Your last command was NOT a success! 
fi

# Using math \ counters

COUNTER=1

for i in $(ls); do
	echo $COUNTER\) $i
	COUNTER=$(expr $COUNTER + 1)
done



# Using sed:

# sed -i = overwite the file with the changes (without -i sed will only print the change)

#/g = "greedy" - replace again and again if found more than once

# sed -i "s/findThisText/replaceItWithThisText/g" file_to_update

# sed -i "s/\<.*\>/\<new_stuff\>/g" file_to_update
				     
#sed "s/\(.*base_url.*\)/\#\1/g" settings.php

#grep -v "#" $SETTINGS_FILE_NAME | grep -v "^//" | grep -v "*" | sed "s/$base_url\(.*\):\/\/.*;/$base_url\1:\/\/$FQDN;/g" 

#grep -v "*" $SETTINGS_FILE_NAME | sed "s/'database'\s*=>\s*'.*'/'database' => '"$2"'/g"
	
