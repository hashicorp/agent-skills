# DoTest Pattern Examples

Complete examples of the DoTest pattern for Vault tests.

## Basic Example: Identity Entity Test

### Test Logic (non-test file)

```go
// vault/external_tests/identity/tests/do_test_entity.go
package tests

import (
    "testing"

    "github.com/hashicorp/vault/sdk/helper/testcluster"
    "github.com/stretchr/testify/require"
)

// DoTestEntityCreate tests entity creation via API
// This file does NOT end in _test.go so it compiles quickly
func DoTestEntityCreate(t *testing.T, cluster testcluster.VaultCluster) {
    t.Helper()
    
    client := cluster.Nodes()[0].APIClient()
    
    // Create entity
    resp, err := client.Logical().Write("identity/entity", map[string]interface{}{
        "name": "test-entity",
        "metadata": map[string]string{
            "team": "foundations",
        },
    })
    require.NoError(t, err)
    require.NotNil(t, resp)
    
    entityID := resp.Data["id"].(string)
    require.NotEmpty(t, entityID)
    
    // Read entity back
    resp, err = client.Logical().Read("identity/entity/id/" + entityID)
    require.NoError(t, err)
    require.Equal(t, "test-entity", resp.Data["name"])
}

// DoTestEntityAlias tests alias creation
func DoTestEntityAlias(t *testing.T, cluster testcluster.VaultCluster) {
    t.Helper()
    
    client := cluster.Nodes()[0].APIClient()
    
    // First create entity
    entityResp, err := client.Logical().Write("identity/entity", map[string]interface{}{
        "name": "alias-test-entity",
    })
    require.NoError(t, err)
    entityID := entityResp.Data["id"].(string)
    
    // Enable userpass for alias mount
    err = client.Sys().EnableAuthWithOptions("userpass", &api.EnableAuthOptions{
        Type: "userpass",
    })
    require.NoError(t, err)
    
    // Get mount accessor
    mounts, err := client.Sys().ListAuth()
    require.NoError(t, err)
    accessor := mounts["userpass/"].Accessor
    
    // Create alias
    _, err = client.Logical().Write("identity/entity-alias", map[string]interface{}{
        "name":           "testuser",
        "canonical_id":   entityID,
        "mount_accessor": accessor,
    })
    require.NoError(t, err)
}
```

### NewTestCluster Test

```go
// vault/external_tests/identity/cluster_test.go
package identity_test

import (
    "testing"

    "github.com/hashicorp/vault/helper/teststorage"
    "github.com/hashicorp/vault/vault"
    "github.com/hashicorp/vault/vault/external_tests/identity/tests"
)

func TestEntityCreate(t *testing.T) {
    t.Parallel()
    
    conf, opts := teststorage.ClusterSetup(nil, nil, nil)
    opts.NumCores = 1  // Single node is sufficient
    
    cluster := vault.NewTestCluster(t, &conf, &opts)
    t.Cleanup(cluster.Cleanup)
    
    tests.DoTestEntityCreate(t, cluster)
}

func TestEntityAlias(t *testing.T) {
    t.Parallel()
    
    conf, opts := teststorage.ClusterSetup(nil, nil, nil)
    opts.NumCores = 1
    
    cluster := vault.NewTestCluster(t, &conf, &opts)
    t.Cleanup(cluster.Cleanup)
    
    tests.DoTestEntityAlias(t, cluster)
}
```

### Docker Cluster Test

```go
// vault/external_tests/identity/binary/docker_test.go
package binary

import (
    "os"
    "testing"

    "github.com/hashicorp/vault/sdk/helper/testcluster/docker"
    "github.com/hashicorp/vault/vault/external_tests/identity/tests"
)

func TestEntityCreate(t *testing.T) {
    if os.Getenv("RUN_DOCKER_TESTS") == "" {
        t.Skip("Set RUN_DOCKER_TESTS=1 to run docker tests")
    }
    
    cluster := docker.NewDockerCluster(t, &docker.DockerClusterOptions{
        ImageTag: "latest",
        NumCores: 1,
    })
    t.Cleanup(cluster.Cleanup)
    
    tests.DoTestEntityCreate(t, cluster)
}
```

## Advanced Example: Replication Test

```go
// vault/external_tests/replication/tests/do_test_replication.go
package tests

import (
    "testing"
    "time"

    "github.com/hashicorp/vault/sdk/helper/testcluster"
    "github.com/stretchr/testify/require"
)

// DoTestReplicationBasic verifies data replicates between clusters
func DoTestReplicationBasic(t *testing.T, primary, secondary testcluster.VaultCluster) {
    t.Helper()
    
    primaryClient := primary.Nodes()[0].APIClient()
    secondaryClient := secondary.Nodes()[0].APIClient()
    
    // Write secret to primary
    _, err := primaryClient.Logical().Write("secret/data/test", map[string]interface{}{
        "data": map[string]string{
            "key": "value",
        },
    })
    require.NoError(t, err)
    
    // Wait for replication
    time.Sleep(2 * time.Second)
    
    // Read from secondary
    resp, err := secondaryClient.Logical().Read("secret/data/test")
    require.NoError(t, err)
    require.NotNil(t, resp)
    
    data := resp.Data["data"].(map[string]interface{})
    require.Equal(t, "value", data["key"])
}
```

## File Organization Summary

```
vault/external_tests/identity/
├── tests/
│   ├── do_test_entity.go       # DoTestEntityCreate, DoTestEntityAlias
│   └── do_test_group.go        # DoTestGroupCreate, etc.
├── cluster_test.go             # TestEntityCreate, TestGroupCreate (NewTestCluster)
└── binary/
    └── docker_test.go          # TestEntityCreate (Docker)
```

## Key Points

1. **DoTestX files don't end in `_test.go`** - They compile separately from test dependencies
2. **Accept `testcluster.VaultCluster` interface** - Works with any cluster implementation
3. **Use only API client** - Never access Core or internal state
4. **TestX files wrap DoTestX** - Handle cluster creation/cleanup
5. **Skip docker tests by default** - Use env var to opt-in
