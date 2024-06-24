resource "scaleway_instance_placement_group" "availability_group" {
  policy_type = "max_availability"
  policy_mode = "enforced"
}

data "scaleway_k8s_version" "latest" {
  name = "latest"
}


resource "scaleway_k8s_cluster" "k8s_cluster" {
  name                        = "${local.name}-cluster"
  version                     = data.scaleway_k8s_version.latest.name
  cni                         = "cilium"
  private_network_id          = scaleway_vpc_private_network.this.id
  delete_additional_resources = true
  depends_on                  = [scaleway_vpc_private_network.this]

  autoscaler_config {
    disable_scale_down               = false
    scale_down_unneeded_time         = "2m"
    scale_down_delay_after_add       = "30m"
    scale_down_utilization_threshold = 0.5
    estimator                        = "binpacking"
    expander                         = "random"
    ignore_daemonsets_utilization    = true
  }
  tags = concat(local.tags)
}

resource "scaleway_k8s_pool" "k8s-tidb-management_pool" {
  name               = "${local.name}-management-pool"
  cluster_id         = scaleway_k8s_cluster.k8s_cluster.id
  node_type          = var.node_type_management
  size               = 3
  min_size           = 3
  max_size           = 3
  autoscaling        = true
  autohealing        = true
  container_runtime  = "containerd"
  placement_group_id = scaleway_instance_placement_group.availability_group.id
  tags = concat(local.tags,["nodetype=management"])
}

resource "scaleway_k8s_pool" "k8s-storage_pool" {
  name               = "${local.name}-storage_pool"
  # count = var.node_count
  cluster_id         = scaleway_k8s_cluster.k8s_cluster.id
  node_type          = var.node_type_storage
  size               = 5
  min_size           = 3
  max_size           = 5
  # nodes = [element(scaleway_instance_server.k8s_nodes.*.id, count.index)]
  autoscaling        = true
  autohealing        = true
  container_runtime  = "containerd"
  placement_group_id = scaleway_instance_placement_group.availability_group.id
  tags = concat(local.tags,["nodetype=storage","taint=node=storage:NoSchedule"])
}




variable "hide" { # Workaround to hide local-exec output
  default   = "yes"
  sensitive = true
}

resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.k8s-storage_pool,scaleway_k8s_pool.k8s-tidb-management_pool]
  triggers = {
    host                   = scaleway_k8s_cluster.k8s_cluster.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.k8s_cluster.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.k8s_cluster.kubeconfig[0].cluster_ca_certificate
  }

  provisioner "local-exec" {
    environment = {
      HIDE_OUTPUT = var.hide # Workaround to hide local-exec output
    }
    command = <<-EOT
    cat<<EOF>kubeconfig.yaml
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: ${self.triggers.cluster_ca_certificate}
        server: ${self.triggers.host}
      name: ${scaleway_k8s_cluster.k8s_cluster.name}
    contexts:
    - context:
        cluster: ${scaleway_k8s_cluster.k8s_cluster.name}
        user: admin
      name: admin@${scaleway_k8s_cluster.k8s_cluster.name}
    current-context: admin@${scaleway_k8s_cluster.k8s_cluster.name}
    kind: Config
    preferences: {}
    users:
    - name: admin
      user:
        token: ${self.triggers.token}
    EOF
    EOT
  }
}

provider "kubernetes" {
  host                   = null_resource.kubeconfig.triggers.host
  token                  = null_resource.kubeconfig.triggers.token
  cluster_ca_certificate = base64decode(null_resource.kubeconfig.triggers.cluster_ca_certificate)
}

resource "time_sleep" "wait_for_cluster" { # wait 1 minute for cluster to stabilize (CNI, etc...)
  depends_on      = [null_resource.kubeconfig]
  create_duration = "60s"
}


resource "scaleway_block_volume" "block_volume" {
    iops       = 5000
    name       = "volulme-for-pv"
    size_in_gb = 200
}
output "block_volume-id" {

  value = [resource.scaleway_block_volume.block_volume.id, resource.scaleway_block_volume.block_volume.zone]

}

