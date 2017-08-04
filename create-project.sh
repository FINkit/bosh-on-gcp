#!/bin/bash

usage ()
{
    cat << EOF
Usage: $0 options

OPTIONS:
    -p: GCP Project
EOF
}

fail_on_error() {
    if [[ ${1} != 0 ]]; then
        echo "Exiting due to an error"
        exit 1
    fi
}

while getopts "p:f" OPTION
do
    case ${OPTION} in
        p)
            GCP_PROJECT=${OPTARG}
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done

if [ -z ${GCP_PROJECT} ]
then
    usage
    exit 1
fi

source ./properties/gcp.properties

if [[ $( gcloud alpha projects list | grep -c "${GCP_PROJECT}") -eq 0 ]]
then
    gcloud alpha projects create ${GCP_PROJECT} --name=${GCP_PROJECT} --set-as-default
    fail_on_error $?
else
    echo "It seems that ${GCP_PROJECT} has already been setup on GCP"
fi

if [[ $(gcloud alpha billing accounts projects describe ${GCP_PROJECT} 2>/dev/null | grep -c "billingEnabled: true") -eq 0 ]]
then
    billing_account=$(gcloud alpha billing accounts list --format json | jq -r '.[].name')
    gcloud alpha billing accounts projects link ${GCP_PROJECT} --billing-account=${billing_account#billingAccounts/}
    fail_on_error $?
else
    echo "It seems that ${GCP_PROJECT} has already been linked to a billing account"
fi

for api_to_enable in "${GCP_APIS_TO_ENABLE[@]}"
do
    if [[ $(gcloud beta --project ${GCP_PROJECT} service-management list --enabled | grep -c "${api_to_enable}") -eq 0 ]]
    then
        gcloud beta --project ${GCP_PROJECT} service-management enable ${api_to_enable}
        fail_on_error $?
    else
        echo "${api_to_enable} already seems to be enabled on this project: ${GCP_PROJECT}"
    fi
done

if [[ $(gcloud iam --project ${GCP_PROJECT} service-accounts list | grep -c "${GCP_SERVICE_ACCOUNT}") -eq 0 ]]
then
    gcloud iam --project ${GCP_PROJECT} service-accounts create "${GCP_SERVICE_ACCOUNT}" --display-name="${GCP_SERVICE_ACCOUNT}"
    fail_on_error $?
else
    echo "${GCP_SERVICE_ACCOUNT} service account already created for project: ${GCP_PROJECT}"
fi

if [[ $(gcloud iam --project ${GCP_PROJECT} service-accounts keys list --iam-account="${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT}.iam.gserviceaccount.com" | wc -l) -eq 0 ]]
then
    gcloud iam --project ${GCP_PROJECT} service-accounts keys create --iam-account="${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT}.iam.gserviceaccount.com" ${GCP_SERVICE_ACCOUNT}.key.json
    fail_on_error $?
else
    if [ ! -f ${GCP_SERVICE_ACCOUNT}.key.json ]
    then
        gcloud iam --project ${GCP_PROJECT} service-accounts keys create --iam-account="${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT}.iam.gserviceaccount.com" ${GCP_SERVICE_ACCOUNT}.key.json
        fail_on_error $?
    fi
fi

gcloud projects add-iam-policy-binding ${GCP_PROJECT} --member="serviceAccount:${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT}.iam.gserviceaccount.com" --role='roles/owner'
fail_on_error $?
