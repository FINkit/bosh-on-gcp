# BOSH on GCP

## Pre-requisites
Ensure you have the [Google Cloud SDK](https://cloud.google.com/sdk/downloads) installed, along with the following
components, at these minimum versions:
```
$ gcloud version
Google Cloud SDK 164.0.0
alpha 2017.07.25
beta 2017.07.25
bq 2.0.24
core 2017.07.25
gcloud
gsutil 4.27
```

Ensure that you've initiated your Google Cloud session using:
```
$ gcloud init
```

## Create a GCP Project
It's advised that a new GCP Project is created using the `create-project.sh` script:
```
$ ./create-project.sh -p <GCP_PROJECT>
```

Once you've created a GCP Project (or you're re-using an existing one created for BOSH purposes) you should move onto
your chosen mechanism for creating a BOSH Director:
* [bosh-bootloader](https://github.com/cloudfoundry/bosh-bootloader) (refer to the `bbl/README.md`)
* [Terraform](https://www.terraform.io/) (refer to the `terraform/README.md` - *recommended*)
