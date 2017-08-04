#/bin/bash -e

GCP_PROJECT=$1
if  [ "${GCP_PROJECT}" == "" ]; then
    echo "./build-bosh-resources.sh <GCP_PROJECT>"
    exit 1
fi

source ../properties/gcp.properties

if [[ $( gcloud alpha projects list | grep -c "${GCP_PROJECT}") -gt 0 ]]
then
    bbl up --gcp-zone ${GCP_ZONE} --gcp-region ${GCP_REGION} --gcp-service-account-key ../${GCP_SERVICE_ACCOUNT}.key.json --gcp-project-id ${GCP_PROJECT} --iaas gcp --no-director

    git clone https://github.com/cloudfoundry/bosh-deployment.git deploy

    bosh create-env deploy/bosh.yml  \
        --state ./state.json  \
        -o deploy/gcp/cpi.yml  \
        -o deploy/external-ip-not-recommended.yml \
        --vars-store ./creds.yml  \
        -l <(bbl bosh-deployment-vars)
else
    echo "Please create and setup your GCP Project - ${GCP_PROJECT} using: ./bbl-setup.sh ${GCP_PROJECT}"
fi
