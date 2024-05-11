terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

variable "instance-uuid" {
    type = string
    description = "instance uuid to attach volumes to"
}

variable "instance-name" {
  type = string
  description = "instance name to attach volumes to"
}

resource "openstack_blockstorage_volume_v3" "storage-volumes" {
  count = 3
  name      = format("%s-volume-%d", var.instance-name, count.index + 1)
  size = "120"
}

resource "openstack_compute_volume_attach_v2" "storage_attachments" {
  for_each = { for item in openstack_blockstorage_volume_v3.storage-volumes : item.name => item.id }
  instance_id = var.instance-uuid
  volume_id = each.value
}