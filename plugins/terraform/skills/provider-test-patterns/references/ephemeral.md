# Ephemeral Resource Testing Reference

Testing patterns for ephemeral resources using `terraform-plugin-testing`.
Ephemeral resources reference external data without persisting it to plan or
state artifacts, which means standard plan checks and state checks cannot
directly assert on ephemeral resource data.

Source: [Ephemeral Resource Acceptance Tests](https://developer.hashicorp.com/terraform/plugin/testing/acceptance-tests/ephemeral-resources)

**Requires Terraform >= 1.10.0** — gate all ephemeral tests with
`tfversion.SkipBelow(tfversion.Version1_10_0)`.

---

## Table of Contents

1. [Testing Approaches](#testing-approaches)
2. [Direct Integration Testing](#direct-integration-testing)
3. [Echo Provider Pattern](#echo-provider-pattern)
4. [Multi-Step Testing](#multi-step-testing)

---

## Testing Approaches

Two strategies for testing ephemeral resources:

| Approach | When to use |
|----------|-------------|
| **Direct integration** | Verify the ephemeral resource successfully provides data to a dependent resource or provider |
| **Echo provider** | Assert on specific attribute values using `ConfigStateChecks` via the `echoprovider` package |

---

## Direct Integration Testing

Test that an ephemeral resource successfully provides data to a dependent
resource. No direct assertions on ephemeral data — the test passes if the
dependent resource applies cleanly.

```go
func TestExampleCloudSecret_DnsKerberos(t *testing.T) {
    resource.UnitTest(t, resource.TestCase{
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_10_0),
        },
        ExternalProviders: map[string]resource.ExternalProvider{
            "dns": {
                Source: "hashicorp/dns",
            },
        },
        ProtoV5ProviderFactories: map[string]func() (tfprotov5.ProviderServer, error){
            "examplecloud": providerserver.NewProtocol5WithError(New()),
        },
        Steps: []resource.TestStep{
            {
                Config: `
ephemeral "examplecloud_secret" "krb" {
  name = "example_kerberos_user"
}

provider "dns" {
  update {
    server = "ns.example.com"
    gssapi {
      realm    = ephemeral.examplecloud_secret.krb.secret_data.realm
      username = ephemeral.examplecloud_secret.krb.secret_data.username
      password = ephemeral.examplecloud_secret.krb.secret_data.password
    }
  }
}

resource "dns_a_record_set" "record_set" {
  zone = "example.com."
  addresses = ["192.168.0.1", "192.168.0.2", "192.168.0.3"]
}
                `,
            },
        },
    })
}
```

---

## Echo Provider Pattern

The `echoprovider` package (Protocol V6) captures ephemeral data into a
managed resource's state, making it assertable with standard
`ConfigStateChecks`.

### Setup

Register both your provider and the echo provider:

```go
import (
    "github.com/hashicorp/terraform-plugin-testing/echoprovider"
)

func TestExampleCloudSecret(t *testing.T) {
    resource.UnitTest(t, resource.TestCase{
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_10_0),
        },
        ProtoV5ProviderFactories: map[string]func() (tfprotov5.ProviderServer, error){
            "examplecloud": providerserver.NewProtocol5WithError(New()),
        },
        ProtoV6ProviderFactories: map[string]func() (tfprotov6.ProviderServer, error){
            "echo": echoprovider.NewProviderServer(),
        },
        Steps: []resource.TestStep{
            // test configurations
        },
    })
}
```

### Config Pattern

Pass ephemeral data to the echo provider's `data` attribute, then assert on
the `echo` managed resource:

```terraform
ephemeral "examplecloud_secret" "krb" {
  name = "example_kerberos_user"
}

provider "echo" {
  data = ephemeral.examplecloud_secret.krb.secret_data
}

resource "echo" "test_krb" {}
```

### State Assertions

Assert on the echo resource's `data` attribute using standard state checks:

```go
Steps: []resource.TestStep{
    {
        Config: `...`,
        ConfigStateChecks: []statecheck.StateCheck{
            statecheck.ExpectKnownValue("echo.test_krb",
                tfjsonpath.New("data").AtMapKey("realm"),
                knownvalue.StringExact("EXAMPLE.COM")),
            statecheck.ExpectKnownValue("echo.test_krb",
                tfjsonpath.New("data").AtMapKey("username"),
                knownvalue.StringExact("john-doe")),
            statecheck.ExpectKnownValue("echo.test_krb",
                tfjsonpath.New("data").AtMapKey("password"),
                knownvalue.StringRegexp(regexp.MustCompile(`^.{12}$`))),
        },
    },
},
```

---

## Multi-Step Testing

The echo resource has special behavior to accommodate ephemeral data
variability:

- During planning for new resources, the `data` attribute is marked unknown
- Existing echo resources preserve prior state regardless of config changes
- Refresh operations always return prior state

Because of this, **create new echo resource instances for each test step**
rather than reusing the same one:

```go
Steps: []resource.TestStep{
    {
        Config: `
ephemeral "examplecloud_secret" "krb" {
  name = "user_one"
}
provider "echo" {
  data = ephemeral.examplecloud_secret.krb
}
resource "echo" "test_krb_one" {}
        `,
        ConfigStateChecks: []statecheck.StateCheck{
            statecheck.ExpectKnownValue("echo.test_krb_one",
                tfjsonpath.New("data").AtMapKey("name"),
                knownvalue.StringExact("user_one")),
        },
    },
    {
        Config: `
ephemeral "examplecloud_secret" "krb" {
  name = "user_two"
}
provider "echo" {
  data = ephemeral.examplecloud_secret.krb
}
resource "echo" "test_krb_two" {}
        `,
        ConfigStateChecks: []statecheck.StateCheck{
            statecheck.ExpectKnownValue("echo.test_krb_two",
                tfjsonpath.New("data").AtMapKey("name"),
                knownvalue.StringExact("user_two")),
        },
    },
},
```
