# BOSH on GCP with Terraform

## Create a BOSH Environment using terraform
Create a BOSH Environment within GCP using the `build-bosh-resources.sh` script:
```
$ ./build-bosh-resources.sh -p <GCP_PROJECT>
```

This script will plan and execute the Terraform recipe `bosh-resources/main.tf` which creates the BOSH environment
(including the *network*, *firewall rules*, a *bosh-bastion vm* and a *nat instance vm*). The recipe also clones the
[bosh-deployment](https://github.com/cloudfoundry/bosh-deployment) repo and creates scripts
on the *bosh-bastion* to create and manage a BOSH Director:
* `create-bosh-director.sh`
* `destroy-bosh-director.sh`

## Create a BOSH Director
Login to the bosh-bastion:
```
$ gcloud compute ssh bosh-bastion
```
and execute the `create-bosh-director.sh` script:
```
$. ./create-bosh-director.sh
```

## Destroy a BOSH Director
Login to the bosh-bastion:
```
$ gcloud compute ssh bosh-bastion
```
and execute the `destroy-bosh-director.sh` script:
```
$. ./destroy-bosh-director.sh
```

## Destroy BOSH Environment within GCP using the `destroy-bosh-resources` script
```
$ ./destroy-bosh-resources.sh -p <GCP_PROJECT>
```
