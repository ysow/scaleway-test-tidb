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
  default = "external"
}
variable "node_type_storage"   {
  default = "external"  
}

variable "node_count" {
  default = 2
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

variable "nodepools" {
  type    = list(string)
  default =  ["management","storage"]
}
variable "node_tags" {
  type = list(list(string))
  default = [ [ "nodetype=management" ], ["nodetype=storage", "taint=node=storage:NoSchedule"] ]
  
}
# scaleway.auto.tfvars
