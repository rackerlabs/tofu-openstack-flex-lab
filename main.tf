
# Define required providers
terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
    cloud = var.cloud
    insecure = true
}

#### Network Configuration

# Get external network
data "openstack_networking_network_v2" "external-network" {
  name = "PUBLICNET"
}

# Create a router
resource "openstack_networking_router_v2" "openstack-flex-router" {
  name                = "openstack-flex-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external-network.id
}

## Management network
# Create management network
resource "openstack_networking_network_v2" "openstack-flex" {
  name           = "openstack-flex"
  admin_state_up = "true"
  external = false
  port_security_enabled = true
}

# Create management subnet
resource "openstack_networking_subnet_v2" "openstack-flex-subnet" {
  name = "openstack-flex-subnet"
  network_id = openstack_networking_network_v2.openstack-flex.id
  cidr       = "172.31.0.0/22"
  ip_version = 4
  enable_dhcp = true
  allocation_pool {
    start = "172.31.0.10"
    end   = "172.31.2.254"
  }
}

# Create management router interface
resource "openstack_networking_router_interface_v2" "openstack-flex-router-interface" {
  router_id = openstack_networking_router_v2.openstack-flex-router.id
  subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
}

## Internal Network
# Create internal network
resource "openstack_networking_network_v2" "openstack-flex-internal" {
  name           = "openstack-flex-internal"
  admin_state_up = "true"
  external = false
  port_security_enabled = false
}

# Create internal subnet
resource "openstack_networking_subnet_v2" "openstack-flex-subnet-internal" {
  name = "openstack-flex-subnet-internal"
  network_id = openstack_networking_network_v2.openstack-flex-internal.id
  cidr       = "192.168.0.0/22"
  no_gateway = true
  ip_version = 4
  enable_dhcp = false
}

## Compute Network
# Create compute network
resource "openstack_networking_network_v2" "openstack-flex-compute" {
  name           = "openstack-flex-compute"
  admin_state_up = "true"
  external = false
  port_security_enabled = false
}
# Create compute subnet
resource "openstack_networking_subnet_v2" "openstack-flex-subnet-compute" {
  name = "openstack-flex-subnet-compute"
  network_id = openstack_networking_network_v2.openstack-flex-compute.id
  cidr       = "192.168.100.0/22"
  no_gateway = true
  ip_version = 4
  enable_dhcp = false
}

resource "openstack_compute_keypair_v2" "mykey" {
  name       = "mykey"
  public_key = file("${var.ssh_public_key_path}")
}

# Create network ports for k8s nodes
resource "openstack_networking_port_v2" "kubernetes-ports" {
  count = var.kubernetes_count
  name                  = format("kubernetes%02d", count.index + 1)
  network_id            = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.mlb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

# Create kubernetes nodes
resource "openstack_compute_instance_v2" "k8s-controller" {
  count     = var.kubernetes_count
  name      = format("kubernetes%02d", count.index + 1)
  image_name = var.kubernetes_image
  flavor_name = var.kubernetes_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    port = openstack_networking_port_v2.kubernetes-ports[count.index].id
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-internal.name
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-compute.name
  }
  metadata = {
    hostname = format("kubernetes%02d", count.index + 1)
    group = "openstack-flex"
  }
}

# Create network ports for controller nodes
resource "openstack_networking_port_v2" "controller-ports" {
  count = var.controller_count
  name                  = format("controller%02d", count.index + 1)
  network_id            = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.mlb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

# Create controller nodes
resource "openstack_compute_instance_v2" "openstack-controller" {
  count     = var.controller_count
  name      = format("controller%02d.%s", count.index + 1, var.cluster_name)
  image_name = var.controller_image
  flavor_name = var.controller_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    port = openstack_networking_port_v2.controller-ports[count.index].id
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-internal.name
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-compute.name
  }
  metadata = {
    hostname = format("controller%02d", count.index + 1)
    group = "openstack-flex"
    cluster_name = var.cluster_name
    role = "controller"
  }
}

# Create network ports for compute nodes
resource "openstack_networking_port_v2" "compute-ports" {
  count = var.compute_count
  name                  = format("compute%02d", count.index + 1)
  network_id            = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.mlb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

# Create compute nodes
resource "openstack_compute_instance_v2" "compute-node" {
  count     = var.compute_count
  name      = format("compute%02d.%s", count.index + 1, var.cluster_name)
  image_name  = var.compute_image
  flavor_name = var.compute_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    port = openstack_networking_port_v2.compute-ports[count.index].id
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-internal.name
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-compute.name
  }
  metadata = {
    hostname = format("compute%02d", count.index + 1)
    group = "openstack-flex"
    cluster_name = var.cluster_name
    role = "compute"
  }
}

# Create network ports for network nodes
resource "openstack_networking_port_v2" "network-ports" {
  count = var.network_count
  name                  = format("network%02d", count.index + 1)
  network_id            = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.mlb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

# Create network nodes
resource "openstack_compute_instance_v2" "network-node" {
  count     = var.network_count
  name      = format("network%02d", count.index + 1)
  image_name  = var.network_image
  flavor_name = var.network_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    port = openstack_networking_port_v2.network-ports[count.index].id
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-internal.name
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-compute.name
  }
  metadata = {
    hostname = format("network%02d", count.index + 1)
    group = "openstack-flex"
  }
}

# Create network ports for storage nodes
resource "openstack_networking_port_v2" "storage-ports" {
  count = var.storage_count
  name                  = format("storage%02d", count.index + 1)
  network_id            = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.mlb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

# Create storage nodes
resource "openstack_compute_instance_v2" "storage-node" {
  count     = var.storage_count
  name      = format("storage%02d.%s", count.index + 1, var.cluster_name)
  image_name  = var.storage_image
  flavor_name = var.storage_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
    network {
    port = openstack_networking_port_v2.storage-ports[count.index].id
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-internal.name
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-compute.name
  }
  metadata = {
    hostname = format("storage%02d", count.index + 1)
    group = "openstack-flex"
    cluster_name = var.cluster_name
    role = "storage"
  }
}

# Create network ports for ceph nodes
resource "openstack_networking_port_v2" "ceph-ports" {
  count = var.storage_count
  name                  = format("ceph%02d", count.index + 1)
  network_id            = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.mlb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

# Create ceph nodes
resource "openstack_compute_instance_v2" "ceph-node" {
  count     = var.ceph_count
  name      = format("ceph%02d", count.index + 1)
  image_name  = var.ceph_image
  flavor_name = var.ceph_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
    network {
    port = openstack_networking_port_v2.ceph-ports[count.index].id
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-internal.name
  }
  network {
    name = openstack_networking_network_v2.openstack-flex-compute.name
  }
  metadata = {
    hostname = format("ceph%02d", count.index + 1)
    group = "openstack-flex"
  }
}

# Create storage volumes and attach to storage nodes
module "storage-volumes" {
  source = "./modules/storage-volumes"
  for_each = { for item in openstack_compute_instance_v2.storage-node : item.name => item.id }
  instance-name = each.key
  instance-uuid = each.value
}

# Create storage volumes and attach to ceph nodes
module "ceph-volumes" {
  source = "./modules/ceph-volumes"
  for_each = { for item in openstack_compute_instance_v2.ceph-node : item.name => item.id }
  instance-name = each.key
  instance-uuid = each.value
}

# Create admin port for bastion node
resource "openstack_networking_port_v2" "bastion" {
  name                  = "bastion"
  network_id            = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.mlb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

# Create bastion node
data "template_file" "cloudinit" {
  template = file("./scripts/cloudinit/configure.yaml")
}
resource "openstack_compute_instance_v2" "bastion" {
  name      = format("openstack-flex-launcher.%s", var.cluster_name)
  image_name  = var.bastion_image
  flavor_name = var.bastion_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    port = openstack_networking_port_v2.bastion.id
  }
  metadata = {
    hostname = "openstack-flex-node-launcher"
    role = "flex-launcher"
    group = "openstack-flex"
    cluster_name = var.cluster_name
  }
  user_data = data.template_file.cloudinit.rendered
}

# Create network port for metallb_vips
resource "openstack_networking_port_v2" "mlbvips" {
  count = length(var.mlb_vips)
  name = format("mlbvip%02d", count.index + 1)
  network_id = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  no_security_groups = "true"

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
    ip_address = var.mlb_vips[count.index]
  }
}

# Create floating ip for bastion/jump server
resource "openstack_networking_floatingip_v2" "bastion" {
  pool = "PUBLICNET"
  port_id = openstack_networking_port_v2.bastion.id
}

# Create floating ip for metallb_vip
resource "openstack_networking_floatingip_v2" "mlbflips" {
  count = length(var.mlb_vips)
  pool = "PUBLICNET"
  port_id = openstack_networking_port_v2.mlbvips[count.index].id
}

output "bastion_flip" {
  value = openstack_networking_floatingip_v2.bastion.address
}

output "metallb_flips" {
  value = zipmap(var.mlb_vips,openstack_networking_floatingip_v2.mlbflips[*].address)
}
