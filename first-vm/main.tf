terraform {
  required_providers {
    azurerm = {
      version = "~>2.23.0"

    }

  }
}

# Configure the Microsoft Azure Provider.
provider "azurerm" {
        features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     =  "${var.prefix}TFRG"
  location =  var.location
  tags     = var.tags
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}TFVnet"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}TFSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes    = var.subnet_address_prefix
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                = "${var.prefix}TFPublicIP"
  location            = "westus2"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}TFNSG"
  location            = "westus2"
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                      = "${var.prefix}NIC"
  location                  = "westus2"
  resource_group_name       = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.prefix}NICConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.prefix}TFVM"
  location              = "westus2"
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "${var.prefix}OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = lookup(var.sku, var.location)
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.prefix}TFVM"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  provisioner "file" {
        connection {
            type     = "ssh"
            host     = azurerm_public_ip.publicip.ip_address
            user     = var.admin_username
            password = var.admin_password
        }

        source      = "newfile.txt"
        destination = "newfile.txt"
    }

    provisioner "remote-exec" {
        connection {
            type     = "ssh"
            host     = azurerm_public_ip.publicip.ip_address
            user     = var.admin_username
            password = var.admin_password
        }

        inline = [
        "ls -a",
        "cat newfile.txt"
        ]
    }
}

output "public_ip_address" {
  value = azurerm_public_ip.publicip.ip_address
}
