# Terraform Plugin SDKv2 reference

## Using Plugin SDKv2

* Terraform Plugin SDKv2 is a Go module:
  github.com/hashicorp/terraform-plugin-sdk/v2
* Terraform Plugin SDKv2 is most often paired with the plugin testing
  module for authoring acceptance tests:
  github.com/hashicorp/terraform-plugin-testing
* Plugin Framework is recommended over Plugin SDKv2 for net-new providers and
  net-new features. Plugin SDKv2 may continue to be used as needed.

## Feature types

* A resource type -- also called a managed resource type -- is a Go type that
  implements the `resource.Resource` interface. A resource may support more
  functionality by implementing optional interfaces in the `resource` package.
  * Specifically, a resource type can support newer Terraform features by
    implementing Resource Identity, using the `resource.ResourceWithIdentity`
    package. This is recommended for net-new resources.
* A data source type -- also called a managed resource type -- is a Go type that
  implements the `datasource.DataSource` interface. A data source may support more
  functionality by implementing optional interfaces in the `resource` package.
* A list resource type is a Go type that implements the `list.ListResource`
  interface. A list resource may support more functionality by implementing
  optional interfaces in the `list` package.
* A provider action type is a Go type that implements the `action.Action`
  interface. A provider action may support more functionality by implementing
  optional interfaces in the `action` package. Provider Actions are only available in Plugin Framework, and not in the legacy Plugin SDKv2.
* An ephemeral resource type is a Go type that implements the
  `ephemeral.EphmemeralReource` interface. An ephemeral resource may support
  more functionality by implementing optional interfaces in the `ephemeral`
  package.
## Developer documentation

- [Terraform Plugin SDKv2](https://developer.hashicorp.com/terraform/plugin/sdkv2)
- [Resource Development](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources)
- [Resource Identity](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources/identity)
- [List Resources](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources/list)
- [Data Source Development](https://developer.hashicorp.com/terraform/plugin/framework/data-sources)


