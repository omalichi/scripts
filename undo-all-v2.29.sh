##!/bin/bash -x
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
## not verified: debian npm ca bundle (directory): /usr/share/ca-certificates/mozilla
# debian npm pkg name:  apt install npm


##################################################################
# Pre-flight checks
##################################################################
# Since ash shell or sh shell - do not support arrays, before using them we need to switch to bash
# if no bash is found and an Alpine Linux was detected, bash will be added dynamically. 
# if no bash is found this script will call itself again using bash.

ALPINE_BASH_BINARY_FILE_SPEC=/tmp/bash.alpine

BASH_LIBS_LOCATION=/usr/lib
READLINE_LIB_FILE_NAME='libreadline.so.8'
NCURSE_LIB_FILE_NAME='libncursesw.so.6'

if [ -s "/etc/alpine-release" ]; then
  echo "Detected Alpine Linux. Version: `cat /etc/alpine-release`"

  echo "Checking if bash is running this script right now ..."
  
  # sending the output using the expression '&>/dev/null' is causing an odd syntax error when running this command in 'sh' so it will be removed for now ...
  
  # 2/8/2021 UPDATE: ps is not always available so we will use /proc instead
  #ps | grep -v "grep" | grep $$ | grep "bash" #&>/dev/null
  
  CURRENT_PID=$(echo $$)
  
  # the tr cmd is required here because there is a null byte in the cmdline file which causes an error when trying to put the file content into a variable
  CURRENT_SHELL=$(cat /proc/$CURRENT_PID/cmdline | tr -d '\0')

  # if the script will be called using bash e.g. 'bash script' and not by running it directly, it will cause the CURRENT_SHELL to contain the script name as well so we need to grep for the word "bash" because it will not always be alone
  echo $CURRENT_SHELL | grep "bash"

  if ! [ "$?" -eq 0 ]; then
      echo "Current running shell is NOT bash. Trying to switch to bash using the binary embedded into this script...."

      getBashForAlpine

      $ALPINE_BASH_BINARY_FILE_SPEC $0
      
      # exit current run
      exit 0
  fi
fi

if [ -s "/etc/lsb-release" ]; then
  # important note!! Debian and Ubuntu's 'sh' shell does not accept escaping using a back slash like so: awk -F\". Therefore one MUST use the other option which is: awk -F'"' otherwise sh will think that the string has not ended (because it sees the \" expression as a start of a string without an ending) giving the error 'Syntax error: Unterminated quoted string'.
  
  echo "Detected Ubuntu Linux. Version: `cat /etc/lsb-release | grep DESC | awk -F'"' '{print $2}'`"

  echo "Checking if bash is running this script right now ..."
  
  # sending the output using the expression '&>/dev/null' is causing an odd syntax error when running this command in 'sh' so it will be removed for now ...
  # 2/8/2021 UPDATE: ps is not always available so we will use /proc instead
  #ps | grep -v "grep" | grep $$ | grep "bash" #&>/dev/null
  
  CURRENT_PID=$(echo $$)
  
  echo $CURRENT_PID
  
  # the tr cmd is required here because there is a null byte in the cmdline file which causes an error when trying to put the file content into a variable
  CURRENT_SHELL=$(cat /proc/$CURRENT_PID/cmdline | tr -d '\0')
  
  echo $CURRENT_SHELL
  
  # if the script will be called using bash e.g. 'bash script' and not by running it directly, it will cause the CURRENT_SHELL to contain the script name as well so we need to grep for the word "bash" because it will not always be alone
  echo $CURRENT_SHELL | grep "bash"

  if ! [ "$?" -eq 0 ]; then
      echo "Current running shell is NOT bash."
      
      echo "Re-running the script using bash ..."

      BASH_LOC=$(which bash)
      
      # 'sh' does not know the operator '=='. it uses a single '=' sign instead for comparisons
      if ! [ "$BASH_LOC" = "" ]; then
          $BASH_LOC $0
          
          if [ "$?" -eq 0 ]; then
              STATUS=0
          else
              echo "Unexpected error!"
              
              STATUS=1
          fi
      else
          echo "The 'which' command is not functioning correctly in this image. Trying to find 'bash' manually ..."
          
          if [ -s "/usr/bin/bash" ]; then
              /usr/bin/bash $0

              if [ "$?" -eq 0 ]; then
                  STATUS=0
              else
                  echo "ERROR! Unexpected error!"
                  
                  STATUS=1
              fi              
          else
              if [ -s "/bin/bash" ]; then
                  /bin/bash $0

                  if [ "$?" -eq 0 ]; then
                      STATUS=0
                  else
                      echo "ERROR! Unexpected error!"
                      
                      STATUS=1
                  fi
              else
                  echo "ERROR! Could not find 'bash' in default locations. Cannot continue!"
                  
                  STATUS=1
              fi
          fi
      fi
      
      # exit current shell run
      exit $STATUS
  fi
fi

if [ -s "/etc/debian_version" ]; then
  echo "Detected Debian Linux. Version: `cat /etc/debian_version`"

  echo "Checking if bash is running this script right now ..."

  # sending the output using the expression '&>/dev/null' is causing an odd syntax error when running this command in 'sh' so it will be removed for now ...
  # 2/8/2021 UPDATE: ps is not always available so we will use /proc instead
  #ps | grep -v "grep" | grep $$ | grep "bash" #&>/dev/null
  
  CURRENT_PID=$(echo $$)
  
  # the tr cmd is required here because there is a null byte in the cmdline file which causes an error when trying to put the file content into a variable
  CURRENT_SHELL=$(cat /proc/$CURRENT_PID/cmdline | tr -d '\0')

  # if the script will be called using bash e.g. 'bash script' and not by running it directly, it will cause the CURRENT_SHELL to contain the script name as well so we need to grep for the word "bash" because it will not always be alone
  echo $CURRENT_SHELL | grep "bash"

  if ! [ "$?" -eq 0 ]; then
      echo "Current running shell is NOT bash."
      
      echo "Re-running the script using bash ..."

      BASH_LOC=$(which bash)

      # 'sh' does not know the operator '=='. it uses a single '=' sign instead for comparisons      
      if ! [ "$BASH_LOC" = "" ]; then
          $BASH_LOC $0
          
          if [ "$?" -eq 0 ]; then
              STATUS=0
          else
              echo "Unexpected error!"
              
              STATUS=1
          fi
      else
          echo "The 'which' command is not functioning correctly in this image. Trying to find 'bash' manually ..."
          
          if [ -s "/usr/bin/bash" ]; then
              /usr/bin/bash $0

              if [ "$?" -eq 0 ]; then
                  STATUS=0
              else
                  echo "ERROR! Unexpected error!"
                  
                  STATUS=1
              fi              
          else
              if [ -s "/bin/bash" ]; then
                  /bin/bash $0

                  if [ "$?" -eq 0 ]; then
                      STATUS=0
                  else
                      echo "ERROR! Unexpected error!"
                      
                      STATUS=1
                  fi
              else
                  echo "ERROR! Could not find 'bash' in default locations. Cannot continue!"
                  
                  STATUS=1
              fi
          fi
      fi
      
      # exit current shell run
      exit $STATUS
  fi
fi

if [ -s "/etc/centos-release" ]; then
  echo "Detected CentOS Linux. Version: `cat /etc/centos-release`"

  echo "Checking if bash is running this script right now ..."
  
  # in CentOS, sh is a link to bash ...
  # 2/8/2021 UPDATE: ps is not always available so we will use /proc instead
  #ps | grep -v "grep" | grep $$ | grep "bash\|sh" #&>/dev/null
  
  CURRENT_PID=$(echo $$)
  
  # the tr cmd is required here because there is a null byte in the cmdline file which causes an error when trying to put the file content into a variable
  CURRENT_SHELL=$(cat /proc/$CURRENT_PID/cmdline | tr -d '\0')

  echo $CURRENT_SHELL | grep "bash\|sh"

  if ! [ "$?" -eq 0 ]; then
      echo "Current running shell is NOT bash."
      
      echo "Re-running the script using bash ..."

      BASH_LOC=$(which bash)

      # 'sh' does not know the operator '=='. it uses a single '=' sign instead for comparisons      
      if ! [ "$BASH_LOC" = "" ]; then
          $BASH_LOC $0
          
          if [ "$?" -eq 0 ]; then
              STATUS=0
          else
              echo "Unexpected error!"
              
              STATUS=1
          fi
      else
          echo "The 'which' command is not functioning correctly in this image. Trying to find 'bash' manually ..."
          
          if [ -s "/usr/bin/bash" ]; then
              /usr/bin/bash $0

              if [ "$?" -eq 0 ]; then
                  STATUS=0
              else
                  echo "ERROR! Unexpected error!"
                  
                  STATUS=1
              fi              
          else
              if [ -s "/bin/bash" ]; then
                  /bin/bash $0

                  if [ "$?" -eq 0 ]; then
                      STATUS=0
                  else
                      echo "ERROR! Unexpected error!"
                      
                      STATUS=1
                  fi
              else
                  echo "ERROR! Could not find 'bash' in default locations. Cannot continue!"
                  
                  STATUS=1
              fi
          fi
      fi
      
      # exit current shell run
      exit $STATUS
  fi
fi

if [ -s "/etc/redhat-release" ]; then
  echo "Detected Redhat Linux for Docker (ubi image). Version: `cat /etc/redhat-release`"

  echo "Checking if bash is running this script right now ..."
  
  # in redhat, sh is a link to bash ...
  # 2/8/2021 UPDATE: ps is not always available so we will use /proc instead
  #ps | grep -v "grep" | grep $$ | grep "bash\|sh" #&>/dev/null
  
  CURRENT_PID=$(echo $$)
  
  # the tr cmd is required here because there is a null byte in the cmdline file which causes an error when trying to put the file content into a variable
  CURRENT_SHELL=$(cat /proc/$CURRENT_PID/cmdline | tr -d '\0')

  echo $CURRENT_SHELL | grep "bash\|sh"

  if ! [ "$?" -eq 0 ]; then
      echo "Current running shell is NOT bash"
      
      echo "Re-running the script using bash ..."

      BASH_LOC=$(which bash)
      
      # 'sh' does not know the operator '=='. it uses a single '=' sign instead for comparisons      
      if ! [ "$BASH_LOC" = "" ]; then
          $BASH_LOC $0
          
          if [ "$?" -eq 0 ]; then
              STATUS=0
          else
              echo "Unexpected error!"
              
              STATUS=1
          fi
      else
          echo "The 'which' command is not functioning correctly in this image. Trying to find 'bash' manually ..."
          
          if [ -s "/usr/bin/bash" ]; then
              /usr/bin/bash $0

              if [ "$?" -eq 0 ]; then
                  STATUS=0
              else
                  echo "ERROR! Unexpected error!"
                  
                  STATUS=1
              fi              
          else
              if [ -s "/bin/bash" ]; then
                  /bin/bash $0

                  if [ "$?" -eq 0 ]; then
                      STATUS=0
                  else
                      echo "ERROR! Unexpected error!"
                      
                      STATUS=1
                  fi
              else
                  echo "ERROR! Could not find 'bash' in default locations. Cannot continue!"
                  
                  STATUS=1
              fi
          fi
      fi
      
      # exit current shell run
      exit $STATUS
  fi
fi

##################################################################
# SETTINGS
##################################################################

PROXY_SCRIPT_FILE_NAME=all-v2.29.sh

APT_CONF='/etc/apt.conf'
YUM_CONF='/etc/yum.conf'
PIP_CONF='/etc/pip.conf'
NPMRC='/etc/npmrc'
ENVIRONMENT='/etc/environment'
APT_PROXY_AND_SSL_SETTINGS='/etc/apt/apt.conf.d/apt-proxy-and-ssl-settings'

FILES_TO_APPEND_DATA_TO=('APT_CONF' 'YUM_CONF' 'ENVIRONMENT')
FILES_TO_CREATE_AS_NEW=('PIP_CONF' 'NPMRC' 'APT_PROXY_AND_SSL_SETTINGS')

CERTS_BUNDLE_STORES_TO_UPDATE=('/etc/ssl/cert.pem' '/etc/ssl/certs/ca-bundle.crt' '/usr/lib/python2.7/site-packages/pip/_vendor/certifi/cacert.pem' '/usr/lib/python3.6/site-packages/pip/_vendor/certifi/cacert.pem' '/etc/ssl/cert.pem' '/usr/local/lib/python2.7/dist-packages/certifi/cacert.pem' '/etc/ssl/certs/ca-certificates.crt')
CERTS_FOLDERS_TO_UPDATE=('/usr/local/share/ca-certificates')

# this array will not unset the variables automatically because this can only be done on current running shell. instead this array will generate an unset script in the /tmp folder of the image to be run from an active shell using the cmd 'source'.
ENV_VARS_TO_UNSET=('HTTP_PROXY' 'HTTPS_PROXY' 'NO_PROXY' 'http_proxy' 'https_proxy' 'no_proxy' 'GIT_SSL_NO_VERIFY')

DEFAULT_DISABLED_FILE_SUFFIX='disabled-by-'$(basename $0)


##################################################################
# FUNCTIONS
##################################################################

restoreFile()
{
	# function params:
  # $1 = file to restore
	# $2 = backup file name suffix
	
	DEFAULT_BACKUP_FILE_SUFFIX='backed-up-by-'$PROXY_SCRIPT_FILE_NAME
	
	if ! [ -z "$1" ]; then
		local -n fileToRestore=$1
	fi
	
	if ! [ -z "$2" ]; then
		local -n backupFileSuffix=$2
	fi
	
	if ! [ -z "$fileToRestore" ]; then
		if [ -z "$backupFileSuffix" ]; then
			backupFileSuffix=$DEFAULT_BACKUP_FILE_SUFFIX
		fi
		
		if [ -s "$fileToRestore.$DEFAULT_BACKUP_FILE_SUFFIX" ]; then
			if ! [ -s "$fileToRestore.$DEFAULT_DISABLED_FILE_SUFFIX" ]; then
				mv -v $fileToRestore $fileToRestore.$DEFAULT_DISABLED_FILE_SUFFIX
				mv -v $fileToRestore.$DEFAULT_BACKUP_FILE_SUFFIX $fileToRestore
			fi
		fi	
	fi
}

undoChanges()
{
	# function params:
	# $1 = array of list of bundles to work on
	# $2 = array of list of certs folders to work on
  # $3 = array of files to append
	# $4 = array of files to create
  # $5 = array of env vars to create unset script for
	
	local -n bundlesArr=$1
	local -n appendArr=$2
	local -n createArr=$3
	local -n foldersArr=$4
  local -n unsetEnvVarsArr=$5
	
	CERTS_NAME_PREFIX='added-by-'$PROXY_SCRIPT_FILE_NAME
	
  UNSET_ENV_VARS_SCRIPT_FILE_SPEC='/tmp/unset-env-vars'
  
  # keeping certs for now - hence this loop is commented
  
	#for i in "${bundlesArr[@]}"
	#do
	#	if [ -s "$i" ]; then
	#		restoreFile i
	#	fi
	#done
	
	for i in "${appendArr[@]}"
	do
		FILE=${!i}
		
		if [ -s "$FILE" ]; then
			restoreFile FILE
		fi
	done

	for i in "${createArr[@]}"
	do
		FILE=${!i}
		
		if [ -s "$FILE" ]; then
			if ! [ -s "$FILE.$DEFAULT_DISABLED_FILE_SUFFIX" ]; then
				mv -v $FILE $FILE.$DEFAULT_DISABLED_FILE_SUFFIX
			fi
		fi
	done
	
	if [ "${#foldersArr[@]}" -gt 0 ]; then
		for i in "${foldersArr[@]}"
		do
			if [ -d "$i" ]; then
				cd $i
				pwd
				rm -v $CERTS_NAME_PREFIX*
			fi
		done
		
		if [ -s "/usr/sbin/update-ca-certificates" ]; then
			/usr/sbin/update-ca-certificates --fresh
		fi
	fi
  
  # remove bash if it was cretaed by the script in alpine
  
  if [ -s "/etc/alpine-release" ]; then
    if [ -s "$ALPINE_BASH_BINARY_FILE_SPEC" ]; then
      echo "Detected bash created by the script (Alpine Linux only). Removing it ...."
      
      rm -v $BASH_LIBS_LOCATION/$READLINE_LIB_FILE_NAME
      rm -v $BASH_LIBS_LOCATION/$NCURSE_LIB_FILE_NAME
      rm -v $ALPINE_BASH_BINARY_FILE_SPEC
    fi
	fi
  
  # create unset env vars script
 	if [ "${#unsetEnvVarsArr[@]}" -gt 0 ]; then
		for i in "${unsetEnvVarsArr[@]}"
		do
        echo "unset $i" >> $UNSET_ENV_VARS_SCRIPT_FILE_SPEC
		done
  fi
}

showAllSettings()
{
	# function params:
    	# $1 = array of files to append
	# $2 = array of list of bundles to work on
	# $3 = restored file name suffix
		
	local -n appendArr=$1
	local -n bundlesArr=$2
	
	if [ -z "$3" ]; then
		local -n disabledFileSuffix=DEFAULT_DISABLED_FILE_SUFFIX
	else
		local -n disabledFileSuffix=$3
	fi	
	
	echo "==========================="
	echo "Proxy via Env:"
	echo "==========================="
	echo ""
	echo ""
	
	env | grep proxy
	
	echo "==========================="
	echo "Other files:"
	echo "==========================="
	echo ""
	echo ""
	
	for i in "${appendArr[@]}"
	do
		FILE=${!i}
		
		if [ -s "$FILE" ]; then	
			echo "==========================="
			echo "$FILE:"
			echo "==========================="
			cat $FILE
			echo ""
			echo ""			
		fi
	done
	
	for i in "${bundlesArr[@]}"
	do
		if [ -s "$i" ]; then
			if [ -s "$i.$disabledFileSuffix" ]; then
				echo "==========================="
				echo "$i:"
				echo "==========================="
				ls -l $i
				ls -l $i.$disabledFileSuffix
				echo ""
				echo ""				
			fi
		fi
	done
}

##################################################################
# MAIN PROGRAM
##################################################################

undoChanges CERTS_BUNDLE_STORES_TO_UPDATE FILES_TO_APPEND_DATA_TO FILES_TO_CREATE_AS_NEW CERTS_FOLDERS_TO_UPDATE ENV_VARS_TO_UNSET

showAllSettings FILES_TO_APPEND_DATA_TO CERTS_BUNDLE_STORES_TO_UPDATE
