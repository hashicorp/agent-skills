# Terraform Plugin Framework reference

## Using Plugin Framework

* Terraform Plugin Framework is a Go module:
  github.com/hashicorp/terraform-plugin-framework
* Terraform Plugin Framework is most often paired with the plugin testing
  module for authoring acceptance tests:
  github.com/hashicorp/terraform-plugin-testing

## Feature types

| Feature Type | Go interface | Notes |
| ------------- | -------------- | -------------- |
| Resource | resource.Resource | Also called a "managed resource" |
| Data source | datasource.DataSource | |
| List resource | list.ListResource | |
| Provider action | action.Action | |
| Ephmeral resource | ephemeral.EphmemeralReource | |

A feature may support more function by implementing optional interfaces in the
respective Go package, such as resource.ResourceWithIdentity.

## Developer documentation

- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Resource Development](https://developer.hashicorp.com/terraform/plugin/framework/resources)
- [Data Source Development](https://developer.hashicorp.com/terraform/plugin/framework/data-sources)
