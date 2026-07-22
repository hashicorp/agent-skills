# Cluster Setup Reference

Options and configurations for Vault test clusters.

## teststorage.ClusterSetup

The standard way to get cluster configuration:

```go
import "github.com/hashicorp/vault/helper/teststorage"

func TestExample(t *testing.T) {
    conf, opts := teststorage.ClusterSetup(nil, nil, nil)
    cluster := vault.NewTestCluster(t, &conf, &opts)
    t.Cleanup(cluster.Cleanup)
}
```

### Parameters

```go
func ClusterSetup(
    conf *vault.CoreConfig,        // nil for defaults
    opts *vault.TestClusterOptions, // nil for defaults  
    setup *teststorage.SetupOpts,   // nil for defaults
) (vault.CoreConfig, vault.TestClusterOptions)
```

## CoreConfig Options

```go
conf := vault.CoreConfig{
    // Logger configuration
    Logger: logging.NewVaultLogger(hclog.Debug),
    
    // Disable default policies
    DisableMlock: true,
    
    // Custom seal (usually not needed)
    Seal: seal,
    
    // Physical storage backend
    Physical: physicalBackend,
    
    // Enable specific features
    EnableUI: true,
    
    // License (EE only)
    LicensePath: "/path/to/license",
}
```

## TestClusterOptions

```go
opts := vault.TestClusterOptions{
    // Number of nodes (default: 3)
    NumCores: 1,
    
    // HTTP handler (REQUIRED for API access)
    HandlerFunc: vaulthttp.Handler,
    
    // Skip initialization
    SkipInit: false,
    
    // Keep standbys sealed
    KeepStandbysSealed: false,
    
    // Custom ports
    BaseListenAddress: "127.0.0.1",
    BaseClusterPort:   0, // random
    
    // TLS configuration  
    TLSDisable: false,
    
    // Temp directory for data
    TempDir: t.TempDir(),
    
    // Plugins
    PluginDirectory: "/path/to/plugins",
}
```

## Common Configurations

### Single Node (Simplest)

```go
conf, opts := teststorage.ClusterSetup(nil, nil, nil)
opts.NumCores = 1

cluster := vault.NewTestCluster(t, &conf, &opts)
```

### With Custom Logger

```go
import "github.com/hashicorp/go-hclog"

logger := hclog.New(&hclog.LoggerOptions{
    Name:  "test",
    Level: hclog.Debug,
})

conf := vault.CoreConfig{
    Logger: logger,
}

_, opts := teststorage.ClusterSetup(&conf, nil, nil)
cluster := vault.NewTestCluster(t, &conf, &opts)
```

### With Plugins

```go
opts := vault.TestClusterOptions{
    NumCores:        1,
    HandlerFunc:     vaulthttp.Handler,
    PluginDirectory: "/path/to/plugins",
}

conf, _ := teststorage.ClusterSetup(nil, &opts, nil)
cluster := vault.NewTestCluster(t, &conf, &opts)
```

### Replication Setup

For replication testing (perf replication, DR replication, or full 4-group topology), see [REPLICATION_TESTING.md](REPLICATION_TESTING.md).

## minimal.NewTestSoloCluster

Convenience function for single-node clusters:

```go
import "github.com/hashicorp/vault/vault/minimal"

func TestSimple(t *testing.T) {
    cluster := minimal.NewTestSoloCluster(t)
    t.Cleanup(cluster.Cleanup)
    
    client := cluster.Cores[0].Client
    // Test with client
}
```

## Waiting for Cluster Ready

After creating a cluster, wait for it to be active:

```go
cluster := vault.NewTestCluster(t, &conf, &opts)
t.Cleanup(cluster.Cleanup)

// Get the active core
core := cluster.Cores[0].Core
vault.TestWaitActive(t, core)

// Now safe to use
client := cluster.Cores[0].Client
```

## Storage Backends

### In-Memory (Default)

```go
conf, opts := teststorage.ClusterSetup(nil, nil, nil)
// Uses inmem by default
```

### Consul

```go
setup := &teststorage.SetupOpts{
    StorageBackend: teststorage.ConsulBackend,
}

conf, opts := teststorage.ClusterSetup(nil, nil, setup)
```

### Raft

```go
setup := &teststorage.SetupOpts{
    StorageBackend: teststorage.RaftBackend,
}

conf, opts := teststorage.ClusterSetup(nil, nil, setup)
```

## Docker Cluster Options

```go
import "github.com/hashicorp/vault/sdk/helper/testcluster/docker"

cluster := docker.NewDockerCluster(t, &docker.DockerClusterOptions{
    ImageRepo: "hashicorp/vault",
    ImageTag:  "latest",
    NumCores:  1,
    
    // Network configuration
    NetworkName: "vault-test",
    
    // Volume mounts
    VolumeBinds: []string{
        "/host/path:/container/path",
    },
    
    // Environment variables
    Env: []string{
        "VAULT_LOG_LEVEL=debug",
    },
})
```

## Exec Cluster Options

```go
import "github.com/hashicorp/vault/sdk/helper/testcluster/exec"

cluster := exec.NewTestExecDevCluster(t, &exec.ExecDevClusterOptions{
    NumCores:   1,
    BinaryPath: "/path/to/vault",
    
    // Additional CLI args
    Args: []string{"-dev-root-token-id=root"},
})
```
