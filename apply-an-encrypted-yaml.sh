#!/bin/bash

PRIVATE_KEY_REMOTE_REPO_BASE_URL='https://my.repository.local'

DEV_ENV_DOCKER_REPO_URL='dev.docker.repo:1111'
TEST_ENV_DOCKER_REPO_URL='test.docker.repo:2222'
PROD_ENV_DOCKER_REPO_URL='prod.docker.repo:3333'


# params:
# $1 = yaml file to work on
# $2 = private key file
# $3 = key pass phrase
# $4 = environment

if [ "$1" == "" -o "$2" == "" -o "$3" == "" -o "$4" == "" ]; then
	echo "ERROR! Wrong usage."
	echo "Usage: $0 <encrypted-yaml-file-to-work-on> <private-key-file> <key-pass-phrase> <environment>"
	echo "'environment' is one of: 'dev', 'test' or 'prod'."
else
	if ! [ -s "$1" ]; then
		echo "ERROR! file '$1' must be a valid non-empty file. Please try again ..."
		echo "Aborting ..."
	else	
		if ! [ -s "$2" ]; then
			echo "ERROR! file '$2' must be a valid non-empty private key file. Please try again ..."
			echo "Aborting ..."
		else
			read -p "Please enter valid creds for the remote repository '$PRIVATE_KEY_REMOTE_REPO_BASE_URL' in a CURL format user:password: " CREDS

			YAML_FILE_NAME=$(basename $1)
			
			YAML_FILE_DIR=$(dirname $1)

			cd $YAML_FILE_DIR

			case $4 in
				'dev')
					ENV=$DEV_ENV_DOCKER_REPO_URL
				;;
				'test')
					ENV=$TEST_ENV_DOCKER_REPO_URL
				;;
				'prod')
					ENV=$PROD_ENV_DOCKER_REPO_URL
				;;
				*)
					ENV=$DEV_ENV_DOCKER_REPO_URL
				;;
			esac
			
			echo "Trying to decrypt the file '$1' using the private key '$2' ..."

			openssl smime -decrypt -in $YAML_FILE_NAME -inform PEM -out decrypted-$YAML_FILE_NAME -inkey $2 -passin pass:$3

			if [ "$?" -eq 0 ]; then
				echo "Decryption succeeded."
				
				if [ -s "decrypted-$YAML_FILE_NAME" ]; then
					DECRYPTED_YAML_FILE_NAME="decrypted-$YAML_FILE_NAME"

					echo "Decrypted file was saved as '$DECRYPTED_YAML_FILE_NAME'."

					echo "Updating images locations according to the given environment parameter ..."				
					
					# the -s in tr means "replace only once". default behaviour is to replace the same number of chars even if the 2nd param refers to only one (it will be repeated).
					# the xargs at the end is important and used to trim spaces before and after the values otherwise the sed cmd will fail
					IMAGES_LINES=$(cat $DECRYPTED_YAML_FILE_NAME | awk -F"image:" '{print $2}' | tr -s "\r\n" " " | xargs)

					echo "DEBUG: images param value: '$IMAGES_LINES'"

					if ! [ "$IMAGES_LINES" == "" ]; then
						for IMAGE_LINE in $IMAGES_LINES
						do
							REQ_CONTENT=$(echo $IMAGE_LINE | awk -F/ 'req="";{for(i=1;i<=NF;i++){if(i>=2) req=req"/"$i}; print req}')
							
							# sed's separator was changed so that sed will not try to parse any "/" chars in the processed urls.

							echo "DEBUG: Running the cmd 'sed -i "s#$IMAGES_LINES#$ENV$REQ_CONTENT#" $DECRYPTED_YAML_FILE_NAME' ..."
							sed -i "s#$IMAGES_LINES#$ENV$REQ_CONTENT#" $DECRYPTED_YAML_FILE_NAME
						done
					fi
					
					if ! [ "$CREDS" == "" ]; then
						echo "Attempting to find the private key in the remote repository ..."
					
						PRIVATE_KEY_FILE_NAME=$(basename $2)

						PRIVATE_KEY_FILE_ID=$(curl -u $CREDS -X GET "$PRIVATE_KEY_REMOTE_REPO_BASE_URL/service/rest/v1/search/assets?name=*$PRIVATE_KEY_FILE_NAME" -H "accept: application/json" | jq '.items[].id')

						if ! [ "$PRIVATE_KEY_FILE_ID" == "" ]; then
							echo "Found it."
							echo "Trying to remove it ..."
						
							curl -u $CREDS -X DELETE "$PRIVATE_KEY_REMOTE_REPO_BASE_URL/service/rest/v1/assets/${PRIVATE_KEY_FILE_ID}" -H "accept: application/json"

							if [ "$?" -eq 0 ]; then
								echo "Removal succeeded."
							else
								echo "ERROR! Something went wrong while trying to remove the file. Please verify its name and your creds and try again."
							fi
						fi
					else
						echo "WARNING: creds were not supplied. The private key file will not be removed from the remote repo."
					fi

					#echo "Applying the yaml file '$DECRYPTED_YAML_FILENAME'"				

					#kubectl apply -f $DECRYPTED_YAML_FILE_NAME
				else
					echo "ERROR! Could not find / create the decrypted file '$DECRYPTED_YAML_FILE_NAME'."
					echo "Aborting ..."
				fi
			else
				echo "ERROR! Something went wrong while trying to decrypt the file '$1'."
				echo "Please make sure the provided files and info are correct and try again."
				echo "Aborting ..."
			fi
		fi
	fi
	
fi




