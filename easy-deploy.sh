#!/bin/bash

shopt -s expand_aliases

DEFAULT_DOCKER_REPO_URL='my.repository.local:4444/security/general'
DEFAULT_NAMESPACE='test-ohad'
DEFAULT_SA='sa-test-ohad'
DEFAULT_IMAGE_PULL_SECRET_NAME='ohad-reg-secret'

SERVICE_ACCOUNT=$DEFAULT_SA
IMAGE_PULL_SECRET_NAME=$DEFAULT_IMAGE_PULL_SECRET_NAME

DEV_ENV_DOCKER_REPO_URL='dev.docker.repo:1111/security/general'
TEST_ENV_DOCKER_REPO_URL='test.docker.repo:2222/security/general'
PROD_ENV_DOCKER_REPO_URL='prod.docker.repo:3333/security/general'

source funcs-bashrc.sh #&>/dev/null

getns &>/dev/null

STATUS=$?

CURRENT_NS=$(getns | awk -F= '{print $2}')

if [ "$CURRENT_NS" == "" ]; then
	NAMESPACE=$DEFAULT_NAMESPACE
else
	NAMESPACE=$CURRENT_NS
fi

if [ "$1" == "" ]; then
	echo "ERROR! Wrong usage."
	echo
	
	echo "Usage 1: $0 print"
	echo "Print all repos available."
	echo
	
	echo "Usage 2: $0 <image-to-deploy-with-tag> [Optional: <namespace> <serviceAccount> <pullSecretName>]"
	echo "Deploy a new image to K8s."
	echo
	echo "Extra notes:"
	echo "1) If chosen to use a specific namespace, you must also supply the other optional parameters."
	echo "2) The 1st param 'image-to-deploy-with-tag' can be with or without a full docker registry repo location (url and sub folders)."
	echo "If only image name and tag are given, will use the current default repo url set in the script which is: '$DEFAULT_DOCKER_REPO_URL'."
	echo
	
	if [ "$STATUS" -eq 0 ]; then
		echo "Hints:"
		echo
		echo "Your current ns is (may be empty):"
		echo "$CURRENT_NS"
		echo
		echo "Your service accounts in current ns are:"
		echo
		
		sa -n $NAMESPACE
		
		echo
		echo "Your secrets in current ns are:"
		echo

		s -n $NAMESPACE

		echo
		echo
	fi
else
	if [ "$1" == "print" ]; then
		echo "Current available repos:"
		echo
		echo "DEV Repo: $DEV_ENV_DOCKER_REPO_URL"
		echo "TEST Repo: $TEST_ENV_DOCKER_REPO_URL"
		echo "PROD Repo: $PROD_ENV_DOCKER_REPO_URL"
	else
		IMAGE=$1
		
		# if slashes were found, assume we want to input a full repo path and don't add the repo url to the image
		echo $IMAGE | grep -q "/"
		
		if ! [ "$?" -eq 0 ]; then
			IMAGE=$DEFAULT_DOCKER_REPO_URL/$1
		fi
		
		if ! [ "$2" == "" ]; then
			if [ "$3" == "" -o "$4" == "" ]; then
				echo "ERROR! you must supply ALL optional parameters."
				echo "Aborting ..."
				
				exit 1
			else
				NAMESPACE=$2
				SERVICE_ACCOUNT=$3
				IMAGE_PULL_SECRET_NAME=$4
			fi
		fi
		
		ONLY_IMAGE_NAME_AND_TAG=$(echo $IMAGE | rev | awk -F/ '{print $1}' | awk -F: '{print $1"-"$2}' | rev)
		
		YAML_BASIC_POD_NAME='easy-deploy'
		RANDOM_POD_NAME="$YAML_BASIC_POD_NAME-$(env LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 6)--$ONLY_IMAGE_NAME_AND_TAG"
		
		COMMAND='[ "sh", "-c", "--" ]'
		ARGS='[ "while true; do sleep 30; done;" ]'
		
		overrides=$(
		  cat <<EOT
			{
			  "spec": {
			    "serviceAccount": "$SERVICE_ACCOUNT",
			    "imagePullSecrets": [{"name": "$IMAGE_PULL_SECRET_NAME"}],
			    "containers": [
			      {
				"securityContext": {
				  "privileged": true
				},
				"image": "$IMAGE",
				"name": "$RANDOM_POD_NAME",
				"command": $COMMAND,
				"args": $ARGS
			      }
			    ],
			    "tolerations": [
			      {
				"key": "CriticalAddonsOnly",
				"operator": "Exists"
			      },
			      {
				"effect": "NoExecute",
				"operator": "Exists"
			      }
			    ]
			  }
			}
EOT
)
# the above too lines must be at the begining of the line

		echo "Trying to deploy a new pod named '$RANDOM_POD_NAME' with an image named '$IMAGE' into namespace '$NAMESPACE' ..."
		echo "(using: serviceAccount named '$SERVICE_ACCOUNT' , imagePullSecret named '$IMAGE_PULL_SECRET_NAME')"
		
		echo "DEBUG: the command is: 'kubectl -n $NAMESPACE run \"$RANDOM_POD_NAME\" --image \"$IMAGE\" --restart=Never --overrides=\"see-in-script\"'"
		
		#kubectl -n $NAMESPACE run "$RANDOM_POD_NAME" --image "$IMAGE" --restart=Never --overrides="$overrides" -i --command -- sh
		
		kubectl -n $NAMESPACE run "$RANDOM_POD_NAME" --image "$IMAGE" --restart=Never --overrides="$overrides"
		
		sleep 5
		
		p -n $NAMESPACE
	fi	
fi
	


