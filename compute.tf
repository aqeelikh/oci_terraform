variable "num_instances" {
  default = "2"
}

variable "instance_shape" {
  default = "VM.Standard.E2.1.Micro"
}

variable "instance_ocpus" {
  default = 1
}

variable "instance_shape_config_memory_in_gbs" {
  default = 1
}

variable "instance_image_ocid" {
  type = map(string)

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.5-2018.10.16-0"

    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaa32voyikkkzfxyo4xbdmadc2dmvorfxxgdhpnk6dw64fa3l4jh7wa"
  }
}

variable "flex_instance_image_ocid" {
  type = map(string)
  default = {
    me-jeddah-1 = "ocid1.image.oc1.me-jeddah-1.aaaaaaaaigq4wmjqotllhajk4ffw7l262supgi25fa4p43li5qtthqdyckka"
  }
}


resource "oci_core_instance" "test_instance" {
  count               = var.num_instances
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "TestInstance-${count.index + 1}"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.test_subnet.id
    display_name     = "Primaryvnic"
    assign_public_ip = true
    hostname_label   = "tfexampleinstance${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = var.flex_instance_image_ocid[var.region]
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = true
    is_monitoring_disabled   = true
    plugins_config {
      name          = "Compute Instance Monitoring"
      desired_state = "ENABLED"
    }
  }
}

resource "oci_core_vcn" "test_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "TestVcn"
  dns_label      = "testvcn"
}

resource "oci_core_internet_gateway" "test_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "TestInternetGateway"
  vcn_id         = oci_core_vcn.test_vcn.id
}

resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = oci_core_vcn.test_vcn.default_route_table_id
  display_name               = "DefaultRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.test_internet_gateway.id
  }
}

resource "oci_core_subnet" "test_subnet" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  cidr_block          = "10.1.20.0/24"
  display_name        = "TestSubnet"
  dns_label           = "testsubnet"
  security_list_ids   = [oci_core_vcn.test_vcn.default_security_list_id]
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.test_vcn.id
  route_table_id      = oci_core_vcn.test_vcn.default_route_table_id
  dhcp_options_id     = oci_core_vcn.test_vcn.default_dhcp_options_id
}

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

data "oci_computeinstanceagent_instance_agent_plugins" "test_instance_agent_plugins" {
  compartment_id   = var.compartment_ocid
  instanceagent_id = oci_core_instance.test_instance.0.id
}

output "agent_plugins" {
  value = [data.oci_computeinstanceagent_instance_agent_plugins.test_instance_agent_plugins]
}

variable "instance_available_plugin_os_name" {
  default = "Oracle Linux"
}

variable "instance_available_plugin_os_version" {
  default = "7.8"
}


data "oci_computeinstanceagent_instance_available_plugins" "test_instance_available_plugins" {
  #Required
  compartment_id = var.compartment_ocid
  os_name        = var.instance_available_plugin_os_name
  os_version     = var.instance_available_plugin_os_version
}

output "available_plugins" {
  value = [data.oci_computeinstanceagent_instance_available_plugins.test_instance_available_plugins]
}
