provider "hcloud" {
  token   = var.hcloud_token
}

# Private Network and subnets
resource "hcloud_network" "default" {
  name     = "kubernetes"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "master" {
  network_id   = hcloud_network.default.id
  type         = "server"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_network_subnet" "worker" {
  network_id   = hcloud_network.default.id
  type         = "server"
  network_zone = "eu-central"
  ip_range     = "10.0.2.0/24"
}

resource "hcloud_server" "master" {
  count       = 1
  name        = "master.${var.domain}"
  image       = "ubuntu-18.04"
  server_type = var.master_servertype
  location    = var.datacenter
  user_data   = file("./user-data/cloud-config.yaml")
}

resource "hcloud_rdns" "rdns_master" {
  count      = length(hcloud_server.master)
  server_id  = hcloud_server.master[count.index].id
  ip_address = hcloud_server.master[count.index].ipv4_address
  dns_ptr    = hcloud_server.master[count.index].name
}

resource "hcloud_server_network" "master_network" {
  count      = length(hcloud_server.master)
  network_id = hcloud_network.default.id
  server_id  = hcloud_server.master.*.id[count.index]
  ip         = "10.0.1.${count.index + 2}"
}

# Worker
resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "node-${count.index + 1}.${var.domain}"
  image       = "ubuntu-18.04"
  server_type = var.worker_servertype
  location    = var.datacenter
  user_data   = file("./user-data/cloud-config.yaml")
}

resource "hcloud_rdns" "rdns_worker" {
  count = length(hcloud_server.worker)
  server_id = hcloud_server.worker[count.index].id
  ip_address = hcloud_server.worker[count.index].ipv4_address
  dns_ptr = hcloud_server.worker[count.index].name
}

resource "hcloud_server_network" "worker_network" {
  count      = length(hcloud_server.worker)
  network_id = hcloud_network.default.id
  server_id  = hcloud_server.worker.*.id[count.index]
  ip         = "10.0.2.${count.index + 1}"
}

resource "hcloud_floating_ip" "lbipv4" {
  count         = var.use_my_ip > 0 ? 0 : var.floatip_count
  type          = "ipv4"
  home_location = var.datacenter
}

data "hcloud_floating_ip" "lbipv4" {
  count         = var.use_my_ip > 0 ? 1 : 0
  with_selector = var.my_ip_tag
}
