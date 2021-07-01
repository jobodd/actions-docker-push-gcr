#!/bin/bash

function split_csv() {
    IFS=','
    csv_data=$1
    local -n global_list_array=$2
    for i in $csv_data; do
        global_list_array+=($i)
    done
    unset IFS
}

ALL_IMAGE_TAG=()
ALL_IMAGE_TAG+=($(git rev-parse --short HEAD))

if [$INPUT_PUSH == "yes"] ; then
    echo "Authenticating docker to gcloud ..."
    if ! echo $INPUT_GCLOUD_SERVICE_KEY | base64 -d >/tmp/key.json 2>/dev/null; then
        echo "Failed to decode gcloud_service_key"
        exit 1
    fi

    if cat /tmp/key.json | docker login -u _json_key --password-stdin https://$INPUT_REGISTRY; then
        echo "Logged in to google cloud ..."
    else
        echo "Docker login failed. Exiting ..."
        exit 1
    fi
fi

split_csv $INPUT_IMAGE_TAG ALL_IMAGE_TAG


TEMP_IMAGE_NAME="$INPUT_IMAGE_NAME:temporary"

echo "Building image ..."

[ -z $INPUT_TARGET ] && TARGET_ARG="" || TARGET_ARG="--target $INPUT_TARGET"

[ -z $INPUT_DOCKERFILE ] && FILE_ARG="" || FILE_ARG="--file $INPUT_DOCKERFILE"


if [ ! -z "$INPUT_BUILD_ARGS" ]; then
  for ARG in $(echo "$INPUT_BUILD_ARGS" | tr ',' '\n'); do
    BUILD_PARAMS="$BUILD_PARAMS --build-arg ${ARG}"
  done
fi

echo "docker build $BUILD_PARAMS $TARGET_ARG -t $TEMP_IMAGE_NAME $FILE_ARG $INPUT_CONTEXT"


if docker build $BUILD_PARAMS $TARGET_ARG -t $TEMP_IMAGE_NAME $FILE_ARG $INPUT_CONTEXT; then
    echo "Image built ..."
else
    echo "Image building failed. Exiting ..."
    exit 1
fi

for IMAGE_TAG in ${ALL_IMAGE_TAG[@]}; do

    IMAGE_NAME="$INPUT_REGISTRY/$INPUT_PROJECT_ID/$INPUT_IMAGE_NAME:$IMAGE_TAG"

    echo "Fully qualified image name: $IMAGE_NAME"

    echo "Creating docker tag ..."

    docker tag $TEMP_IMAGE_NAME $IMAGE_NAME
    if [$INPUT_PUSH == "yes"] ; then
        echo "Pushing image $IMAGE_NAME ..."

        if ! docker push $IMAGE_NAME; then
            echo "Pushing failed. Exiting ..."
            exit 1
        else
            echo "Image pushed."
        fi
    fi
done

echo "Process complete."