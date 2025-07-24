resource "azurerm_resource_group" "site_to_site_vpn" {
  name     = "rg-azure-stackit-site-to-site-vpn"
  location = "West Europe"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-main"
  location            = azurerm_resource_group.site_to_site_vpn.location
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.site_to_site_vpn.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.255.224/27"]
}

resource "azurerm_public_ip" "vnet_gateway" {
  name                = "pip-vgw-azure-stackit-site-to-site-vpn"
  location            = azurerm_resource_group.site_to_site_vpn.location
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name
  sku                 = "Standard"

  allocation_method = "Static"
}

resource "azurerm_virtual_network_gateway" "site_to_site_vpn" {
  name                = "vgw-azure-stackit-site-to-site-vpn"
  location            = azurerm_resource_group.site_to_site_vpn.location
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  sku = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vnet_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

resource "azurerm_local_network_gateway" "stackit" {
  name                = "lgw-stackit"
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name
  location            = azurerm_resource_group.site_to_site_vpn.location
  gateway_address     = stackit_public_ip.vpn_gateway.ip
  address_space       = [one(stackit_network_area.main.network_ranges).prefix]
}

resource "random_password" "shared_key" {
  length = 32
}

resource "azurerm_virtual_network_gateway_connection" "stackit" {
  name                       = "con-stackit"
  location                   = azurerm_resource_group.site_to_site_vpn.location
  resource_group_name        = azurerm_resource_group.site_to_site_vpn.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.site_to_site_vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.stackit.id
  shared_key                 = random_password.shared_key.result
  connection_mode            = "ResponderOnly"

  ipsec_policy {
    dh_group         = "ECP384"
    ike_encryption   = "GCMAES256"
    ike_integrity    = "SHA384"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "ECP384"
    sa_lifetime      = 27000
  }
}

# Test resources

resource "azurerm_subnet" "test" {
  name                 = "TestSubnet"
  resource_group_name  = azurerm_resource_group.site_to_site_vpn.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_security_group" "test" {
  name                = "nsg-subnet-test"
  location            = azurerm_resource_group.site_to_site_vpn.location
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "test" {
  subnet_id                 = azurerm_subnet.test.id
  network_security_group_id = azurerm_network_security_group.test.id
}

resource "azurerm_public_ip" "test" {
  name                = "pip-vm-test"
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name
  location            = azurerm_resource_group.site_to_site_vpn.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "test" {
  name                = "nic-vm-test"
  location            = azurerm_resource_group.site_to_site_vpn.location
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test.id
  }
}

resource "azurerm_linux_virtual_machine" "test" {
  name                = "vm-test"
  resource_group_name = azurerm_resource_group.site_to_site_vpn.name
  location            = azurerm_resource_group.site_to_site_vpn.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.test.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
