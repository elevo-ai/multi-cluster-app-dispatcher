#!/bin/bash

mcad_image=mcad-controller
mcad_imagetag=main-v1.38.1
aizen_release=0.0.1
if [[ -z ${AIZENREPO} ]]; then
   aizen_repo=172.16.26.41:5000
else
   aizen_repo=$AIZENREPO
fi
#Cleanup the image
make clean
echo "$(docker images -q $mcad_image:$mcad_imagetag 2> /dev/null)"
if [[ ! -z "$(docker images -q $mcad_image:$mcad_imagetag 2> /dev/null)" ]]; then
   echo "docker image rm $mcad_image:$mcad_imagetag $aizen_repo/foresight-mcad-controller:$aizen_release"
   docker image rm $mcad_image:$mcad_imagetag $aizen_repo/foresight-mcad-controller:$aizen_release
   echo "docker image rm $(docker images -q $mcad_image:$mcad_imagetag)"
   docker image rm $(docker images -q $mcad_image:$mcad_imagetag)
fi
exit 0
make mcad-controller
if [[ -e  _output/bin/"mcad_controller" ]]; then
   make images
   if [ ! -z "$(docker images -q $mcad_image:$mcad_imagetag 2> /dev/null)" ]; then
    docker tag $mcad_image:$mcad_imagetag $aizen_repo/foresight-mcad-controller:$aizen_release
    echo -e "\nSuccessfully pushed image $aizen_repo/foresight-mcad-controller:$aizen_release\n"
    exit 0
   fi
else
   echo -e "\nBuild failed\n"
   exit 1
fi
