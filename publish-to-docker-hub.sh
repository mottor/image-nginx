#!/bin/bash
CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_NAME="mottor1/nginx"

OFFICIAL_VERSIONS=$(cat OFFICIAL_VERSIONS.md | head -n 1)
VERSION=$(cat VERSION.md | head -n 1)

docker login ## Enter login and pass

input="$CUR_DIR/OFFICIAL_VERSIONS.md"
while IFS= read -r official_version
do
  echo " "
  echo "---------------"
  echo "Building $IMAGE_NAME:$official_version"
  docker build --build-arg NGINX_VERSION="$official_version" --tag "$IMAGE_NAME:$official_version" .

  echo " "
  echo "---------------"
  echo "Pushing $IMAGE_NAME:$official_version"
  docker push "$IMAGE_NAME:$official_version"
done < "$input"

echo " "
echo "✅ DONE"
echo " "
