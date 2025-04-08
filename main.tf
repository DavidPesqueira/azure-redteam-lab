# Azure Red Team Lab - Terraform Main Config

provider "azurerm" {
  features {}
}

variable "location" {
  default = "eastus"
}

variable "admin_username" {
  default = "labadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for admin access"
}
  
resource "azurerm_resource_group" "rg" {
  name     = "redteam-lab-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "redteam-lab-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "redteam-lab-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "lab-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "YOUR.IP.ADDRESS.HERE/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "lab-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab_ip.id
  }
}

resource "azurerm_public_ip" "lab_ip" {
  name                = "lab-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "lab_vm" {
  name                = "redteam-lab-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Kali-Linux"
    offer     = "kali"
    sku       = "kali"
    version   = "latest"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y havoc screen",
      "screen -dmS systemd-logger /usr/bin/havoc teamserver"
    ]
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      host        = azurerm_public_ip.lab_ip.ip_address
    }
  }
}

output "public_ip" {
  value = azurerm_public_ip.lab_ip.ip_address
}
