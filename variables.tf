variable "cloud" {
  type        = string
  description = "The cloud you want to use from clouds.yaml"
  sensitive   = false
}

variable "ssh_public_key_path" {
  type = string
  description = "path to public key you would like to add to openstack"
}

variable "kubernetes_count" {
  type = number
  description = "number of kubernetes nodes"
  default = 3
}

variable "kubernetes_image" {
  type = string
  description = "Image name for kubernetes nodes"
  default = "Ubuntu-22.04"
}

variable "kubernetes_flavor" {
  type = string
  description = "Flavor name for kubernetes nodes"
  default = "m1.large"
}

variable "network_count" {
  type = number
  description = "number of network nodes"
  default = 3
}

variable "network_image" {
  type = string
  description = "Image name for network nodes"
  default = "Ubuntu-22.04"
}

variable "network_flavor" {
  type = string
  description = "Flavor name for network nodes"
  default = "m1.large"
}

variable "controller_count" {
  type = number
  description = "number of controllers"
  default = 7
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

variable "cluster_name" {
  type = string
  description = "Name of the cluster"
  default = "cluster.local"
}
