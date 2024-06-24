locals {
  tags = concat(["terraform=true"],var.tags, [var.env])
  name = "tidb-demo"
}
