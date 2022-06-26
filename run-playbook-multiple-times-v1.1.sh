#!/bin/bash

############################################################
# Help                                                     #
############################################################

function showHelp()
{
   echo "Run a playbook multiple time using a running number"
   echo
   echo "Syntax: $0 -p <playbook-file> -c <a-number> -a <args-to-ansible>"
   echo "options:"
   echo "h     show help."
   echo "p     playbook file to run."
   echo "c     number of times to run."
   echo "a     args with counters to send to ansible."
   echo "		- use '####' for a number without padding and '@@@@' for a number with padding"
   echo "		- use one of the above + <a-number> for limiting a specific argument to a given number and make its counter reset before the main counter ends."
   echo "			E.g. 'myArg-@@@@5' with a given main counter (-c) of 10 will cause to reset back to 1 after 5 main iterations making 'my-Arg-05' the maximum value"
   
   echo
   
   echo "E.g.: $0 -p ./my-playbook.yaml -c 30 -a 'my-vm-#### my-host-@@@@10'"
   
   echo
}


############################################################
# Main program                                             #
############################################################

# Set variables
WITHOUT_PADDING_PATTERN='####'
WITH_PADDING_PATTERN='@@@@'

ANSIBLE_PLAYBOOK='ansible-playbook'

############################################################
# Process the input options. Add options as needed.        #
############################################################

ANSIBLE_PLAYBOOK_BINARY_LOC=$(which $ANSIBLE_PLAYBOOK)

if [ "$ANSIBLE_PLAYBOOK_BINARY_LOC" == "" ]; then
	echo "Error! Cannot find the 'ansible-playbook' binary file in path!"
	echo "Aborting ..."
	exit 1		             
fi

if ! [ -x "$ANSIBLE_PLAYBOOK_BINARY_LOC" ]; then
	echo "The file given as an 'ansible-playbook' binary file is not executable!"
	echo "Aborting ..."
	exit 1          
fi

# Get the options
while getopts "h:p:c:a:" option; do
   case $option in
      h) # display Help
         showHelp
         exit 0
         ;;
      p) if ! [ -s "$OPTARG" ]; then
		echo "Error! Value given as a playbook file is either empty or does not exist."
         	exit 1		             
      	 else    
      	 	PLAYBOOK_FILE=$OPTARG
	 fi
         ;;
      c) re='^[0-9]+$'
	 
	 if ! [[ $OPTARG =~ $re ]]; then
         	echo "Error! Invalid Number!"
	        exit 1
	 else
	 	COUNTER=$OPTARG
	 fi
         ;;
      a) RAW_INPUT=$OPTARG
		      	
      	 if [ -z "$RAW_INPUT" ]; then
      	 	echo "Error! Invalid Input (empty 'args' value). Nothing to work on. Aborting ..."
         	exit 1
      	 fi
      	 
      	 echo $RAW_INPUT | grep -q $WITHOUT_PADDING_PATTERN
      	 
      	 if [ "$?" -eq 0 ]; then
      	 	NO_PADDING_PATTERN_FOUND=1
      	 fi
      	 
      	 echo $RAW_INPUT | grep -q $WITHOUT_PADDING_PATTERN
      	 
      	 if [ "$?" -eq 0 ]; then
      	 	NO_PADDING_PATTERN_FOUND=1
      	 fi

      	 echo $RAW_INPUT | grep -q $WITH_PADDING_PATTERN
      	 
      	 if [ "$?" -eq 0 ]; then
      	 	PADDING_PATTERN_FOUND=1
      	 fi
      	 
      	 if [ "$NO_PADDING_PATTERN_FOUND" -ne 1 -a "$PADDING_PATTERN_FOUND" -ne 1 ]; then
	      	echo "Error! Invalid Input (no patterns found in the 'args' value). Nothing to work on. Aborting ..."
         	exit 1      	 	
      	 fi
         ;;
      *) echo "Error! Invalid option!"
         showHelp
         exit 1
         ;;
   esac
done

if [ "$PLAYBOOK_FILE" == "" -a "$COUNTER" == "" -a "$RAW_INPUT" == "" ]; then
         echo "Error! Bad usage. Please check your input and try again."
         showHelp
         exit 1
fi

# check if limits were set for args
LIMITS_FOR_WITH_PADDING=$(echo $RAW_INPUT | grep -o "$WITH_PADDING_PATTERN.*" | grep -Eo "[0-9]+" | tr '\n' ' ')
LIMITS_FOR_WITHOUT_PADDING=$(echo $RAW_INPUT | grep -o "$WITHOUT_PADDING_PATTERN.*" | grep -Eo "[0-9]+" | tr '\n' ' ')

for CURRENT_COUNTER in $(seq 1 $COUNTER); do
	# set / reset the param in order to get updated values
	MODIFIED_ARGS=$RAW_INPUT

	# handle args with limits - we are using a math reminder operation to cut the main counter according to the limit settings and reset the value up to that limit
	if ! [ "$LIMITS_FOR_WITH_PADDING" == "" ]; then
		for CURRENT_LIMIT in $LIMITS_FOR_WITH_PADDING; do
			REMINDER=$(expr $CURRENT_COUNTER % $CURRENT_LIMIT)
			
			echo $REMINDER
			
			if [ "$REMINDER" -eq 0 ]; then
				NEW_VALUE=$CURRENT_LIMIT
			else
				NEW_VALUE=$REMINDER
			fi
			
			if [ "$NEW_VALUE" -gt 9 ]; then
				MODIFIED_ARGS=$(echo $MODIFIED_ARGS | sed 's/'$WITH_PADDING_PATTERN$CURRENT_LIMIT'/'$NEW_VALUE'/g')
			else
				MODIFIED_ARGS=$(echo $MODIFIED_ARGS | sed 's/'$WITH_PADDING_PATTERN$CURRENT_LIMIT'/0'$NEW_VALUE'/g')
			fi
		done
	fi

	if ! [ "$WITHOUT_PADDING_PATTERN" == "" ]; then
		for CURRENT_LIMIT in $LIMITS_FOR_WITHOUT_PADDING; do
			REMINDER=$(expr $CURRENT_COUNTER % $CURRENT_LIMIT)
			
			if [ "$REMINDER" -eq 0 ]; then
				NEW_VALUE=$CURRENT_LIMIT
			else
				NEW_VALUE=$REMINDER
			fi
				
			MODIFIED_ARGS=$(echo $MODIFIED_ARGS | sed 's/'$WITHOUT_PADDING_PATTERN$CURRENT_LIMIT'/'$NEW_VALUE'/g')
		done
	fi
	
	# handle args without limits
	if [ "$CURRENT_COUNTER" -gt 9 ]; then
		MODIFIED_ARGS=$(echo $MODIFIED_ARGS | sed 's/'$WITH_PADDING_PATTERN'/'$CURRENT_COUNTER'/g')
	else
		MODIFIED_ARGS=$(echo $MODIFIED_ARGS | sed 's/'$WITH_PADDING_PATTERN'/0'$CURRENT_COUNTER'/g')
	fi
	
	MODIFIED_ARGS=$(echo $MODIFIED_ARGS | sed 's/'$WITHOUT_PADDING_PATTERN'/'$CURRENT_COUNTER'/g')
	
	echo "Iteration #$CURRENT_COUNTER: Running the command '$ANSIBLE_PLAYBOOK_BINARY_LOC --extra-args=\"$MODIFIED_ARGS\" $PLAYBOOK_FILE'"
	
	# $ANSIBLE_PLAYBOOK_BINARY_LOC --extra-args="$MODIFIED_ARGS"
done




