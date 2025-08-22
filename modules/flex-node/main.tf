terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

variable "instance-role" {
    type = string
    description = "Name of the flex node you are creating"
}

variable "image-name" {
    type = string
    description = "Openstack image name to use"
}

variable "flavor-name" {
    type = string
    description = "Openstack flavor name to use"
}

variable "instance-count" {
    type = number
    description = "Number of instances"
}

variable "cluster-name" {
    type = string
    description = "name of the cluster, defaults to cluster.local but should be passed from root module"
}

variable "security-group-ids" {
    type = list(string)
    description = "List of security group ids"
}

variable "openstack-flex-network-network-id" {
    type = string
    description = "Then openstack-flex-network network id"
}

variable "openstack-flex-subnet-subnet-id" {
    type = string
    description = "The openstack-flex-subnet subnet id"
}

variable "openstack-flex-network-internal-network-id" {
    type = string
    description = "The openstack-flex-internal-network id"
}

variable "openstack-flex-network-compute-network-id" {
    type = string
    description = "The openstack-flex-compute network id"
}

variable "openstack-keypair-id" {
    type = string
    description = "The openstack keypair id"
}

variable "metal_lb_vips" {
    type = list(string)
    description = "Metal LB ip addresses if needed"
    default = []
}

# Create network ports for controller nodes
resource "openstack_networking_port_v2" "instance-ports" {
  count              = var.instance-count
  name               = format("%s%02d.%s", var.instance-role, count.index + 1, var.cluster-name)
  network_id         = var.openstack-flex-network-network-id
  admin_state_up     = "true"
  security_group_ids = var.security-group-ids
  fixed_ip {
    subnet_id = var.openstack-flex-subnet-subnet-id
  }
  dynamic "allowed_address_pairs" {
    for_each = toset(var.metal_lb_vips)
    content {
      ip_address = allowed_address_pairs.value
    }
  }
}

resource "openstack_compute_instance_v2" "flex-node" {
  count = var.instance-count
  name        = format("%s%02d.%s", var.instance-role, count.index + 1, var.cluster-name)
  image_name  = var.image-name
  flavor_name = var.flavor-name
  key_pair    = var.openstack-keypair-id
  network {
    port = openstack_networking_port_v2.instance-ports[count.index].id
  }
  network {
    uuid = var.openstack-flex-network-internal-network-id
  }
  network {
    uuid = var.openstack-flex-network-compute-network-id
  }
  metadata = {
    hostname     = format("%s%02d", var.instance-role, count.index + 1)
    group        = "openstack-flex"
    cluster_name = var.cluster-name
    role         = var.instance-role
  }
}
