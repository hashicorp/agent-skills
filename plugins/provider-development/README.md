# Terraform Provider Development

## Terraform plugin framework

The plugin framework is HashiCorp’s recommended way develop to Terraform Plugins on [protocol version 6](/terraform/plugin/terraform-plugin-protocol#protocol-version-6) or [protocol version 5](/terraform/plugin/terraform-plugin-protocol#protocol-version-5). 

### Get Started

- Try the [/terraform/tutorials/providers-plugin-framework](https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider).
- If you're starting from scratch building a new provider, clone the [terraform-provider-scaffolding-framework](https://github.com/hashicorp/terraform-provider-scaffolding-framework) template repository on GitHub.

### Key Concepts

- [Provider Servers](/terraform/plugin/framework/provider-servers) encapsulate all Terraform plugin details and handle all calls for provider, resource, and data source operations by implementing the [Terraform Plugin Protocol](/terraform/plugin/how-terraform-works#terraform-plugin-protocol). They are implemented as binaries that the Terraform CLI downloads, starts, and stops.
- [Providers](/terraform/plugin/framework/providers) are the top level abstraction that define the available resources and data sources for practitioners to use and may accept its own configuration, such as authentication information.
- [Schemas](/terraform/plugin/framework/handling-data/schemas) define available fields for provider, resource, or provisioner configuration block, and give Terraform metadata about those fields.
- [Resources](/terraform/plugin/framework/resources) are an abstraction that allow Terraform to manage infrastructure objects, such as a compute instance, an access policy, or disk. Providers act as a translation layer between Terraform and an API, offering one or more resources for practitioners to define in a configuration.
- [Data Sources](/terraform/plugin/framework/data-sources) are an abstraction that allow Terraform to reference external data. Providers have data sources that tell Terraform how to request external data and how to convert the response into a format that practitioners can interpolate.
- [Functions](/terraform/plugin/framework/functions) are an abstraction that allow Terraform to reference computational logic. Providers can implement their own custom logic functions to augment the Terraform configuration language [built-in functions](/terraform/language/functions).

### Test and Publish

- Learn to write [acceptance tests](/terraform/plugin/framework/acctests) for your provider.
- Learn to [publish your provider](/terraform/registry/providers/publishing) to the Terraform Registry.

### Combine or Translate

- [Combine your provider with other SDKv2 providers](/terraform/plugin/mux/combining-protocol-version-5-providers) using [protocol version 5](/terraform/plugin/how-terraform-works#protocol-version-5).
- [Combine your provider with other framework providers](/terraform/plugin/mux/combining-protocol-version-6-providers) using [protocol version 6](/terraform/plugin/how-terraform-works#protocol-version-6).
