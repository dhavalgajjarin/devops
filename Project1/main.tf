terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.34.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "e9c93904-c316-4f60-a1b3-fc5ae575878f"
  tenant_id       = "624a0ea3-8660-4927-96de-a646f74ad52b"
  client_id       = "0feeb28b-8afe-4960-8e65-4c7f823bc736"
  client_secret   = "Z~r8Q~vq5lLuxXDRjWnMlh9zLn6KcmZ09sH~GcA2"
}

resource "azurerm_resource_group" "devops" {
  name     = "devops-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "devops" {
  name                = "devops-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name
}

resource "azurerm_subnet" "devops" {
  name                 = "devops-subnet"
  resource_group_name  = azurerm_resource_group.devops.name
  virtual_network_name = azurerm_virtual_network.devops.name
  address_prefixes     = ["10.0.9.0/24"]
}

resource "azurerm_ssh_public_key" "devops" {
  name                = "devops"
  resource_group_name = azurerm_resource_group.devops.name
  location            = azurerm_resource_group.devops.location
  public_key          = file("~/.ssh/id_rsa.pub")
}

resource "azurerm_network_security_group" "devops" {
  name                = "devops-nsg"
  resource_group_name = azurerm_resource_group.devops.name
  location            = azurerm_resource_group.devops.location

  security_rule {
    name                       = "SSH"
    priority                   = 100
    access                     = "Allow"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }
  security_rule {
    name                       = "HTTP"
    priority                   = 101
    access                     = "Allow"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }
  security_rule {
    name                       = "Jenkins"
    priority                   = 102
    access                     = "Allow"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "8080"
  }

}

// Master
resource "azurerm_public_ip" "master" {
  name                = "master-public-ip"
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "master" {
  name                = "master-nic"
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name

  ip_configuration {
    name                          = "master-ip"
    subnet_id                     = azurerm_subnet.devops.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.master.id
  }
}

resource "azurerm_network_interface_security_group_association" "master" {
  network_interface_id      = azurerm_network_interface.master.id
  network_security_group_id = azurerm_network_security_group.devops.id
}

resource "azurerm_virtual_machine" "master" {
  name                             = "Master"
  location                         = azurerm_resource_group.devops.location
  resource_group_name              = azurerm_resource_group.devops.name
  vm_size                          = "Standard_D2s_v3"
  network_interface_ids            = [azurerm_network_interface.master.id]
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  storage_os_disk {
    name              = "master-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "master"
    admin_username = "azureuser"
    admin_password = "Password@123"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = azurerm_ssh_public_key.devops.public_key
    }
  }

}

// Slave 1
resource "azurerm_public_ip" "slave1" {
  name                = "slave1-public-ip"
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "slave1" {
  name                = "slave1-nic"
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name

  ip_configuration {
    name                          = "slave1-ip"
    subnet_id                     = azurerm_subnet.devops.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.slave1.id
  }
}

resource "azurerm_network_interface_security_group_association" "slave1" {
  network_interface_id      = azurerm_network_interface.slave1.id
  network_security_group_id = azurerm_network_security_group.devops.id
}

resource "azurerm_virtual_machine" "slave1" {
  name                             = "Slave1"
  location                         = azurerm_resource_group.devops.location
  resource_group_name              = azurerm_resource_group.devops.name
  vm_size                          = "Standard_D2s_v3"
  network_interface_ids            = [azurerm_network_interface.slave1.id]
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  storage_os_disk {
    name              = "slave1-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "slave1"
    admin_username = "azureuser"
    admin_password = "Password@123"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = azurerm_ssh_public_key.devops.public_key
    }
  }

}

// Slave 2
resource "azurerm_public_ip" "slave2" {
  name                = "slave2-public-ip"
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "slave2" {
  name                = "slave2-nic"
  location            = azurerm_resource_group.devops.location
  resource_group_name = azurerm_resource_group.devops.name

  ip_configuration {
    name                          = "slave2-ip"
    subnet_id                     = azurerm_subnet.devops.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.slave2.id
  }
}

resource "azurerm_network_interface_security_group_association" "slave2" {
  network_interface_id      = azurerm_network_interface.slave2.id
  network_security_group_id = azurerm_network_security_group.devops.id
}

resource "azurerm_virtual_machine" "slave2" {
  name                             = "Slave2"
  location                         = azurerm_resource_group.devops.location
  resource_group_name              = azurerm_resource_group.devops.name
  vm_size                          = "Standard_D2s_v3"
  network_interface_ids            = [azurerm_network_interface.slave2.id]
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  storage_os_disk {
    name              = "slave2-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "slave2"
    admin_username = "azureuser"
    admin_password = "Password@123"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = azurerm_ssh_public_key.devops.public_key
    }
  }

}
