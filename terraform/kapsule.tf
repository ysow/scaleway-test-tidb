resource "scaleway_instance_placement_group" "availability_group" {
  policy_type = "max_availability"
  policy_mode = "enforced"
}

data "scaleway_k8s_version" "latest" {
  name = "latest"
}


resource "scaleway_k8s_cluster" "k8s_cluster" {
  name                        = "${local.name}-cluster"
  type                        = "multicloud"
  version                     = data.scaleway_k8s_version.latest.name
  cni                         = "kilo"
  region                      = "fr-par"
  # private_network_id          = scaleway_vpc_private_network.this.id
  delete_additional_resources = false

  # autoscaler_config {
  #   disable_scale_down               = false
  #   scale_down_unneeded_time         = "2m"
  #   scale_down_delay_after_add       = "30m"
  #   scale_down_utilization_threshold = 0.5
  #   estimator                        = "binpacking"
  #   expander                         = "random"
  #   ignore_daemonsets_utilization    = true
  # }
  tags = concat(local.tags)
}

# resource "scaleway_k8s_pool" "management_pool" {
#   name               = "${local.name}-management-pool"
#   cluster_id         = scaleway_k8s_cluster.k8s_cluster.id
#   node_type          = var.node_type_management
#   size               = 1
#   region                      = "fr-par"

#   tags = concat(local.tags,["nodetype=management"])
# }

resource "scaleway_k8s_pool" "pool" {
  name               = "${local.name}-${var.nodepools[count.index]}-pool"
  count = var.node_count
  cluster_id         = scaleway_k8s_cluster.k8s_cluster.id
  node_type          = "external"
  size               = 0
  region             = "fr-par"
  
  tags = concat(local.tags,var.node_tags[count.index])
}

###############################################
#     CONFIGURE THE ELASTIC METAL SERVER      #
###############################################

# Select at least one SSH key to connect to your server
data "local_sensitive_file" "secret_key" {
  # name = "ssh-key"
  filename = pathexpand("../secret-key")
}
data "local_sensitive_file" "ssh_private_key" {
  # name = "ssh-key"
  filename = pathexpand("~/.ssh/id_ed25519_kosmos")
}
resource "scaleway_iam_ssh_key" "key" {
  name = "ssh-key"
  public_key = file("~/.ssh/id_ed25519_kosmos.pub")
}
# Select the type of offer for your server
data "scaleway_baremetal_offer" "offer" {
  name = "EM-B220E-NVME"
  
}
# Select the OS you want installed on your server
data "scaleway_baremetal_os" "os" {
  name = "Ubuntu"
  version = "22.04 LTS (Jammy Jellyfish)"
}

resource "scaleway_baremetal_server" "server" {
  offer       = data.scaleway_baremetal_offer.offer.name
  os          = data.scaleway_baremetal_os.os.id
  ssh_key_ids = [scaleway_iam_ssh_key.key.id]
  count = var.node_count
  # Configure the SSH connexion used by Terraform for the remote execution  
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file(data.local_sensitive_file.ssh_private_key.filename)
    host     = one([for k in self.ips : k if k.version == "IPv4"]).address   # We look for the IPv4 in the list of IPs
  }

  # Download and execute the configuration script
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /mnt/tikv-data",
      "sudo mkdir -p /mnt/tiflash-data",
      "sudo mkdir -p /mnt/pd-data",
      "sudo mkdir -p /mnt/tidb-dashboard",
      "sudo mkdir -p /mnt/ng-monitoring-data",
      "sudo mkdir -p /mnt/tidb-monitor-data",
      "sudo mkdir -p /mnt/additional-1",
      "sudo mkdir -p /mnt/additional-2",
      "sudo mkdir -p /mnt/additional-3",
      "sudo mkdir -p /mnt/additional-4",
      "wget https://scwcontainermulticloud.s3.fr-par.scw.cloud/node-agent_linux_amd64 > log && chmod +x node-agent_linux_amd64",
      "echo \"\nPOOL_ID=${split("/", scaleway_k8s_pool.pool[count.index].id)[1]}\nPOOL_REGION=${scaleway_k8s_pool.pool[count.index].region}\nSCW_SECRET_KEY=${data.local_sensitive_file.secret_key.content}\" >> log",
      "export POOL_ID=${split("/", scaleway_k8s_pool.pool[count.index].id)[1]}  POOL_REGION=${scaleway_k8s_pool.pool[count.index].region}  SCW_SECRET_KEY=${data.local_sensitive_file.secret_key.content}",
      "sudo -E ./node-agent_linux_amd64 -loglevel 0 -no-controller >> log",
    ]
  }           # The list of SSH key IDs allowed to connect to the server
  zone        = "fr-par-2"
}


variable "hide" { # Workaround to hide local-exec output
  default   = "yes"
  sensitive = true
}

resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.pool]
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

