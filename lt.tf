variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

# Configure the Azure Resource Manager Provider
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

# Create a resource group
resource "azurerm_resource_group" "lt" {
    name     = "lt"
    location = "West US"
}

# Create a virtual network in the web_servers resource group
resource "azurerm_virtual_network" "ltNetwork" {
  name                = "ltNetwork"
  address_space       = ["11.0.0.0/16"]
  location            = "West US"
  resource_group_name = "${azurerm_resource_group.lt.name}"
}

resource "azurerm_subnet" "public" {
    name = "public"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    virtual_network_name = "${azurerm_virtual_network.ltNetwork.name}"
    address_prefix = "11.0.1.0/24"
    network_security_group_id = "${azurerm_network_security_group.ltwebNSG.id}"
}

resource "azurerm_subnet" "private" {
    name = "private"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    virtual_network_name = "${azurerm_virtual_network.ltNetwork.name}"
    address_prefix = "11.0.3.0/24"
    network_security_group_id = "${azurerm_network_security_group.ltdbNSG.id}"
}

resource "azurerm_dns_zone" "azurelt" {
   name = "azr.zencloud.com"
   resource_group_name = "${azurerm_resource_group.lt.name}"
}

resource "azurerm_dns_a_record" "azurelt_a_web_pub" {
   name = "web_pub"
   zone_name = "${azurerm_dns_zone.azurelt.name}"
   resource_group_name = "${azurerm_resource_group.lt.name}"
   ttl = "300"
   records = ["${azurerm_public_ip.ltweb01pub.ip_address}"]
}

resource "azurerm_dns_a_record" "azurelt_a_web_pri" {
   name = "web_pri"
   zone_name = "${azurerm_dns_zone.azurelt.name}"
   resource_group_name = "${azurerm_resource_group.lt.name}"
   ttl = "300"
   records = ["${azurerm_network_interface.ltwebpudinter.private_ip_address}"]
}


resource "azurerm_dns_a_record" "zenlt_a_app" {
   name = "app"
   zone_name = "${azurerm_dns_zone.azurelt.name}"
   resource_group_name = "${azurerm_resource_group.lt.name}"
   ttl = "300"
   records = ["${azurerm_network_interface.ltdbpudinter.private_ip_address}"]
}

resource "azurerm_public_ip" "ltweb01pub" {
    name = "ltweb01pub"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    public_ip_address_allocation = "static"
    domain_name_label = "webpub"
}

resource "azurerm_network_interface" "ltwebpudinter" {
    name = "ltwebpudinter"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_id = "${azurerm_network_security_group.ltwebNSG.id}"

    ip_configuration {
        name = "ltconfiguration1"
        subnet_id = "${azurerm_subnet.public.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = "${azurerm_public_ip.ltweb01pub.id}"
        #load_balancer_backend_address_pools_ids = ["${azurerm_simple_lb.ltwebpudinter.                                     backend_pool_id}"]
    }
}

resource "azurerm_network_interface" "ltdbpudinter" {
    name = "ltdbpudinter"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.lt.name}"

    ip_configuration {
        name = "ltconfiguration1"
        subnet_id = "${azurerm_subnet.private.id}"
        private_ip_address_allocation = "dynamic"
    }
}

resource "azurerm_storage_account" "swebacnt" {
    name = "swebacnt"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    location = "westus"
    account_type = "Standard_LRS"
    tags {
        environment = "staging"
    }
}

resource "azurerm_storage_container" "swebcont" {
    name = "swebcont"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    storage_account_name = "${azurerm_storage_account.swebacnt.name}"
    container_access_type = "private"
}

resource "azurerm_storage_blob" "swebblob" {
    name = "swebblob.vhd"

    resource_group_name = "${azurerm_resource_group.lt.name}"
    storage_account_name = "${azurerm_storage_account.swebacnt.name}"
    storage_container_name = "${azurerm_storage_container.swebcont.name}"
    type = "page"
    size = 5120
}

resource "azurerm_virtual_machine" "weblt01" {
    name = "weblt01"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_interface_ids = ["${azurerm_network_interface.ltwebpudinter.id}"]
    vm_size = "Standard_A0"


    storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer = "WindowsServer"
        sku = "2008-R2-SP1"
        version = "latest"
    }

    storage_os_disk {
        name = "myosdisk1"
        vhd_uri = "${azurerm_storage_account.swebacnt.primary_blob_endpoint}${azurerm_storage_container.swebcont.name}/myosdisk1.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

    os_profile {
        computer_name = "weblt01"
        admin_username = "zenadmin"
        admin_password = "Redhat#12345"
    }

    os_profile_windows_config {
        enable_automatic_upgrades = false
    }

    tags {
        environment = "staging"
    }
}

resource "azurerm_storage_account" "sdbacnt" {
    name = "sdbacnt"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    location = "westus"
    account_type = "Standard_LRS"
        tags {
        environment = "staging"
    }
}

resource "azurerm_storage_container" "sdbcont" {
    name = "sdbcont"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    storage_account_name = "${azurerm_storage_account.sdbacnt.name}"
    container_access_type = "private"
}

resource "azurerm_storage_blob" "sdbblob" {
    name = "sdbblob.vhd"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    storage_account_name = "${azurerm_storage_account.sdbacnt.name}"
    storage_container_name = "${azurerm_storage_container.sdbcont.name}"
    type = "page"
    size = 5120
}

resource "azurerm_virtual_machine" "dblt01" {
    name = "dblt01"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_interface_ids = ["${azurerm_network_interface.ltdbpudinter.id}"]
    vm_size = "Standard_A0"

    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "14.04.2-LTS"
        version = "latest"
    }

    storage_os_disk {
        name = "myosdisk1"
        vhd_uri = "${azurerm_storage_account.sdbacnt.primary_blob_endpoint}${azurerm_storage_container.sdbcont.name}/myosdisk1.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

    os_profile {
        computer_name = "dblt01"
        admin_username = "zenadmin"
        admin_password = "Redhat#12345"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    tags {
        environment = "staging"
    }
}

resource "azurerm_network_security_group" "ltwebNSG" {
    name = "ltwebNSG"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.lt.name}"
}

resource "azurerm_network_security_rule" "HTTP" {
    name = "HTTP"
    priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "80"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltwebNSG.name}"
}

resource "azurerm_network_security_rule" "HTTPS" {
    name = "HTTPS"
    priority = 200
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "443"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltwebNSG.name}"
}

resource "azurerm_network_security_rule" "RDP-web" {
    name = "RDP-web"
    priority = 300
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = "3389"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltwebNSG.name}"
}

resource "azurerm_network_security_rule" "Winrm" {
    name = "Winrm"
    priority = 400
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "5985"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltwebNSG.name}"
}

resource "azurerm_network_security_rule" "HTTP-out" {
    name = "HTTP-out"
    priority = 100
        direction = "Outbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "0"
        destination_port_range = "65535"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltwebNSG.name}"
}

resource "azurerm_network_security_rule" "HTTPS-out" {
    name = "HTTPS-out"
    priority = 200
        direction = "Outbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "0"
        destination_port_range = "65535"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltwebNSG.name}"
}

resource "azurerm_network_security_rule" "Winrm-out" {
    name = "Winrm-out"
    priority = 300
        direction = "Outbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "5985"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltwebNSG.name}"
}


resource "azurerm_network_security_group" "ltdbNSG" {
    name = "ltdbNSG"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.lt.name}"
}

resource "azurerm_network_security_rule" "RDP-App" {
    name = "RDP-App"
    priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "3389"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltdbNSG.name}"
}

resource "azurerm_network_security_rule" "R1443" {
    name = "R1433"
    priority = 200
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "1443"
        source_address_prefix = "0.0.0.0"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.lt.name}"
    network_security_group_name = "${azurerm_network_security_group.ltdbNSG.name}"
}

output "Application URLs: " {
        value = "${azurerm_public_ip.ltweb01pub.ip_address}"
}

output "DNS entry" {
        value = "web_pub.azr.zencloud.com"
}
