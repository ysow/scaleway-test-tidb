

resource "scaleway_vpc" "this" {
  name = format("${local.name}-vpc-%s", var.env)
  tags = local.tags
}

resource "scaleway_vpc_private_network" "this" {
  name   = format("${local.name}-pn-%s", var.env)
  vpc_id = scaleway_vpc.this.id

  tags = local.tags
}

resource "scaleway_vpc_public_gateway_ip" "this" {
}

resource "scaleway_vpc_public_gateway" "this" {
  name       = format("${local.name}-gw-%s", var.env)
  type       = "VPC-GW-M"
  ip_id      = scaleway_vpc_public_gateway_ip.this.id
  tags = local.tags
  depends_on = [scaleway_vpc_private_network.this]
  # to avoid race conditions, create PGW after PN
}

resource "scaleway_vpc_gateway_network" "this" {
  gateway_id         = scaleway_vpc_public_gateway.this.id
  private_network_id = scaleway_vpc_private_network.this.id
  enable_masquerade  = true
  ipam_config {
    push_default_route = true
  }
}

resource "time_sleep" "wait_for_pgw" {
  # wait 20s after creating the PGW network.
  depends_on      = [scaleway_vpc_gateway_network.this]
  create_duration = "20s"
}
