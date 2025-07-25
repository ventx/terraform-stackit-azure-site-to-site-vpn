<a name="ventx_logo" href="https://ventx.de">![ventx logo](logo.svg)</a>

# STACKIT Azure Site-to-Site VPN

This project creates a site-to-site VPN between STACKIT and Azure. The STACKIT side uses a small VM running LibreSwan, while the Azure side utilizes an Azure VNet Gateway with the `VpnGw1` SKU (the `Basic` SKU just supports the deprecated Diffie-Hellman group 2).

## Prerequisites

A STACKIT service account with owner permissions at the organization level is needed. If you don't have one already, follow these steps:

1. In the resource manager, create a dummy project within your STACKIT organization where the service account lives (e. g. `dummy-project`).
2. In the resource manager, switch to the newly created project and create a service account.
3. Create a service account key for the service account and save it.
4. In the resource manager, switch to your STACKIT organization and assign the owner role to the service account.

The following tools need to be available on the machine that shall run the code:

* Terraform / OpenTofu
* curl
* truncate

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.37.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7.2 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | ~> 0.58.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.37.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_stackit"></a> [stackit](#provider\_stackit) | 0.58.1 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_local_network_gateway.stackit](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway) | resource |
| [azurerm_public_ip.vnet_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.site_to_site_vpn](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subnet.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_gateway.site_to_site_vpn](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) | resource |
| [azurerm_virtual_network_gateway_connection.stackit](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) | resource |
| [random_password.shared_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [stackit_image.alpine](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/image) | resource |
| [stackit_key_pair.vpn_gateway](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/key_pair) | resource |
| [stackit_network.site_to_site_vpn](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network) | resource |
| [stackit_network_area.main](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_area) | resource |
| [stackit_network_area_route.site_to_site_vpn](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_area_route) | resource |
| [stackit_network_interface.vpn_gateway](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/network_interface) | resource |
| [stackit_public_ip.vpn_gateway](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/public_ip) | resource |
| [stackit_resourcemanager_project.site_to_site_vpn](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_project) | resource |
| [stackit_security_group.site_to_site_vpn](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/security_group) | resource |
| [stackit_security_group_rule.allow_internal_traffic_to_vpn_gateway_network](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/security_group_rule) | resource |
| [stackit_server.vpn_gateway](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/server) | resource |
| [terraform_data.alpine_image](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Your Azure subscription ID. | `string` | n/a | yes |
| <a name="input_owner_email"></a> [owner\_email](#input\_owner\_email) | Your email address. | `string` | n/a | yes |
| <a name="input_public_key_path"></a> [public\_key\_path](#input\_public\_key\_path) | Path to your SSH key public key. | `string` | n/a | yes |
| <a name="input_stackit_organization_id"></a> [stackit\_organization\_id](#input\_stackit\_organization\_id) | Your STACKIT organization ID. | `string` | n/a | yes |
| <a name="input_stackit_service_account_key_path"></a> [stackit\_service\_account\_key\_path](#input\_stackit\_service\_account\_key\_path) | Path to your STACKIT service account key JSON file. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

## Usage

1. Make sure the prerequisites are met.
2. Assign values to the variables (e. g. through a `.tfvars` file or environment variables).
3. Adjust the IP ranges of the `stackit_network_area.main` and `stackit_network.site_to_site_vpn` resources to match your needs.
4. Adjust the IP ranges of the `azurerm_virtual_network.main` and `azurerm_subnet.gateway` resources to match your needs.
5. Run `terraform plan` / `tofu plan` and check if the plan matches your expectations.
6. Run `terraform apply` / `tofu apply` to deploy the infrastructure.


## Benchmark

    test-server:~$ iperf3 -c 10.0.0.4
    Connecting to host 10.0.0.4, port 5201
    [  5] local 10.1.0.3 port 56648 connected to 10.0.0.4 port 5201
    [ ID] Interval           Transfer     Bitrate         Retr  Cwnd
    [  5]   0.00-1.00   sec  72.2 MBytes   605 Mbits/sec  517   2.06 MBytes
    [  5]   1.00-2.00   sec  69.8 MBytes   585 Mbits/sec    0   2.18 MBytes
    [  5]   2.00-3.00   sec  74.5 MBytes   625 Mbits/sec    0   2.27 MBytes
    [  5]   3.00-4.00   sec  79.1 MBytes   664 Mbits/sec    0   2.34 MBytes
    [  5]   4.00-5.00   sec  80.9 MBytes   678 Mbits/sec    0   2.39 MBytes
    [  5]   5.00-6.00   sec  77.4 MBytes   649 Mbits/sec    0   2.43 MBytes
    [  5]   6.00-7.00   sec  78.1 MBytes   655 Mbits/sec    0   2.45 MBytes
    [  5]   7.00-8.00   sec  79.6 MBytes   668 Mbits/sec    0   2.47 MBytes
    [  5]   8.00-9.00   sec  80.1 MBytes   672 Mbits/sec    0   2.47 MBytes
    [  5]   9.00-10.00  sec  73.8 MBytes   619 Mbits/sec    0   2.47 MBytes
    - - - - - - - - - - - - - - - - - - - - - - - - -
    [ ID] Interval           Transfer     Bitrate         Retr
    [  5]   0.00-10.00  sec   766 MBytes   642 Mbits/sec  517            sender
    [  5]   0.00-10.02  sec   764 MBytes   640 Mbits/sec                  receiver

    iperf Done.

## Support

If you need help with the usage of this project, feel free to create an issue. For help with STACKIT in general, contact us at stackit@ventx.de and we'll see how we can assist you on your journey with STACKIT 😊

Need help with anything else? Come visit us at [ventx.de](https://ventx.de) to get an overview of what we have to offer!

## Roadmap

Ideas for the future:

* Create a branch where the Azure side also uses a small VM with LibreSwan instead of the Azure VNet Gateway, as the `VpnGw1` SKU can be a bit expensive (~120€ per month) if you just want to do small tests.

## Contributing

Ideas for improvements? Create an issue or a pull request!
