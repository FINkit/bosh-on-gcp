// Easier mainteance for updating GCE image string
variable "latest_ubuntu" {
    type = "string"
    default = "ubuntu-1404-trusty-v20170718"
}

variable "projectid" {
    type = "string"
}

variable "region" {
    type = "string"
    default = "europe-west2"
}

variable "zone" {
    type = "string"
    default = "europe-west2-a"
}

variable "prefix" {
    type = "string"
    default = ""
}

variable "service_account_email" {
    type = "string"
    default = ""
}

variable "baseip" {
    type = "string"
    default = "10.0.0.0"
}

variable "bosh_cli_version" {
    type = "string"
    default = "2.0.16"
}

provider "google" {
    project = "${var.projectid}"
    region = "${var.region}"
}

resource "google_compute_network" "bosh" {
  name       = "${var.prefix}bosh"
}

resource "google_compute_route" "nat-primary" {
  name        = "${var.prefix}nat-primary"
  dest_range  = "0.0.0.0/0"
  network       = "${google_compute_network.bosh.name}"
  next_hop_instance = "${google_compute_instance.nat-instance-private-with-nat-primary.name}"
  next_hop_instance_zone = "${var.zone}"
  priority    = 800
  tags = ["no-ip"]
}

// Subnet for the BOSH director
resource "google_compute_subnetwork" "bosh-subnet-1" {
  name          = "${var.prefix}bosh-${var.region}"
  ip_cidr_range = "${var.baseip}/24"
  network       = "${google_compute_network.bosh.self_link}"
}

// Subnet for the BuildStack
resource "google_compute_subnetwork" "buildstack-subnet" {
  name          = "${var.prefix}buildstack-${var.region}"
  ip_cidr_range = "10.40.0.0/24"
  network       = "${google_compute_network.bosh.self_link}"
}

// Allow SSH to BOSH bastion
resource "google_compute_firewall" "bosh-bastion" {
  name    = "${var.prefix}bosh-bastion"
  network = "${google_compute_network.bosh.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["bosh-bastion"]
}

// Allow all traffic within subnet
resource "google_compute_firewall" "bosh-intra-subnet-open" {
  name    = "${var.prefix}bosh-intra-subnet-open"
  network = "${google_compute_network.bosh.name}"

  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  source_tags = ["internal"]
}

// BOSH bastion host
resource "google_compute_instance" "bosh-bastion" {
  name         = "${var.prefix}bosh-bastion"
  machine_type = "f1-micro"
  zone         = "${var.zone}"

  tags = ["bosh-bastion", "internal"]

  disk {
    image = "${var.latest_ubuntu}"
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.bosh-subnet-1.name}"
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<EOT
#!/bin/bash
cat > /etc/motd <<EOF




#    #     ##     #####    #    #   #   #    #    ####
#    #    #  #    #    #   ##   #   #   ##   #   #    #
#    #   #    #   #    #   # #  #   #   # #  #   #
# ## #   ######   #####    #  # #   #   #  # #   #  ###
##  ##   #    #   #   #    #   ##   #   #   ##   #    #
#    #   #    #   #    #   #    #   #   #    #    ####

Startup scripts have not finished running, and the tools you need
are not ready yet. Please log out and log back in again in a few moments.
This warning will not appear when the system is ready.
EOF

apt-get update
apt-get install -y git tree jq build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev sqlite3 unzip

# install bosh2
curl -O https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${var.bosh_cli_version}-linux-amd64
chmod +x bosh-cli-*
sudo mv bosh-cli-* /usr/local/bin/bosh

cat > /etc/profile.d/bosh.sh <<'EOF'
#!/bin/bash
# Misc vars
export prefix=${var.prefix}
export ssh_key_path=$HOME/.ssh/bosh

# Vars from Terraform
export subnetwork=${google_compute_subnetwork.bosh-subnet-1.name}
export network=${google_compute_network.bosh.name}


# Vars from metadata service
export project_id=$$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)
export zone=$$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)
export zone=$${zone##*/}
export region=$${zone%-*}

# Configure gcloud
gcloud config set compute/zone $${zone}
gcloud config set compute/region $${region}

if [[ ! -d bosh-deployment ]]; then
    git clone https://github.com/cloudfoundry/bosh-deployment
fi

bosh -v

sudo cat > create-bosh-director.sh << 'EOI'
#!/bin/bash -e

export service_account=bosh-user
export base_ip=10.0.0.0
export project_id=$(gcloud config list 2>/dev/null | grep project | sed -e 's/project = //g')
export service_account_email=$${service_account}@$${project_id}.iam.gserviceaccount.com

if [[ ! $(gcloud iam service-accounts list | grep $${service_account}) ]]; then
	gcloud iam service-accounts create $${service_account}
fi

if [[ ! -f ~/.ssh/bosh ]]; then
	gcloud projects add-iam-policy-binding $${project_id} \
    	  	--member serviceAccount:$${service_account_email} \
        	--role roles/compute.instanceAdmin
	gcloud projects add-iam-policy-binding $${project_id} \
      		--member serviceAccount:$${service_account_email} \
        	--role roles/compute.storageAdmin
	gcloud projects add-iam-policy-binding $${project_id} \
      		--member serviceAccount:$${service_account_email} \
        	--role roles/storage.admin
	gcloud projects add-iam-policy-binding $${project_id} \
      		--member serviceAccount:$${service_account_email} \
        	--role  roles/compute.networkAdmin
	gcloud projects add-iam-policy-binding $${project_id} \
      		--member serviceAccount:$${service_account_email} \
        	--role roles/iam.serviceAccountActor

    ssh-keygen -t rsa -f ~/.ssh/bosh -C bosh
    gcloud compute project-info add-metadata --metadata-from-file \
            sshKeys=<( gcloud compute project-info describe --format=json | jq -r '.commonInstanceMetadata.items[] | select(.key ==  "sshKeys") | .value' & echo "bosh:$(cat ~/.ssh/bosh.pub)" )
fi

if [ ! -f $${service_account_email}.key.json ]; then
    gcloud iam service-accounts keys create $${service_account_email}.key.json \
            --iam-account $${service_account_email}
fi

echo "==================================================================="
bosh int ~/bosh-deployment/bosh.yml \
    --vars-store=~/creds.yml \
    -o ~/bosh-deployment/gcp/cpi.yml \
    -v director_name=gcpbosh \
    -v internal_cidr=10.0.0.0/24 \
    -v internal_gw=10.0.0.1 \
    -v internal_ip=10.0.0.6 \
    --var-file gcp_credentials_json=~/$${service_account_email}.key.json \
    -v project_id=$${project_id} \
    -v zone=$${zone} \
    -v tags=[internal,no-ip] \
    -v network=bosh \
    -v subnetwork=bosh-$${region}
echo "==================================================================="

bosh create-env ~/bosh-deployment/bosh.yml \
    --state=~/director-state.json \
    --vars-store=~/creds.yml \
    -o ~/bosh-deployment/gcp/cpi.yml \
    -v director_name=gcpbosh \
    -v internal_cidr=10.0.0.0/24 \
    -v internal_gw=10.0.0.1 \
    -v internal_ip=10.0.0.6 \
    --var-file gcp_credentials_json=~/$${service_account_email}.key.json \
    -v project_id=$${project_id} \
    -v zone=$${zone} \
    -v tags=[internal,no-ip] \
    -v network=bosh \
    -v subnetwork=bosh-$${region}

bosh alias-env bosh-director -e 10.0.0.6 --ca-cert <(bosh int ./creds.yml --path /director_ssl/ca)
cat >> ~/.profile << 'EOP'

export BOSH_ENVIRONMENT=bosh-director
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int ./creds.yml --path /admin_password`
EOP

source ~/.profile
bosh login

EOI

cat > destroy-bosh-director.sh << 'EOI'
#!/bin/bash -e

echo "Creating Service Account"
export service_account=bosh-user
export project_id=$(gcloud config list 2>/dev/null | grep project | sed -e 's/project = //g')
export service_account_email=$${service_account}@$${project_id}.iam.gserviceaccount.com

bosh delete-env ~/bosh-deployment/bosh.yml \
    --state=~/director-state.json \
    --vars-store=~/creds.yml \
    -o ~/bosh-deployment/gcp/cpi.yml \
    -v director_name=gcpbosh \
    -v internal_cidr=10.0.0.0/24 \
    -v internal_gw=10.0.0.1 \
    -v internal_ip=10.0.0.6 \
    --var-file gcp_credentials_json=$${service_account_email}.key.json \
    -v project_id=$${project_id} \
    -v zone=$${zone} \
    -v tags=[internal] \
    -v network=bosh \
    -v subnetwork=bosh-$${region}
EOI

chmod 755 create-bosh-director.sh
chmod 755 destroy-bosh-director.sh
EOF


rm /etc/motd
EOT

  service_account {
    email = "${var.service_account_email}"
    scopes = ["cloud-platform"]
  }
}

// NAT server (primary)
resource "google_compute_instance" "nat-instance-private-with-nat-primary" {
  name         = "${var.prefix}nat-instance-primary"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"

  tags = ["nat", "internal"]

  disk {
    image = "${var.latest_ubuntu}"
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.bosh-subnet-1.name}"
    access_config {
      // Ephemeral IP
    }
  }

  can_ip_forward = true

  metadata_startup_script = <<EOT
#!/bin/bash
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
EOT
}
