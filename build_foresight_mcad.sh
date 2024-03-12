#!/bin/bash

mcad_image=mcad-controller
mcad_imagetag=0.0.1
if [[ -z ${AIZENREPO} ]]; then
   aizen_repo=172.16.26.41:5000
else
   aizen_repo=$AIZENREPO
fi
#Cleanup the image
echo "$(docker images -q $mcad_image:$mcad_imagetag 2> /dev/null)"
if [[ ! -z "$(docker images -q $mcad_image:$mcad_imagetag 2> /dev/null)" ]]; then
   docker image rm $aizen_repo/foresight-mcad-controller:$mcad_imagetag
   docker image rm $mcad_image:$mcad_imagetag
fi
make mcad-controller
if [[ -e  _output/bin/"mcad-controller" ]]; then
   echo -e "\n**** Proceeding to build mcad images *****\n"
   make images
   if [ ! -z "$(docker images -q $mcad_image:$mcad_imagetag 2> /dev/null)" ]; then
    docker tag $mcad_image:$mcad_imagetag $aizen_repo/foresight-mcad-controller:$mcad_imagetag
    docker push $aizen_repo/foresight-mcad-controller:$mcad_imagetag
    echo -e "\nSuccessfully pushed image $aizen_repo/foresight-mcad-controller:$mcad_imagetag\n"
    docker image rm $aizen_repo/foresight-mcad-controller:$mcad_imagetag
    docker image rm $mcad_image:$mcad_imagetag
    exit 0
   fi
else
   echo -e "\nBuild failed\n"
   exit 1
fi
