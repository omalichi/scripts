#!/bin/bash

# this script replaces texts in a given file in 3 ways by going over a text file with replacements - each line represents one replacement:
# 1. a yaml-based key-value replacement. Syntax: a colon AND a space MUST be between the key and value. E.g. in the example 'port: 8088' any place the 'port' word will be found with colon and a space after it its value will be replaced in the given file with the value '8088'.
# 2. an orderly yaml-based replacement. Syntax: an index number followed by a special delimiter of a '~' char and then the key-value pair in the same convention as noted above in option #1.
# E.g. the given line of '3~indexName: k8s' with replace ONLY the 3RD occurence of the value represented the key 'indexName'.
# 3. a general string replacement.  Syntax: the word 'generic' followed by a '~' char and then the "from" and "to" parts of the replacement where the same delimiter of a colon and a space MUST be present between the two. E.g. the line 'generic~ splunk/: \ security/splunk/' will replace every occurence of the expression ' splunk/' with '\ security/splunk/'. Note that the second space in the "to" expression '\ ' is mandatory to keep the yaml structure intact.



# must be with space and must consist 2 chars so that a colon as data or a space as data will not be ignored
KEY_VALUE_DELIMITER=':\ '
REPEATED_FIELDS_DELIMITER='~'
GENERIC_UPDATE_CMD_DELIMITER='generic'

if [ "$1" == "" -o "$2" == "" ]; then
	echo "ERROR! Wrong usage."
	echo "Usage: $0 <fields-file-to-work-with> <file-to-update>"
else
	if ! [ -s "$1" ]; then
		echo "ERROR! file '$1' must be a valid non-empty file. Please try again ..."
		echo "Aborting ..."
	else
		if ! [ -s "$2" ]; then
			echo "ERROR! file '$2' must be a valid non-empty file. Please try again ..."
			echo "Aborting ..."
		else
			FIELDS_FILE=$1
			FILE_TO_UPDATE=$2
			
			BKUP_IFS=$IFS
			
			IFS=$'\n'
			
			for i in $(cat $FIELDS_FILE)
			do
				CURRENT_FIELD=$i
				
				FIELD_NAME=$(echo $CURRENT_FIELD | awk -F$KEY_VALUE_DELIMITER '{print $1}')
				
				echo $FIELD_NAME | grep $REPEATED_FIELDS_DELIMITER &>/dev/null
				
				STATUS=$?
				
				echo "DEBUG: FIELD_NAME=$FIELD_NAME"
				
				# repeated field detected - find the appropriate location
				if [ "$STATUS" -eq 0 ]; then
					REPEAT_SERIAL_OR_CMD=$(echo $FIELD_NAME | awk -F$REPEATED_FIELDS_DELIMITER '{print $1}')

					if [ "$REPEAT_SERIAL_OR_CMD" == "" ]; then
						echo "FATAL ERROR! Encountered a parsing error!"
						
						echo "DEBUG DATA:"
						echo "REPEAT_SERIAL_OR_CMD = $REPEAT_SERIAL_OR_CMD"
						
						echo "Aborting ..."
						
						exit 1
					fi					
					
					echo "DEBUG: REPEAT_SERIAL_OR_CMD=$REPEAT_SERIAL_OR_CMD"
					
					# a command for general replace was detected ...
					if [ "$REPEAT_SERIAL_OR_CMD" == "$GENERIC_UPDATE_CMD_DELIMITER" ]; then						
						FROM=$(echo $FIELD_NAME | awk -F$REPEATED_FIELDS_DELIMITER '{print $2}')
						TO=$(echo $CURRENT_FIELD | awk -F$KEY_VALUE_DELIMITER '{print $2}')
						
						echo "DEBUG: FIELD_NAME=$FIELD_NAME"
						echo "DEBUG: FROM=$FROM"
						echo "DEBUG: TO=$TO"
						echo "DEBUG: KEY_VALUE_DELIMITER=$KEY_VALUE_DELIMITER"
						echo "DEBUG: REPEATED_FIELDS_DELIMITER=$REPEATED_FIELDS_DELIMITER"
						
						echo "DEBUG: about to run the cmd \"sed -i 's#$FROM#$TO#g' $FILE_TO_UPDATE\""
						
						# change sed's default delimiter to '#' to avoid problems when the data itself contains the char "/"
						#sed -i "s#$FROM#$TO#g" $FILE_TO_UPDATE
						
						sed -i -r "h;s+[^#]*++1;x;s+#.*++;s+$FROM+$TO+g;G;s+(.*)\n+\1+" $FILE_TO_UPDATE

						# Explanation:
						# h; - Save in hold buffer
						# s/[^#]*//1; - Remove everything before #
						# x; - Swap with hold buffer
						# s/#.*//; - Remove the comment
						# s/test/TEST/g; - Replace all occurences of test with TEST
						# G; - Append newline + hold buffer (the comment)
						# s/(.*)\n/\1/ - Remove the last newline
						# The -r switch is required for using \1. 
					else
						# check if the extracted expression is a number
						if [[ "$REPEAT_SERIAL_OR_CMD" =~ ^[0-9]+$ ]]; then
							FIELD_NAME_WITHOUT_REPEAT_SERIAL=$(echo $FIELD_NAME | awk -F$REPEATED_FIELDS_DELIMITER '{print $2}')
						
							if [ "$REPEAT_SERIAL_OR_CMD" == "" -o "$FIELD_NAME_WITHOUT_REPEAT_SERIAL" == "" ]; then
								echo "FATAL ERROR! Encountered a parsing error!"
								
								echo "DEBUG DATA:"
								echo "REPEAT_SERIAL_OR_CMD = $REPEAT_SERIAL_OR_CMD"
								echo "FIELD_NAME_WITHOUT_REPEAT_SERIAL = $FIELD_NAME_WITHOUT_REPEAT_SERIAL"
								
								echo "Aborting ..."
								
								exit 2
							fi
							
							echo 'DEBUG: about to run the cmd "cat '$FILE_TO_UPDATE' | grep -v "#" | grep -n "'$FIELD_NAME_WITHOUT_REPEAT_SERIAL':" | nl | tr -d ":" | grep "^\s*'$REPEAT_SERIAL_OR_CMD'" | awk "{print $2}"'
							
							LOC=$(cat $FILE_TO_UPDATE | grep -n "$FIELD_NAME_WITHOUT_REPEAT_SERIAL:" | nl | tr -d ":" | grep "^\s*$REPEAT_SERIAL_OR_CMD" | awk '{print $2}')
							
							if [ "$LOC" == "" ]; then
								echo "FATAL ERROR! Encountered a parsing error!"
								
								echo "DEBUG DATA:"
								echo "LOC = $LOC"
								echo "FIELD_NAME_WITHOUT_REPEAT_SERIAL = $FIELD_NAME_WITHOUT_REPEAT_SERIAL"
								echo "REPEAT_SERIAL_OR_CMD = $REPEAT_SERIAL_OR_CMD"
								
								echo "Aborting ..."
								
								exit 3
							fi
							
							FIELD_DATA=$(echo $CURRENT_FIELD | awk -F$KEY_VALUE_DELIMITER '{print $2}')
							UPDATED_FIELD="$FIELD_NAME_WITHOUT_REPEAT_SERIAL$KEY_VALUE_DELIMITER$FIELD_DATA"
							
							echo "DEBUG: about to run the cmd \"sed -i '${LOC}s#$FIELD_NAME_WITHOUT_REPEAT_SERIAL.*#$UPDATED_FIELD#' $FILE_TO_UPDATE\""
							
							# change sed's default delimiter to '#' to avoid problems when the data itself contains the char "/"
							#sed -i "${LOC}s#$FIELD_NAME_WITHOUT_REPEAT_SERIAL.*#$UPDATED_FIELD#" $FILE_TO_UPDATE
							
							sed -i -r "h;s+[^#]*++1;x;s+#.*++;${LOC}s+$FIELD_NAME_WITHOUT_REPEAT_SERIAL.*+$UPDATED_FIELD+;G;s+(.*)\n+\1+" $FILE_TO_UPDATE

							# Explanation:
							# h; - Save in hold buffer
							# s/[^#]*//1; - Remove everything before #
							# x; - Swap with hold buffer
							# s/#.*//; - Remove the comment
							# s/test/TEST/g; - Replace all occurences of test with TEST
							# G; - Append newline + hold buffer (the comment)
							# s/(.*)\n/\1/ - Remove the last newline
							# The -r switch is required for using \1. 							
						else
							echo "Unexpected error occured!"
							
							echo "DEBUG DATA:"
							echo "REPEAT_SERIAL_OR_CMD = $REPEAT_SERIAL_OR_CMD"
						fi
					fi
				else
					echo "DEBUG: about to run the cmd \"sed -i 's#$FIELD_NAME.*#$CURRENT_FIELD#g' $FILE_TO_UPDATE\""
					
					# change sed's default delimiter to '#' to avoid problems when the data itself contains the char "/"
					#sed -i "s#$FIELD_NAME.*#$CURRENT_FIELD#g" $FILE_TO_UPDATE
					
					sed -i -r "h;s+[^#]*++1;x;s+#.*++;s+$FIELD_NAME.*+$CURRENT_FIELD+g;G;s+(.*)\n+\1+" $FILE_TO_UPDATE

					# Explanation:
					# h; - Save in hold buffer
					# s/[^#]*//1; - Remove everything before #
					# x; - Swap with hold buffer
					# s/#.*//; - Remove the comment
					# s/test/TEST/g; - Replace all occurences of test with TEST
					# G; - Append newline + hold buffer (the comment)
					# s/(.*)\n/\1/ - Remove the last newline
					# The -r switch is required for using \1. 
				fi
			done
			
			IFS=$BKUP_IFS
		fi
	fi
fi
