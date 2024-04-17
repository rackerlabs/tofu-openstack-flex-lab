variable "cloud" {
  type        = string
  description = "The cloud you want to use from clouds.yaml"
  sensitive   = false
}

variable "ssh_public_key_path" {
  type = string
  description = "path to public key you would like to add to openstack"
}

variable "controller_count" {
  type = number
  description = "number of controllers"
  default = 3
}

variable "controller_image" {
  type = string
  description = "Image name for controller"
  default = "Ubuntu-22.04"
}

variable "controller_flavor" {
  type = string
  description = "Flavor name for controller"
  default = "m1.large"
}

variable "compute_count" {
  type = number
  description = "Number of compute nodes"
  default = 4
}

variable "compute_image" {
  type = string
  description = "Image name for compute nodes"
  default = "Ubuntu-22.04"
}

variable "compute_flavor" {
  type = string
  description = "Flavor name for compute nodes"
  default = "m1.large"
}

variable "storage_count" {
  type = number
  description = "Number of workers that will also have storage volumes."
  default = 3
}

variable "storage_image" {
  type = string
  description = "Image name for storage nodes"
  default = "Ubuntu-22.04"
}

variable "storage_flavor" {
  type = string
  description = "Flavor name for storage nodes"
  default = "m1.large"
}

variable "bastion_image" {
  type = string
  description = "Image name for bastion node"
  default = "Ubuntu-22.04"
}

variable "bastion_flavor" {
  type = string
  description = "Flavor name for bastion node"
  default = "m1.medium"
}

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
  port_security_enabled = false
}

# Create management subnet
resource "openstack_networking_subnet_v2" "openstack-flex-subnet" {
  name = "openstack-flex-subnet"
  network_id = openstack_networking_network_v2.openstack-flex.id
  cidr       = "172.31.0.0/22"
  ip_version = 4
  enable_dhcp = true
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

# # Create internal router interface
# resource "openstack_networking_router_interface_v2" "openstack-flex-router-interface-internal" {
#   router_id = openstack_networking_router_v2.openstack-flex-router.id
#   subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet-internal.id
# }

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

# # Create compute router interface
# resource "openstack_networking_router_interface_v2" "openstack-flex-router-compute-internal" {
#   router_id = openstack_networking_router_v2.openstack-flex-router.id
#   subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet-compute.id
# }

resource "openstack_compute_keypair_v2" "mykey" {
  name       = "mykey"
  public_key = file("${var.ssh_public_key_path}")
}

# Create controller nodes
resource "openstack_compute_instance_v2" "k8s-controller" {
  count     = var.controller_count
  name      = format("controller%02d", count.index + 1)
  image_name = var.controller_image
  flavor_name = var.controller_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    name = openstack_networking_network_v2.openstack-flex.name
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
  }
}
# Create compute nodes
resource "openstack_compute_instance_v2" "compute-node" {
  count     = var.compute_count
  name      = format("compute%02d", count.index + 1)
  image_name  = var.compute_image
  flavor_name = var.compute_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    name = openstack_networking_network_v2.openstack-flex.name
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
  }
}

# Create storage nodes
resource "openstack_compute_instance_v2" "storage-node" {
  count     = var.storage_count
  name      = format("storage%02d", count.index + 1)
  image_name  = var.storage_image
  flavor_name = var.storage_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    name = openstack_networking_network_v2.openstack-flex.name
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
  }
}

# resource "openstack_blockstorage_volume_v3" "storage-volume-1" {
#   # for_each = openstack_compute_instance_v2.storage-node
#   for_each = { for instance in openstack_compute_instance_v2.storage-node : instance.name => instance }
#   name      = format("%s-volume-1", each.value.name)
#   size = "50"
# }

# resource "openstack_blockstorage_volume_v3" "storage-volume-2" {
#   # for_each = openstack_compute_instance_v2.storage-node
#   for_each = { for instance in openstack_compute_instance_v2.storage-node : instance.name => instance }
#   name      = format("%s-volume-1", each.value.name)
#   size = "50"
# }

# resource "openstack_blockstorage_volume_v3" "storage-volume-3" {
#   for_each = { for instance in openstack_compute_instance_v2.storage-node : instance.name => instance }
#   name      = format("%s-volume-1", each.value.name)
#   size = "50"
# }

resource "openstack_compute_instance_v2" "bastion" {
  name      = "openstack-flex-launcher"
  image_name  = var.bastion_image
  flavor_name = var.bastion_flavor
  key_pair  = openstack_compute_keypair_v2.mykey.name
  network {
    # name = openstack_networking_network_v2.openstack-flex.name
    port = openstack_networking_port_v2.bastion.id
  }
  metadata = {
    hostname = "openstack-flex-node-launcher"
    group = "openstack-flex"
  }
}

# Create network port bastion
resource "openstack_networking_port_v2" "bastion" {
  name = "bastion"
  network_id = openstack_networking_network_v2.openstack-flex.id
  admin_state_up = "true"
  no_security_groups = "true" # Doc says that security groups interfere with metallb

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.openstack-flex-subnet.id
  }
}

# Create floating ip for bastion/jump server
resource "openstack_networking_floatingip_v2" "bastion" {
  pool = "PUBLICNET"
  port_id = openstack_networking_port_v2.bastion.id
}

# resource "openstack_blockstorage_volume_v3" "ceph_storage-node5" {
#   count = 3
#   name      = format("openstack-flex-node-5-volume-%s", count.index)
#   size = "20"
# }

# resource "openstack_blockstorage_volume_v3" "ceph_storage-node6" {
#   count = 3
#   name      = format("openstack-flex-node-6-volume-%s", count.index)
#   size = "20"
# }

# resource "openstack_blockstorage_volume_v3" "ceph_storage-node7" {
#   count = 3
#   name      = format("openstack-flex-node-7-volume-%s", count.index)
#   size = "20"
# }

# resource "openstack_compute_volume_attach_v2" "ceph_attachments" {

# }
