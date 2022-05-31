#!/bin/bash

IMAGES_LIST_FILESPEC='images.txt'

# destination location ...
NEW_TAGS_PREFIX='my.repository.local'

if [ -s "$IMAGES_LIST_FILESPEC" ]; then

	IMAGES=$(cat $IMAGES_LIST_FILESPEC)

	for i in $IMAGES; do
		echo "Currently working on image '$i' ..."

		echo "Trying to pull ..."
		docker pull $i
		
		if ! [ "$?" == 0 ]; then
			echo "ERROR! Couldn't pull the image '$i'! Maybe you forgot to login?"
			echo "Aborting ..."
			exit 1
		fi

		echo "Pull done. Re-tagging ..."

		IMAGE_NAME_AND_TAG_ONLY=$(echo $i | rev | awk -F/ '{ print $1 }' | rev)
		
		NEW_IMAGE_FULL_PATH=$NEW_TAGS_PREFIX$IMAGE_NAME_AND_TAG_ONLY
		docker tag $i $NEW_IMAGE_FULL_PATH
		
		echo "Pushing the new image to the repo ..."
		docker push $NEW_IMAGE_FULL_PATH

		if ! [ "$?" == 0 ]; then
                        echo "ERROR! Couldn't push the image '$NEW_IMAGE_FULL_PATH'! Maybe you forgot to login to Nexus?"
			echo "Aborting ..."
                        exit 1
                fi
	done
else
	echo "ERROR! file '$IMAGES_LIST_FILESPEC' does not exist!"
fi



