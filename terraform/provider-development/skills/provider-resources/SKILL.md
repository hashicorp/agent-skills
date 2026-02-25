---
name: provider-resources
description: |
    Add a new feature type to an existing Terraform Provider. Use this skill to
    add a resource, data source, list resource, a provider action, an ephemeral
    resource, or a provider-defined function.
copyright: Copyright IBM Corp. 2026
version: "0.0.1"
---

# Terraform Provider feature implementation

## Provider framework categorization

* If the Go module has a dependency on github.com/hashicorp/terraform-plugin-mux, then it is a combined Framework and SDKv2 provider.
  * Typically, the developer will maintain existing resources in SDKv2 and author net-new resources in
  Framework, although there can be exceptions.
* Else, if the Go module has a dependency on github.com/hashicorp/terraform-plugin-framework, then
  it is a Framework provider, and all resources will be Framework resources.
  * [Plugin Framework reference](references/plugin-framework.md)
* Else, it is an SDKv2 provider, and all resources will be SDKv2 resources.
  * [Plugin SDKv2 reference](references/plugin-sdk-v2.md)

## Agent resource recommendations

* The run-acceptance-tests skill in github.com/hashicorp/agent-skills

## Pre-Submission Checklist

- [ ] Code compiles without errors
- [ ] All tests pass locally
- [ ] All dependencies are up-to-date
- [ ] Resource has all CRUD operations implemented and acceptance tested
- [ ] Import is implemented and acceptance tested
- [ ] A "disappears" acceptance test is included
- [ ] Documentation is complete with examples
- [ ] Error messages are clear and actionable
- [ ] Sensitive attributes are marked
- [ ] Validators cover edge cases
