locals {
  alpine_version = "3.22.1"
  alpine_image_url = join("",
    [
      "https://dl-cdn.alpinelinux.org/alpine/v${substr(local.alpine_version, 0, 4)}",
      "/releases/cloud/generic_alpine-${local.alpine_version}-x86_64-uefi-cloudinit-r0.qcow2"
    ]
  )
}

resource "stackit_network_area" "main" {
  organization_id = var.stackit_organization_id
  name            = "nwa-main"
  network_ranges = [
    {
      prefix = "10.1.0.0/16"
    }
  ]
  # Each project attached to this network area uses 1 IP address within the transfer network,
  # so choose the size accordingly (extension is not possible).
  transfer_network      = "10.255.255.0/24"
  default_nameservers   = ["9.9.9.9"]
  default_prefix_length = 24
  min_prefix_length     = 23
  max_prefix_length     = 26
}

resource "stackit_network_area_route" "site_to_site_vpn" {
  organization_id = stackit_network_area.main.organization_id
  network_area_id = stackit_network_area.main.network_area_id
  prefix          = one(azurerm_virtual_network.main.address_space)
  next_hop        = stackit_network_interface.vpn_gateway.ipv4
}

resource "stackit_resourcemanager_project" "site_to_site_vpn" {
  parent_container_id = stackit_network_area.main.organization_id
  name                = "pro-stackit-azure-site-to-site-vpn"
  labels = {
    "networkArea" = stackit_network_area.main.network_area_id
  }
  owner_email = var.owner_email
}

resource "stackit_network" "site_to_site_vpn" {
  project_id       = stackit_resourcemanager_project.site_to_site_vpn.project_id
  name             = "nw-stackit-azure-site-to-site-vpn"
  ipv4_nameservers = ["9.9.9.9"]
  ipv4_prefix      = "10.1.255.0/24"
  routed           = true
}

resource "stackit_security_group" "site_to_site_vpn" {
  project_id = stackit_resourcemanager_project.site_to_site_vpn.project_id
  name       = "sg-stackit-azure-site-to-site-vpn"
  stateful   = true
}

resource "stackit_security_group_rule" "allow_internal_traffic_to_vpn_gateway_network" {
  project_id        = stackit_resourcemanager_project.site_to_site_vpn.project_id
  security_group_id = stackit_security_group.site_to_site_vpn.security_group_id
  direction         = "ingress"
  ip_range          = one(stackit_network_area.main.network_ranges).prefix
}

resource "terraform_data" "alpine_image" {
  triggers_replace = local.alpine_image_url

  # Download Alpine image, overwriting placeholder file.
  provisioner "local-exec" {
    when    = create
    command = "curl --clobber -o alpine.qcow2 ${local.alpine_image_url}"
  }
}

resource "stackit_image" "alpine" {
  project_id  = stackit_resourcemanager_project.site_to_site_vpn.project_id
  name        = "img-alpine-${local.alpine_version}"
  disk_format = "qcow2"
  # local_file_path expects a file to be present at all times, therefore we use an
  # empty placeholder file to still be able to download the image on the fly.
  local_file_path = "alpine.qcow2"
  min_disk_size   = 1
  min_ram         = 128

  # Truncate Alpine image to 0 bytes, making it a placeholder file again.
  provisioner "local-exec" {
    when    = create
    command = "truncate -s0 ${self.local_file_path}"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.alpine_image]
  }
}

resource "stackit_network_interface" "vpn_gateway" {
  project_id         = stackit_resourcemanager_project.site_to_site_vpn.project_id
  network_id         = stackit_network.site_to_site_vpn.network_id
  security_group_ids = [stackit_security_group.site_to_site_vpn.security_group_id]
  allowed_addresses  = [one(azurerm_virtual_network.main.address_space)]
}

resource "stackit_public_ip" "vpn_gateway" {
  project_id           = stackit_resourcemanager_project.site_to_site_vpn.project_id
  network_interface_id = stackit_network_interface.vpn_gateway.network_interface_id
}

resource "stackit_key_pair" "vpn_gateway" {
  name       = "key-vpn-gateway"
  public_key = chomp(file(var.public_key_path))
}

resource "stackit_server" "vpn_gateway" {
  project_id = stackit_resourcemanager_project.site_to_site_vpn.project_id
  boot_volume = {
    size                  = 1
    source_type           = "image"
    source_id             = stackit_image.alpine.image_id
    performance_class     = "storage_premium_perf0"
    delete_on_termination = true
  }
  name               = "ser-vpn-gateway-stackit-azure"
  machine_type       = "t1.2"
  keypair_name       = stackit_key_pair.vpn_gateway.name
  network_interfaces = [stackit_network_interface.vpn_gateway.network_interface_id]
  user_data = templatefile(
    "./cloud-init.yaml.tftpl",
    {
      stackit_gateway_ipv4  = trim(stackit_network_interface.vpn_gateway.ipv4, "\"")
      stackit_address_space = trim(one(stackit_network_area.main.network_ranges).prefix, "\"")
      azure_gateway_ipv4    = trim(azurerm_public_ip.vnet_gateway.ip_address, "\"")
      azure_address_space   = trim(one(azurerm_virtual_network.main.address_space), "\"")
      shared_key            = azurerm_virtual_network_gateway_connection.stackit.shared_key
      sa_lifetime           = azurerm_virtual_network_gateway_connection.stackit.ipsec_policy[0].sa_lifetime
    }
  )
}

# Test resources

resource "stackit_resourcemanager_project" "test" {
  parent_container_id = stackit_network_area.main.organization_id
  name                = "pro-test-site-to-site-vpn"
  labels = {
    "networkArea" = stackit_network_area.main.network_area_id
  }
  owner_email = var.owner_email
}

resource "stackit_network" "test" {
  project_id       = stackit_resourcemanager_project.test.project_id
  name             = "nw-stackit-azure-site-to-site-vpn"
  ipv4_nameservers = ["9.9.9.9"]
  ipv4_prefix      = "10.1.0.0/24"
  routed           = true
}

resource "stackit_security_group" "test" {
  project_id = stackit_resourcemanager_project.test.project_id
  name       = "sg-test-stackit-azure-site-to-site-vpn"
  stateful   = true
}

resource "stackit_security_group_rule" "test" {
  project_id        = stackit_resourcemanager_project.test.project_id
  security_group_id = stackit_security_group.test.security_group_id
  direction         = "ingress"
  description = "Allow SSH"
  protocol = {
    name = "tcp"
  }
  port_range = {
    max = 22
    min = 22
  }
}

resource "stackit_network_interface" "test" {
  project_id         = stackit_resourcemanager_project.test.project_id
  network_id         = stackit_network.test.network_id
  security_group_ids = [stackit_security_group.test.security_group_id]
  ipv4               = "10.1.0.3"
}

resource "stackit_server" "test" {
  project_id = stackit_resourcemanager_project.test.project_id
  boot_volume = {
    size                  = 1
    source_type           = "image"
    source_id             = stackit_image.alpine_test.image_id
    performance_class     = "storage_premium_perf0"
    delete_on_termination = true
  }
  name               = "ser-test"
  machine_type       = "t1.2"
  keypair_name       = stackit_key_pair.vpn_gateway.name
  network_interfaces = [stackit_network_interface.test.network_interface_id]
}

resource "stackit_public_ip" "test" {
  project_id           = stackit_resourcemanager_project.test.project_id
  network_interface_id = stackit_network_interface.test.network_interface_id
}

resource "terraform_data" "alpine_image_test" {
  triggers_replace = local.alpine_image_url

  # Download Alpine image, overwriting placeholder file.
  provisioner "local-exec" {
    when    = create
    command = "curl --clobber -o alpine.qcow2 ${local.alpine_image_url}"
  }
}

resource "stackit_image" "alpine_test" {
  project_id  = stackit_resourcemanager_project.test.project_id
  name        = "img-alpine-${local.alpine_version}"
  disk_format = "qcow2"
  # local_file_path expects a file to be present at all times, therefore we use an
  # empty placeholder file to still be able to download the image on the fly.
  local_file_path = "alpine.qcow2"
  min_disk_size   = 1
  min_ram         = 128

  # Truncate Alpine image to 0 bytes, making it a placeholder file again.
  provisioner "local-exec" {
    when    = create
    command = "truncate -s0 ${self.local_file_path}"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.alpine_image_test]
  }
}
