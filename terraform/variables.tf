# main.tf
variable "access_key" {
  type = string
  sensitive = true
}

variable "secret_key" {
  type = string
  sensitive = true
}

variable "organization_id" {
  type = string
  sensitive = true
}

variable "project_id" {
  type = string
  sensitive = true
}


variable "cluster_name" {
  default = "my-kubernetes-cluster"
}

variable "node_pool_name" {
  default = "my-node-pool"
}

variable "node_type_management" {
  default = "PRO2-S"
}
variable "node_type_storage"   {
  default = "PRO2-XXS"  
}

variable "node_count" {
  default = 3
}

variable "volume_size" {
  default = 200
}

variable "tags" {
  type = list(string)
  default = ["demo","SA"]
}

variable "env" {
  type    = string
  default = "test"
}
# scaleway.auto.tfvars
