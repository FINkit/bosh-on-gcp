#/bin/bash -e

GCP_PROJECT=$1
if  [ "${GCP_PROJECT}" == "" ]; then
    echo "./destroy-bosh-resources.sh <GCP_PROJECT>"
    exit 1
fi

source ../properties/gcp.properties

if [[ $( gcloud alpha projects list | grep -c "${GCP_PROJECT}") -gt 0 ]]
then
    bbl destroy
else
    echo "${GCP_PROJECT} project not found!"
fi
