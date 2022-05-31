#!/bin/bash

###################
# Setup Parameters
###################

PROXY_ADDR=192.168.1.1
PROXY_PORT=3218
NO_PROXY_ADDRESSES=localhost,127.0.0.1

PROXY_SCRIPT_FILE_NAME=all-v2.29.sh

# this array defines what commands require running a proxy script BEFORE them
# array items must be in quotes because the items themselves have spaces (and the default delimiter for arrays is space)
PRE_INSTALL_CMDS_ARR=("pip install" "dotnet restore" "npm install" "go build" "go install")

# some pkgs overwrite ssl certificates when they are being installed so we need to detect these and run the proxy script AFTER them on these cases so that our certs will be restored
# DON'T put any spaces here after the expr ".*" otherwise grep won't catch expressions like "apk add curl" because it will be matching only TWO spaces 
#POST_INSTALL_CMDS_ARR=("apk ((add)|(upgrade)) .*((curl)|(wget)|(ca-certificates))")
#POST_INSTALL_CMDS_ARR=("apk ((add)|(upgrade)) .*((curl)|(ca-certificates))")
POST_INSTALL_CMDS_ARR=("apk ((add)|(upgrade)) .*((curl)|(wget)|(ca-certificates))" "((apt)|(apt-get)) install .*((curl)|(wget)|(ca-certificates))")


###################
# Inner Parameters
###################

PROXY_UNDO_SCRIPT_FILE_NAME='undo-'$PROXY_SCRIPT_FILE_NAME

PRE_RUN_SECTION_ADDED_BY_LINE='# Pre-Run-Section-Added-by-'$(basename $0)
PRE_INSTALL_SECTION_ADDED_BY_LINE='# Pre-Install-Section-Added-by-'$(basename $0)
POST_INSTALL_SECTION_ADDED_BY_LINE='# Post-Install-Section-Added-by-'$(basename $0)
FINALLY_SECTION_ADDED_BY_LINE='# Finally-Section-Added-by-'$(basename $0)

SED_ENV_SECTION='ENV\ HTTP_PROXY\ http:\/\/'$PROXY_ADDR':'$PROXY_PORT'\nENV\ HTTPS_PROXY\ http:\/\/'$PROXY_ADDR':'$PROXY_PORT'\nENV\ http_proxy\ http:\/\/'$PROXY_ADDR':'$PROXY_PORT'\nENV\ https_proxy\ http:\/\/'$PROXY_ADDR':'$PROXY_PORT'\nENV\ NO_PROXY\ '$NO_PROXY_ADDRESSES'\nENV\ no_proxy\ '$NO_PROXY_ADDRESSES

SED_USER_ROOT_SECTION='USER\ root'

SED_PROXY_SCRIPT_SECTION='COPY\ '$PROXY_SCRIPT_FILE_NAME'\ \/tmp\nCOPY\ '$PROXY_UNDO_SCRIPT_FILE_NAME'\ \/tmp\nRUN\ sh\ \/tmp\/'$PROXY_SCRIPT_FILE_NAME

SED_PROXY_SCRIPT_SECTION_RUN_ONLY_DO='RUN\ sh\ \/tmp\/'$PROXY_SCRIPT_FILE_NAME

SED_PROXY_SCRIPT_SECTION_RUN_ONLY_UNDO='RUN\ sh\ \/tmp\/'$PROXY_UNDO_SCRIPT_FILE_NAME

CAT_PROXY_SCRIPT_SECTION_RUN_ONLY_UNDO='RUN sh /tmp/'$PROXY_UNDO_SCRIPT_FILE_NAME

BACKUP_FILE_NAME_PREFIX='Backed-Up-by-'$(basename $0)

###################
# Functions
###################

scanForInstallCmdsAndInsertProxyScriptCalls()
{
    # function params:
    # $1 = array of pre install cmds to work on
    # $2 = array of post install cmds to work on
    # $3 = the file to work on
    
    local -n preInstallCmdsArr=$1
    local -n postInstallCmdsArr=$2
    local -n dockerFile=$3
    
    if [ -s "$dockerFile" ]; then
        # before going over the dockerfile, we must make it flat first - meaning only one command per line even if it is long.
        # so we need to convert divided lines to one liners by removing slashes when they appear at end of lines using 'sed -z'
        
        echo "Converting new lines into one liners if needed ..."
        
        sed -i -z 's/\\\s*\n\s*//g' $dockerFile
    
        for ((i = 0; i < ${#preInstallCmdsArr[@]}; i++))
        do
              grep -Eq "${preInstallCmdsArr[$i]}" $dockerFile
              
              if [ "$?" -eq 0 ]; then
                  grep -q "$PRE_INSTALL_SECTION_ADDED_BY_LINE" $dockerFile
                
                  if ! [ "$?" -eq 0 ]; then
                      echo "Found an install cmd '${preInstallCmdsArr[$i]}'. Adding a pre-install proxy settings BEFORE it ..."
                      
                      sed -r -i "s/(.*${preInstallCmdsArr[$i]}.*)/$PRE_INSTALL_SECTION_ADDED_BY_LINE\n$SED_PROXY_SCRIPT_SECTION_RUN_ONLY_DO\n\1/" $dockerFile
                  #else
                  #     echo "Pre-Install section(s) already exist(s)."
                  fi
              fi
        done
        
        for ((i = 0; i < ${#postInstallCmdsArr[@]}; i++))
        do
              #echo "DEBUG: grep cmd: grep -Eq '${postInstallCmdsArr[$i]}' $dockerFile"
              
              grep -Eq "${postInstallCmdsArr[$i]}" $dockerFile
              
              if [ "$?" -eq 0 ]; then
                  grep -q "$POST_INSTALL_SECTION_ADDED_BY_LINE" $dockerFile
                
                  if ! [ "$?" -eq 0 ]; then
                      echo "Found an install cmd '${postInstallCmdsArr[$i]}'. Adding a post-install proxy settings AFTER it ..."
                      
                      sed -r -i "s/(.*${postInstallCmdsArr[$i]}.*)/\1\n$POST_INSTALL_SECTION_ADDED_BY_LINE\n$SED_PROXY_SCRIPT_SECTION_RUN_ONLY_DO/" $dockerFile
                  #else
                  #     echo "Post-Install section(s) already exist(s)."
                  fi
              fi
        done
    else
          echo "ERROR! the file '$dockerFile' is either empty or does not exist. Aborting ..."
    fi
}

fixSpecialCases()
{
    # function params:
    # $1 = the file to work on
    
    local -n dockerFile=$1
    
    WGET_INSTALL_ADDED_BY_LINE='# Wget-Install-Added-by-'$(basename $0)
    WGET_CMD_LINE_SEARCH_PATTERN_1='((RUN wget)(.*))'
    WGET_CMD_LINE_SEARCH_PATTERN_2='(&& wget.*)'
    # this pattern is needed for multiple substitutions of wget calls - specifically for a fix that adds a switch to any wget call. the pattern divides a line by using the pattern "[^&&]" which means "all chars but &&"
    WGET_CMD_LINE_SEARCH_PATTERN_3='((&& wget)([^&&]))'
    # for detection we can use patterns 1 and 2 only because it is enough
    WGET_CMD_LINE_SEARCH_PATTERN_DETECT=$WGET_CMD_LINE_SEARCH_PATTERN_1'|'$WGET_CMD_LINE_SEARCH_PATTERN_2
    # the 'exit 0' part of the command is needed in cases where alpine is not the os in use - this line will make this command exit successfully even when there was an error while running it
    WGET_APK_INSTALL_CMD_VIA_DOCKERFILE_1='RUN apk add wget; exit 0'
    # the & is sed is a special character which means "repeat the matched pattern" - like \1 - so we need to escape it to get it literally
    WGET_APK_INSTALL_CMD_VIA_DOCKERFILE_2='\&\& apk add wget; exit 0\n'$WGET_INSTALL_ADDED_BY_LINE'\nRUN echo '
    
    APT_UPDATE_CMD_REVISED_BY_LINE='# Apt-Update-Revised-by-'$(basename $0)
    APT_UPDATE_CMD_SEARCH_PATTERN='((apt\ update)|(apt-get\ update))'
    APT_UPDATE_REVISED_CMD='apt-get\ --allow-insecure-repositories\ update'

    APT_INSTALL_CMD_REVISED_BY_LINE='# Apt-Install-Revised-by-'$(basename $0)
    APT_INSTALL_CMD_SEARCH_PATTERN='((apt\ install)|(apt-get\ install))'
    APT_INSTALL_REVISED_CMD='apt-get\ --allow-unauthenticated\ install'
    
    ALPINE_VERIFY_SEARCH_PATTERN_1='(apk)|(alpine)'
    ALPINE_VERIFY_SEARCH_PATTERN_2='(apt.*)|(yum.*)'
    
    WGET_RUN_REVISED_BY_LINE='# Wget-Run-Revised-by-'$(basename $0)
    WGET_RUN_REVISED_SWITCH='--allow-unauthenticated'
    WGET_CMD_LINE_SEARCH_PATTERN_BASIC='wget\ '
    
    if [ -s "$dockerFile" ]; then
          # wget special case - replace the minimal built-in to busybox 'wget' cmd with a full 'wget' cmd in order to get support for advanced options such as sending ssl requests via proxy
          grep -q "$WGET_INSTALL_ADDED_BY_LINE" $dockerFile
          
          if ! [ "$?" -eq 0 ]; then
              echo "Searching for 'wget' usage (Alpine only wget fix) ..."
              
              grep -Eq "$WGET_CMD_LINE_SEARCH_PATTERN_DETECT" $dockerFile
              
              if [ "$?" -eq 0 ]; then
                    echo "Found usage. Trying to verify OS type (will update Alpine installations only) ..."
                    
                     grep -Eq "$ALPINE_VERIFY_SEARCH_PATTERN_1" $dockerFile
                     
                     if ! [ "$?" -eq 0 ]; then
                          # a REVERSED check - verify that this Dockerfile is not running other OSes install cmds
                          grep -Eq "$ALPINE_VERIFY_SEARCH_PATTERN_2" $dockerFile
                          
                          if [ "$?" -eq 0 ]; then
                                echo "The OS been used is not Alpine so nothing to update here ..."
                                echo "Skipping ..."
                          else
                                echo "Could not verify the OS type to be Alpine. You may want to update manually if needed."
                                echo "Ignoring ..."
                          fi
                     else
                          echo "Alpine OS verified."
                          echo "Adding a new 'apk add wget' cmd before the 'wget' cmd usage ..."
                          
                          # on substitution here we use pattern 2 and not 3 because for this fix we only need to add a new call once and we need it before the wget call and outside of it so we don't want to get sub calls here
                          sed -r -i "s/($WGET_CMD_LINE_SEARCH_PATTERN_1)/$WGET_INSTALL_ADDED_BY_LINE\n$WGET_APK_INSTALL_CMD_VIA_DOCKERFILE_1\n$SED_PROXY_SCRIPT_SECTION_RUN_ONLY_DO\n\1/" $dockerFile
                          sed -r -i "s/($WGET_CMD_LINE_SEARCH_PATTERN_2)/$WGET_INSTALL_ADDED_BY_LINE\n$WGET_APK_INSTALL_CMD_VIA_DOCKERFILE_2\n$SED_PROXY_SCRIPT_SECTION_RUN_ONLY_DO\n\1/" $dockerFile                          
                     fi
              else
                    echo "Did not find 'wget' usage."
              fi
          else
                echo "A 'wget' install fix was already added."
          fi
          
          # apt special case - replace either 'apt update' or 'apt-get update' with 'apt-get --allow-insecure-repositories update' so that the command won't fail because of failures to access gpg keys for repos via the proxy
          grep -q "$APT_UPDATE_CMD_REVISED_BY_LINE" $dockerFile
          
          if ! [ "$?" -eq 0 ]; then
              echo "Searching for 'apt update' or 'apt-get update' usage ..."
              
              grep -Eq "$APT_UPDATE_CMD_SEARCH_PATTERN" $dockerFile
              
              if [ "$?" -eq 0 ]; then
                    echo "Found usage. Adding a new switch '--allow-insecure-repositories' inside it ..."
                    
                    # here we need to replace only the cmd and then add the 'added-by' section seperately because the apt cmd might be in the middle of some other cmds on one hand and on the other it might start with the directive "RUN" and it might not so we can't rely on non of the above and we must make the append after updating the cmd by using grep -n and sed append
                    sed -r -i "s/$APT_UPDATE_CMD_SEARCH_PATTERN/$APT_UPDATE_REVISED_CMD/" $dockerFile
                    
                    LINE_NUMBER=$(grep -En "$APT_UPDATE_REVISED_CMD" $dockerFile | awk -F: '{print $1}')
                    
                    echo $LINE_NUMBER | grep -Eq "[0-9]+"
                    
                    if [ "$?" -eq 0 ]; then
                        let LINE_NUMBER=LINE_NUMBER-1
                    
                        sed -i "$LINE_NUMBER a $APT_UPDATE_CMD_REVISED_BY_LINE" $dockerFile
                    else
                        echo "ERROR! Unexpected error!"
                    fi
              else
                    echo "Did not find 'apt update' or 'apt-get upate' usage."
              fi
          else
                echo "An 'apt update' fix was already added."
          fi
 
          # apt special case 2 - replace either 'apt install' or 'apt-get install' with 'apt-get --allow-unauthenticated install' so that the command won't fail because of failures to access signed repos via the proxy
          grep -q "$APT_INSTALL_CMD_REVISED_BY_LINE" $dockerFile
          
          if ! [ "$?" -eq 0 ]; then
              echo "Searching for 'apt install' or 'apt-get install' usage ..."
              
              #echo "DEBUG: grep cmd: grep -Eq '$APT_INSTALL_CMD_SEARCH_PATTERN' $dockerFile"
              
              grep -Eq "$APT_INSTALL_CMD_SEARCH_PATTERN" $dockerFile
              
              if [ "$?" -eq 0 ]; then
                    echo "Found usage. Adding a new switch '--allow-unauthenticated' inside it ..."
                    
                    # here we need to replace only the cmd and then add the 'added-by' section seperately because the apt cmd might be in the middle of some other cmds on one hand and on the other it might start with the directive "RUN" and it might not so we can't rely on non of the above and we must make the append after updating the cmd by using grep -n and sed append.
                    # the append technique is used on a given line number so we must run a loop here in cases where more then one usage was found.
                    
                    #echo "DEBUG: sed cmd: sed -r -i 's/$APT_INSTALL_CMD_SEARCH_PATTERN/$APT_INSTALL_REVISED_CMD/g' $dockerFile"
                    
                    sed -r -i "s/$APT_INSTALL_CMD_SEARCH_PATTERN/$APT_INSTALL_REVISED_CMD/g" $dockerFile
                    
                    #echo "DEBUG: grep cmd: grep -En '$APT_INSTALL_REVISED_CMD' $dockerFile | awk -F: '{print \$1}' | tr \"\n\" \" \""
                    
                    LINE_NUMBERS=$(grep -En "$APT_INSTALL_REVISED_CMD" $dockerFile | awk -F: '{print $1}' | tr "\n" " ")
                    
                    #echo "DEBUG: LINE_NUMBERS=$LINE_NUMBERS"
                    
                    for i in $LINE_NUMBERS; do
                        # verify that the current expression is a valid number
                        echo $i | grep -Eq "[0-9]+"
                    
                        if [ "$?" -eq 0 ]; then
                            # get to the correct line location - before the 'data' line - the line with the cmd itself
                            let i=i-1
                            
                            #echo "DEBUG: sed cmd: sed -i '$i a $APT_INSTALL_CMD_REVISED_BY_LINE' $dockerFile"
                            
                            sed -i "$i a $APT_INSTALL_CMD_REVISED_BY_LINE" $dockerFile
                        else
                            echo "ERROR! Unexpected error!"
                        fi
                    done
              else
                    echo "Did not find 'apt install' or 'apt-get install' usage."
              fi
          else
                echo "An 'apt install' fix was already added."
          fi
          
          # wget special case - replace a normal wget call with a call with the switch '--no-check-certificate'.
          # reason: even though we have all of the proxy certs installed, on newer system this is not enough because there is also a new check to the certificates which fails due to insufficient key length.
          # proxy certs are too old.
          # the error is: 'EE certificate key too weak'
          grep -q "$WGET_RUN_REVISED_BY_LINE" $dockerFile
          
          if ! [ "$?" -eq 0 ]; then
              echo "Searching for 'wget' usage (add '--no-check-certificate' fix) ..."
              
              WGET_USAGE_COUNT=$(grep -En "$WGET_CMD_LINE_SEARCH_PATTERN_DETECT" $dockerFile)
              
              if ! [ "$WGET_USAGE_COUNT" == "" ]; then
                    echo "Found usage. Making sure the switch is not there ..."
                    
                    # we need to make sure that the number of switches is equal to the number of wget calls 
                    SWITCHES_COUNT=$(grep -En "$WGET_RUN_REVISED_SWITCH" $dockerFile)
                    
                    if [ "$WGET_USAGE_COUNT" == "$SWITCHES_COUNT" ]; then
                         echo "The switch is already present ... Nothing to do ..."
                    else
                          echo "Adding the switch ..."
                          
                          # if only some of the wget calls have the switch and some don't, we first need to remove the switches so that we can add them once to the entire file
                          # remove switch
                          sed -r -i "s/($WGET_RUN_REVISED_SWITCH)//g" $dockerFile
                          
                          # add switch back
                          sed -r -i "s/($WGET_CMD_LINE_SEARCH_PATTERN_1)/$WGET_RUN_REVISED_BY_LINE\n\2 $WGET_RUN_REVISED_SWITCH\3/" $dockerFile
                          sed -r -i "s/($WGET_CMD_LINE_SEARCH_PATTERN_3)/\2 $WGET_RUN_REVISED_SWITCH\3/g" $dockerFile 
                    fi
              else
                    echo "Did not find 'wget' usage."
              fi
          else
              echo "A 'wget' run fix was already added."
          fi
    else
          echo "ERROR! the file '$dockerFile' is either empty or does not exist. Aborting ..."
    fi
}

###################
# Main Program
###################

if [ "$1" == "" ]; then
    echo "ERROR! Wrong Input."
    echo "Usage: $0 <Dockerfile-to-update> [optional: <undo-action>]"
    echo "The undo-action parameter can be one of; 'n', 'no', 'skip'. Using it will make the script NOT to include a call to the proxy undo script in the Dockerfile (Default: add undo call)."
else
    if ! [ -s "$1" ]; then
        echo "ERROR! the file '$1' is either empty or does not exist. Aborting ..."
    else
        #if ! [ -s "$PROXY_SCRIPT_FILE_NAME" ]; then
        #      echo "WARNING: The proxy script itself '$PROXY_SCRIPT_FILE_NAME' was not found next to this script."
        #      echo "Please make sure that you copy the proxy script itself to a place acessible to Docker."
        #fi
        
        DOCKERFILE=$1
        
        CURRENT_LOC=`pwd`
        
        if ! [ -s "$CURRENT_LOC/$PROXY_SCRIPT_FILE_NAME" ]; then
              echo "Warning: Couldn't find the proxy script in current location (which is: '$CURRENT_LOC/$PROXY_SCRIPT_FILE_NAME')."
              echo "Trying to copy it from '${BASH_SOURCE[0]}/$PROXY_SCRIPT_FILE_NAME' ..."
        
              if [ -s "$(dirname ${BASH_SOURCE[0]})/$PROXY_SCRIPT_FILE_NAME" ]; then
                  cp -v $(dirname ${BASH_SOURCE[0]})/$PROXY_SCRIPT_FILE_NAME .
              else
                  echo "Warning: Couldn't find proxy script in '$(dirname ${BASH_SOURCE[0]})/$PROXY_SCRIPT_FILE_NAME'."
                  echo "Please copy it manually."
              fi
        fi

        if ! [ -s "$CURRENT_LOC/$PROXY_UNDO_SCRIPT_FILE_NAME" ]; then
            echo "Warning: Couldn't find the proxy script in current location (which is: '$CURRENT_LOC/$PROXY_UNDO_SCRIPT_FILE_NAME')."
            echo "Trying to copy it from '${BASH_SOURCE[0]}/$PROXY_UNDO_SCRIPT_FILE_NAME' ..."
 
            if [ -s "$(dirname ${BASH_SOURCE[0]})/$PROXY_UNDO_SCRIPT_FILE_NAME" ]; then
                 cp -v $(dirname ${BASH_SOURCE[0]})/$PROXY_UNDO_SCRIPT_FILE_NAME .
            else
                  echo "Warning: Couldn't find proxy script in '$(dirname ${BASH_SOURCE[0]})/$PROXY_UNDO_SCRIPT_FILE_NAME'."
                  echo "Please copy it manually."                  
            fi
        fi
        
        #DOCKERFILE_PATH=$(dirname $DOCKERFILE)
        
        grep -q "$PRE_RUN_SECTION_ADDED_BY_LINE" $DOCKERFILE
        
        if ! [ "$?" -eq 0 ]; then
            # only if a pre-run section does not exist which means that this is the original file - backup it before continuing with the updates
            cp -v $DOCKERFILE $BACKUP_FILE_NAME_PREFIX-$(basename $DOCKERFILE)
        
            echo "Adding basic proxy settings after every 'FROM' line (Pre-Run section) ..."
            # add the proxy ENV params and a first proxy script call to the begining of the docker file
            sed -i "s/\(^FROM.*\)/\1\n\n$PRE_RUN_SECTION_ADDED_BY_LINE\n$SED_ENV_SECTION\n$SED_USER_ROOT_SECTION\n$SED_PROXY_SCRIPT_SECTION/" $DOCKERFILE
        else
            echo "Pre-Run section(s) already exist(s)."
        fi
        
         echo "Searching for installation cmds and adding a proxy call before or after them if needed (Pre-Install and Post-Install sections) ..."
         
         grep -q "$PRE_INSTALL_SECTION_ADDED_BY_LINE" $DOCKERFILE
         
         PRE_RESULT=$?
         
         grep -q "$POST_INSTALL_SECTION_ADDED_BY_LINE" $DOCKERFILE
         
         POST_RESULT=$?
         
         #echo "DEBUG: PRE_RESULT=$PRE_RESULT, POST_RESULT=$POST_RESULT"
         
         if [ "$PRE_RESULT" -gt 0 -o "$POST_RESULT" -gt 0 ]; then
              scanForInstallCmdsAndInsertProxyScriptCalls PRE_INSTALL_CMDS_ARR POST_INSTALL_CMDS_ARR DOCKERFILE
              
              #grep -q "$PRE_INSTALL_SECTION_ADDED_BY_LINE" $DOCKERFILE
              
              #if [ "$?" -eq 0 ]; then
              #      echo "All pre-installation sections that needed an update were updated."
              #fi
              
              #grep -q "$POST_INSTALL_SECTION_ADDED_BY_LINE" $DOCKERFILE
              
              #if [ "$?" -eq 0 ]; then
              #      echo "All post-installation sections that needed an update were updated."
              #fi             
         else
              if [ "$PRE_RESULT" -eq 0 ]; then              
                  echo "Pre-Install section(s) already exist(s)."
              fi

              if [ "$POST_RESULT" -eq 0 ]; then              
                  echo "Post-Install section(s) already exist(s)."
              fi              
         fi
         
         echo "Running extra tests and fixes ..."
         
         fixSpecialCases DOCKERFILE
         
         echo "Checking if a call to the proxy undo script needs to be added at the end of the file (a finally section) ..."
         
         grep -q "$FINALLY_SECTION_ADDED_BY_LINE" $DOCKERFILE
         
         if [ "$?" -eq 0 ]; then
              echo "There is no need to add a call to the proxy undo script at the end of the file as it already exists."
         else
              if [ "$2" == "n" -o "$2" == "no" -o "$2" == "skip" ]; then
                  echo "NOT Adding a call to the proxy undo script due to user request."
              else
                  echo "Adding a call to the proxy undo script at the end of the file (Finally section) ..."

                  echo $FINALLY_SECTION_ADDED_BY_LINE >> $DOCKERFILE
                  echo $CAT_PROXY_SCRIPT_SECTION_RUN_ONLY_UNDO >> $DOCKERFILE
              fi
         fi
    fi
fi