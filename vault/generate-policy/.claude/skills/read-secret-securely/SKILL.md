# Skill: Read Secret Securely

## Overview
This skill guides AI agents in implementing secure secret retrieval patterns from HashiCorp Vault, focusing on authentication, authorization, secure handling, and proper secret lifecycle management.

## Capability Statement
The agent will implement secure secret access patterns that:
- Use appropriate authentication methods for the context
- Handle secrets in memory without logging
- Implement proper error handling and retry logic
- Respect secret TTLs and rotation schedules
- Use response wrapping for sensitive operations
- Minimize secret exposure surface area

## Prerequisites
- Vault cluster access (URL and port)
- Valid authentication credentials
- Understanding of secret engine types
- Knowledge of application deployment context

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `auth_method` | string | Yes | Authentication method (token, approle, kubernetes, aws, etc.) |
| `secret_path` | string | Yes | Full path to secret |
| `secret_engine` | string | Yes | Type of secret engine (kv, database, aws, pki) |
| `runtime_environment` | string | Yes | Execution context (cli, application, ci/cd) |
| `language` | string | No | Programming language for code examples |

## Execution Steps

### 1. Choose Authentication Method

```markdown
**Authentication Method Selection**

| Method | Use Case | Security Level |
|--------|----------|----------------|
| Token | CLI, development | Medium |
| AppRole | Applications, automation | High |
| Kubernetes | K8s pods | High |
| AWS IAM | AWS resources | High |
| GitHub | GitHub Actions | Medium-High |
| TLS Certificate | mTLS authentication | High |
```

### 2. Authenticate to Vault

#### Token Authentication (Development)
```bash
# Environment variable
export VAULT_TOKEN="hvs.CAESIF..."

# Or read from file
export VAULT_TOKEN=$(cat ~/.vault-token)
```

#### AppRole Authentication (Production Applications)
```python
import hvac
import os

def authenticate_approle():
    """Authenticate using AppRole"""
    client = hvac.Client(url=os.getenv('VAULT_ADDR'))
    
    role_id = os.getenv('VAULT_ROLE_ID')
    secret_id = os.getenv('VAULT_SECRET_ID')
    
    # Read secret_id from file if not in environment
    if not secret_id:
        with open('/var/run/secrets/vault-secret-id', 'r') as f:
            secret_id = f.read().strip()
    
    response = client.auth.approle.login(
        role_id=role_id,
        secret_id=secret_id
    )
    
    # Store token for subsequent requests
    client.token = response['auth']['client_token']
    
    # Optionally store token lifetime for renewal
    return client, response['auth']['lease_duration']
```

#### Kubernetes Authentication
```python
def authenticate_kubernetes():
    """Authenticate using Kubernetes service account"""
    client = hvac.Client(url=os.getenv('VAULT_ADDR'))
    
    # Read service account JWT
    with open('/var/run/secrets/kubernetes.io/serviceaccount/token', 'r') as f:
        jwt = f.read()
    
    role = os.getenv('VAULT_K8S_ROLE', 'my-app')
    
    response = client.auth.kubernetes.login(
        role=role,
        jwt=jwt
    )
    
    client.token = response['auth']['client_token']
    return client
```

### 3. Read Secret Securely

#### KV Secrets (Version 2)
```python
def read_kv_secret(client, path, mount_point='secret'):
    """
    Securely read KV secret
    
    Args:
        client: Authenticated Vault client
        path: Secret path (without 'data/' prefix)
        mount_point: KV mount point
    
    Returns:
        dict: Secret data
    """
    try:
        # Read secret
        response = client.secrets.kv.v2.read_secret_version(
            path=path,
            mount_point=mount_point
        )
        
        # Extract data
        secret_data = response['data']['data']
        
        # Log access (without secret values)
        print(f"Successfully retrieved secret from {mount_point}/{path}")
        
        return secret_data
        
    except hvac.exceptions.InvalidPath:
        print(f"Secret not found: {mount_point}/{path}")
        return None
    except hvac.exceptions.Forbidden:
        print(f"Permission denied: {mount_point}/{path}")
        return None
    except Exception as e:
        print(f"Error reading secret: {str(e)}")
        return None

# Usage
db_creds = read_kv_secret(client, 'database/prod/postgres')
if db_creds:
    username = db_creds['username']
    password = db_creds['password']
    # Use credentials without logging
```

#### Dynamic Database Credentials
```python
def get_database_credentials(client, role_name, mount_point='database'):
    """
    Generate dynamic database credentials
    
    Args:
        client: Authenticated Vault client
        role_name: Database role name
        mount_point: Database mount point
    
    Returns:
        tuple: (username, password, lease_id, lease_duration)
    """
    try:
        response = client.secrets.database.generate_credentials(
            name=role_name,
            mount_point=mount_point
        )
        
        username = response['data']['username']
        password = response['data']['password']
        lease_id = response['lease_id']
        lease_duration = response['lease_duration']
        
        print(f"Generated dynamic credentials (lease: {lease_duration}s)")
        
        return username, password, lease_id, lease_duration
        
    except Exception as e:
        print(f"Error generating credentials: {str(e)}")
        raise

# Usage with automatic renewal
username, password, lease_id, ttl = get_database_credentials(client, 'readonly-prod')

# Store lease ID for renewal
```

#### AWS Credentials
```python
def get_aws_credentials(client, role_name, mount_point='aws'):
    """Get temporary AWS credentials"""
    try:
        response = client.secrets.aws.generate_credentials(
            name=role_name,
            mount_point=mount_point
        )
        
        return {
            'access_key': response['data']['access_key'],
            'secret_key': response['data']['secret_key'],
            'security_token': response['data'].get('security_token'),
            'lease_id': response['lease_id'],
            'lease_duration': response['lease_duration']
        }
    except Exception as e:
        print(f"Error generating AWS credentials: {str(e)}")
        raise
```

### 4. Secure Secret Handling

#### In-Memory Only
```python
import os
from typing import Dict

class SecureSecret:
    """Handle secrets securely in memory"""
    
    def __init__(self, data: Dict[str, str]):
        self._data = data
    
    def get(self, key: str) -> str:
        """Retrieve secret value"""
        return self._data.get(key)
    
    def __repr__(self) -> str:
        """Prevent accidental logging"""
        return "<SecureSecret [REDACTED]>"
    
    def __str__(self) -> str:
        """Prevent accidental logging"""
        return "<SecureSecret [REDACTED]>"
    
    def __del__(self):
        """Zero out memory on deletion"""
        if hasattr(self, '_data'):
            # Overwrite values before deletion
            for key in self._data:
                self._data[key] = None
            self._data.clear()

# Usage
secret = SecureSecret(read_kv_secret(client, 'app/config'))
password = secret.get('password')

# Use password...

# Clean up
del secret
```

#### Avoid Logging Secrets
```python
import logging
from functools import wraps

def redact_secrets(func):
    """Decorator to redact secrets from logs"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            result = func(*args, **kwargs)
            # Never log the actual result
            logging.info(f"{func.__name__} completed successfully")
            return result
        except Exception as e:
            logging.error(f"{func.__name__} failed: {type(e).__name__}")
            raise
    return wrapper

@redact_secrets
def process_secret(secret_data):
    """Process secret data"""
    # Work with secret
    pass
```

### 5. Lease Management

#### Token Renewal
```python
import threading
import time

class TokenRenewer:
    """Automatically renew Vault token"""
    
    def __init__(self, client, ttl):
        self.client = client
        self.ttl = ttl
        self.running = False
        self.thread = None
    
    def start(self):
        """Start renewal thread"""
        self.running = True
        self.thread = threading.Thread(target=self._renew_loop)
        self.thread.daemon = True
        self.thread.start()
    
    def stop(self):
        """Stop renewal thread"""
        self.running = False
        if self.thread:
            self.thread.join()
    
    def _renew_loop(self):
        """Renewal loop"""
        while self.running:
            # Renew at 50% of TTL
            sleep_time = self.ttl * 0.5
            time.sleep(sleep_time)
            
            if self.running:
                try:
                    response = self.client.auth.token.renew_self()
                    self.ttl = response['auth']['lease_duration']
                    print(f"Token renewed, new TTL: {self.ttl}s")
                except Exception as e:
                    print(f"Token renewal failed: {e}")
                    self.running = False

# Usage
renewer = TokenRenewer(client, ttl=3600)
renewer.start()

# ... application runs ...

renewer.stop()
```

#### Lease Renewal for Dynamic Secrets
```python
def renew_lease(client, lease_id, increment=None):
    """Renew a secret lease"""
    try:
        response = client.sys.renew_lease(
            lease_id=lease_id,
            increment=increment
        )
        new_ttl = response['lease_duration']
        print(f"Lease renewed, new TTL: {new_ttl}s")
        return new_ttl
    except hvac.exceptions.InvalidRequest:
        print("Lease cannot be renewed, fetch new credentials")
        return 0
    except Exception as e:
        print(f"Lease renewal error: {e}")
        raise

# Auto-renewal
def auto_renew_lease(client, lease_id, initial_ttl):
    """Automatically renew lease"""
    while True:
        # Renew at 50% of TTL
        time.sleep(initial_ttl * 0.5)
        initial_ttl = renew_lease(client, lease_id)
        if initial_ttl == 0:
            break
```

### 6. Response Wrapping

```python
def read_wrapped_secret(client, path, mount_point='secret'):
    """Read secret with response wrapping"""
    # Create wrapped response
    wrap_response = client.secrets.kv.v2.read_secret_version(
        path=path,
        mount_point=mount_point,
        wrap_ttl='60s'  # Wrapped token expires in 60s
    )
    
    wrap_token = wrap_response['wrap_info']['token']
    
    # Store or transmit wrap_token (not the actual secret)
    # ...
    
    # Unwrap to get secret (only once)
    unwrap_response = client.sys.unwrap(wrap_token)
    secret_data = unwrap_response['data']['data']
    
    return secret_data
```

### 7. Error Handling and Retry Logic

```python
import time
from functools import wraps

def retry_on_vault_error(max_attempts=3, backoff=2):
    """Retry decorator for Vault operations"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except hvac.exceptions.VaultDown:
                    if attempt < max_attempts - 1:
                        wait = backoff ** attempt
                        print(f"Vault down, retrying in {wait}s...")
                        time.sleep(wait)
                    else:
                        raise
                except hvac.exceptions.InvalidPath:
                    # Don't retry on invalid path
                    raise
                except hvac.exceptions.Forbidden:
                    # Don't retry on permission errors
                    raise
                except Exception as e:
                    if attempt < max_attempts - 1:
                        wait = backoff ** attempt
                        print(f"Error: {e}, retrying in {wait}s...")
                        time.sleep(wait)
                    else:
                        raise
        return wrapper
    return decorator

@retry_on_vault_error(max_attempts=3)
def fetch_secret_with_retry(client, path):
    """Fetch secret with automatic retry"""
    return read_kv_secret(client, path)
```

## Complete Example: Production Application

```python
#!/usr/bin/env python3
"""
Secure Vault secret access for production applications
"""

import hvac
import os
import sys
import threading
import time
from typing import Optional, Dict

class VaultClient:
    """Secure Vault client implementation"""
    
    def __init__(self):
        self.vault_addr = os.getenv('VAULT_ADDR')
        self.client: Optional[hvac.Client] = None
        self.token_ttl: int = 0
        self.renewer: Optional[threading.Thread] = None
        self.running = False
    
    def authenticate(self):
        """Authenticate using AppRole"""
        self.client = hvac.Client(url=self.vault_addr)
        
        role_id = os.getenv('VAULT_ROLE_ID')
        
        # Read secret_id from file (injected by orchestrator)
        with open('/var/run/secrets/vault-secret-id', 'r') as f:
            secret_id = f.read().strip()
        
        try:
            response = self.client.auth.approle.login(
                role_id=role_id,
                secret_id=secret_id
            )
            
            self.client.token = response['auth']['client_token']
            self.token_ttl = response['auth']['lease_duration']
            
            # Start token renewal
            self._start_token_renewal()
            
            print("✓ Authenticated to Vault")
            
        except Exception as e:
            print(f"✗ Authentication failed: {e}")
            sys.exit(1)
    
    def get_database_credentials(self, role: str) -> Dict[str, str]:
        """Get dynamic database credentials"""
        try:
            response = self.client.secrets.database.generate_credentials(
                name=role
            )
            
            return {
                'username': response['data']['username'],
                'password': response['data']['password'],
                'lease_id': response['lease_id'],
                'ttl': response['lease_duration']
            }
        except Exception as e:
            print(f"✗ Failed to get DB credentials: {e}")
            raise
    
    def get_application_config(self, path: str) -> Dict:
        """Get application configuration secrets"""
        try:
            response = self.client.secrets.kv.v2.read_secret_version(
                path=path,
                mount_point='secret'
            )
            return response['data']['data']
        except Exception as e:
            print(f"✗ Failed to read config: {e}")
            raise
    
    def _start_token_renewal(self):
        """Start background token renewal"""
        self.running = True
        self.renewer = threading.Thread(target=self._token_renewal_loop)
        self.renewer.daemon = True
        self.renewer.start()
    
    def _token_renewal_loop(self):
        """Background token renewal loop"""
        while self.running:
            # Renew at 50% of TTL
            sleep_time = max(self.token_ttl * 0.5, 60)
            time.sleep(sleep_time)
            
            if self.running:
                try:
                    response = self.client.auth.token.renew_self()
                    self.token_ttl = response['auth']['lease_duration']
                    print(f"✓ Token renewed (TTL: {self.token_ttl}s)")
                except Exception as e:
                    print(f"✗ Token renewal failed: {e}")
                    self.running = False
    
    def cleanup(self):
        """Clean up resources"""
        self.running = False
        if self.renewer:
            self.renewer.join(timeout=5)
        
        # Revoke token
        if self.client and self.client.token:
            try:
                self.client.auth.token.revoke_self()
                print("✓ Token revoked")
            except:
                pass

# Application usage
def main():
    vault = VaultClient()
    vault.authenticate()
    
    try:
        # Get application secrets
        config = vault.get_application_config('app/myapp/prod')
        api_key = config['api_key']
        
        # Get database credentials
        db_creds = vault.get_database_credentials('myapp-prod')
        
        # Use secrets...
        print("✓ Application running with Vault secrets")
        
        # Application main loop
        time.sleep(3600)
        
    finally:
        vault.cleanup()

if __name__ == '__main__':
    main()
```

## Best Practices

1. **Never Log Secrets**: Redact secret values from all logs
2. **Use Appropriate Auth**: Choose auth method matching deployment context
3. **Renew Tokens/Leases**: Implement automatic renewal
4. **Handle Errors Gracefully**: Retry transient errors, fail fast on auth issues
5. **Minimize TTL**: Request shortest acceptable TTL
6. **Use Response Wrapping**: For sensitive one-time secret delivery
7. **Clean Up**: Revoke tokens and leases when done
8. **Secure Transmission**: Use TLS for all Vault communication
9. **Memory Management**: Zero out secrets from memory when done
10. **Audit Access**: Log secret access (not values) for compliance

## Related Skills
- [Generate Policy](../generate-policy/SKILL.md)
- [Secret Rotation](../rotate-secrets/SKILL.md)

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-07 | Initial skill definition |
