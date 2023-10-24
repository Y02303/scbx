terraform {
  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
	features {}
}

resource "azurerm_resource_group" "vmss" {
	name     = var.resource_group_name
	location = var.location
	tags     = var.tags
}

resource "random_string" "fqdn" {
	length  = 6
	special = false
	upper   = false
	numeric  = false
}

resource "azurerm_virtual_network" "vmss" {
	name                = "vmss-vnet"
	address_space       = ["10.0.0.0/16"]
	location            = var.location
	resource_group_name = azurerm_resource_group.vmss.name
	tags                = var.tags
}

resource "azurerm_subnet" "vmss" {
	name                 = "vmss-subnet"
	resource_group_name  = azurerm_resource_group.vmss.name
	virtual_network_name = azurerm_virtual_network.vmss.name
	address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vmss" {
	name                         = "vmss-public-ip"
	location                     = var.location
	resource_group_name          = azurerm_resource_group.vmss.name
	allocation_method            = "Static"
	domain_name_label            = random_string.fqdn.result
	tags                         = var.tags
}

resource "azurerm_lb" "vmss" {
	name                = "vmss-lb"
	location            = var.location
	resource_group_name = azurerm_resource_group.vmss.name

	frontend_ip_configuration {
		name                 = "PublicIPAddress"
		public_ip_address_id = azurerm_public_ip.vmss.id
	}

	tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
	loadbalancer_id     = azurerm_lb.vmss.id
	name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
	resource_group_name = azurerm_resource_group.vmss.name
	loadbalancer_id     = azurerm_lb.vmss.id
	name                = "http-probe"
	protocol = "http"
	request_path = "/"
	port                = "8080" #var.application_port
}

resource "azurerm_lb_rule" "lbnatrule" {
	resource_group_name            = azurerm_resource_group.vmss.name
	loadbalancer_id                = azurerm_lb.vmss.id
	name                           = "http"
	protocol                       = "Tcp"
	frontend_port                  = var.application_port
	backend_port                   = "8080"
	backend_address_pool_ids        = [azurerm_lb_backend_address_pool.bpepool.id]
	frontend_ip_configuration_name = "PublicIPAddress"
	probe_id                       = azurerm_lb_probe.vmss.id
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmscaleset"
  resource_group_name = azurerm_resource_group.vmss.name
  location            = var.location
  sku                 = "Standard_DS1_v2"
  instances           = 1
  admin_username      = var.admin_user
	health_probe_id = azurerm_lb_probe.vmss.id
	custom_data = base64encode(file("web.conf"))
  admin_ssh_key {
    username   = var.admin_user
    public_key = file("mykey.pub")

  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "terraformnetworkprofile"
    primary = true
		network_security_group_id = azurerm_network_security_group.web.id

    ip_configuration {
      name      = "IPConfiguration"
      primary   = true
      subnet_id = azurerm_subnet.vmss.id
			load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
    }
  }

 tags = var.tags
}




# resource "azurerm_public_ip" "jumpbox" {
# 	name                         = "jumpbox-public-ip"
# 	location                     = var.location
# 	resource_group_name          = azurerm_resource_group.vmss.name
# 	allocation_method            = "Static"
# 	domain_name_label            = "${random_string.fqdn.result}-ssh"
# 	tags                         = var.tags
# }

# resource "azurerm_network_interface" "jumpbox" {
# 	name                = "jumpbox-nic"
# 	location            = var.location
# 	resource_group_name = azurerm_resource_group.vmss.name

# 	ip_configuration {
# 		name                          = "IPConfiguration"
# 		subnet_id                     = azurerm_subnet.vmss.id
# 		private_ip_address_allocation = "dynamic"
# 		public_ip_address_id          = azurerm_public_ip.jumpbox.id
# 	}

# 	tags = var.tags
# }

# resource "azurerm_virtual_machine" "jumpbox" {
# 	name                  = "jumpbox"
# 	location              = var.location
# 	resource_group_name   = azurerm_resource_group.vmss.name
# 	network_interface_ids = [azurerm_network_interface.jumpbox.id]
# 	vm_size               = "Standard_DS1_v2"

# 	storage_image_reference {
# 		publisher = "Canonical"
# 		offer     = "0001-com-ubuntu-server-focal"
# 		sku       = "20_04-lts"
# 		version   = "latest"
# 	}

# 	storage_os_disk {
# 		name              = "jumpbox-osdisk"
# 		caching           = "ReadWrite"
# 		create_option     = "FromImage"
# 		managed_disk_type = "Standard_LRS"
# 	}

# 	os_profile {
# 		computer_name  = "jumpbox"
# 		admin_username = var.admin_user
# 	}

# 	os_profile_linux_config {
#    disable_password_authentication = true
# 	 ssh_keys {
# 		 key_data = file("mykey.pub")
# 		 path = "/home/azureuser/.ssh/authorized_keys"
# 	 }
# 	}

# 	tags = var.tags
# }

# resource "azurerm_network_interface_security_group_association" "jumpbox" {
#   network_interface_id      = azurerm_network_interface.jumpbox.id
#   network_security_group_id = azurerm_network_security_group.allow-ssh.id
# }


resource "azurerm_network_security_group" "web" {
  name                = "web-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmss.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# resource "azurerm_network_security_group" "allow-ssh" {
#   name                = "allow-ssh-nsg"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.vmss.name

#   security_rule {
#     name                       = "SSH"
#     priority                   = 1001
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
# }