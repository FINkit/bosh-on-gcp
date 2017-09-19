module "bosh-haraka" {
    source      = "github.com/migs/bosh-haraka//terraform"
    projectid   = "${var.projectid}"
    prefix      = "${var.prefix}"
    network     = "${google_compute_network.bosh.name}"
}
