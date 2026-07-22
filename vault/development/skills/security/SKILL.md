---
name: vault-security
description: Implement security-critical features in HashiCorp Vault. Use when working with authentication, authorization, secrets handling, cryptography, input validation, audit logging, or error message sanitization. Ensures security best practices are followed.
compatibility: Requires Go 1.22+, crypto/subtle for comparisons
---

# Vault Security

## Security-First Mindset

Vault is a **security product**. Vulnerabilities expose customer secrets in production.

**Core principles**:
1. Assume all input is malicious until validated
2. Never log secrets or sensitive data
3. Validate at all boundaries (API, storage, cache)
4. Fail securely (deny by default)
5. Use constant-time comparisons for secrets
6. Sanitize error messages

## Critical Rules

### 1. Logging Rules

#### 1.1 Use `github.com/hashicorp/go-hclog` for logging

```go
type JwtAuthManager struct {
 // logger for operations
 logger hclog.Logger
}
```

#### 1.2 Never log secrets

```go
// ❌ WRONG
log.Printf("Token: %s", token)
log.Printf("Processing: %+v", req)  // req may contain secrets

// ✅ CORRECT
log.Printf("Token received")
log.Printf("Processing request for entity %s", entityID)
```

#### 1.3 Never log information on user requests

If the code path is directly encountered on a user request,
do not log info statements. Only log errors and debug statements if required.

### 2. Constant-Time Comparisons

```go
// ❌ WRONG - timing attack vulnerable
if token == expectedToken {
    // grant access
}

// ✅ CORRECT
import "crypto/subtle"

if subtle.ConstantTimeCompare([]byte(token), []byte(expectedToken)) == 1 {
    // grant access
}
```

### 3. Input Validation

Always validate at API boundaries:

```go
func CreateEntity(ctx context.Context, name string) error {
    // Validate
    if name == "" {
        return fmt.Errorf("entity name cannot be empty")
    }
    if len(name) > 512 {
        return fmt.Errorf("entity name too long")
    }
    if !validNamePattern.MatchString(name) {
        return fmt.Errorf("entity name contains invalid characters")
    }

    // Process validated input
}
```

### 4. Sanitize Error Messages

```go
// ❌ WRONG - leaks sensitive info
return fmt.Errorf("authentication failed: invalid token %s", token)

// ✅ CORRECT
return fmt.Errorf("authentication failed")
```

## Authentication Patterns

```go
func ValidateToken(ctx context.Context, token string) (*TokenEntry, error) {
    // Never log token
    if token == "" {
        return nil, fmt.Errorf("empty token")
    }

    te, err := c.tokenStore.Lookup(ctx, token)
    if err != nil {
        return nil, fmt.Errorf("token lookup failed")  // Generic error
    }
    if te == nil {
        return nil, fmt.Errorf("invalid token")
    }

    if te.IsExpired() {
        return nil, fmt.Errorf("token expired")
    }

    return te, nil
}
```

## Cryptographic Operations

```go
import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"  // Use crypto/rand, NEVER math/rand
)

func Encrypt(plaintext, key []byte) ([]byte, error) {
    block, err := aes.NewCipher(key)
    if err != nil {
        return nil, err
    }

    // Use GCM for authenticated encryption
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, err
    }

    // Generate random nonce
    nonce := make([]byte, gcm.NonceSize())
    if _, err := rand.Read(nonce); err != nil {
        return nil, err
    }

    return gcm.Seal(nonce, nonce, plaintext, nil), nil
}
```

## Security Checklist

Before submitting code:

- [ ] No secrets in logs or error messages
- [ ] Input validated at all boundaries
- [ ] Constant-time comparisons for secrets
- [ ] Error messages don't leak info
- [ ] Using `crypto/rand` not `math/rand`
- [ ] Sensitive data cleared from memory
- [ ] Audit logging for sensitive operations
- [ ] Rate limiting considered for endpoints
- [ ] Authentication requirements enforced
- [ ] ACL checks before privileged operations

## Input Validation Patterns

**Validate at write-time** (config creation) to prevent runtime failures:

```go
// Separate validation functions for testability
func validateJWKSUri(jwksUri string, warnings *[]string) error {
    if jwksUri == "" {
        return fmt.Errorf("JWKS URI is empty")
    }

    parsed, err := url.Parse(jwksUri)
    if err != nil {
        return fmt.Errorf("invalid JWKS URI: %w", err)
    }

    if !parsed.IsAbs() {
        return fmt.Errorf("JWKS URI must be absolute URL")
    }

    // Warning (non-blocking) vs Error (blocking)
    if parsed.Scheme == "http" {
        *warnings = append(*warnings, "JWKS URI uses http:// - insecure")
    }

    return nil
}

// Integration in handler
func (b *Backend) handleConfigWrite(ctx context.Context, req *logical.Request, data *framework.FieldData) (*logical.Response, error) {
    var warnings []string

    // Blocking validation
    if err := validateJWKSUri(uri, &warnings); err != nil {
        return logical.ErrorResponse(err.Error()), nil
    }

    // Store config...

    // Return with warnings if any
    if len(warnings) > 0 {
        return &logical.Response{Warnings: warnings}, nil
    }
    return nil, nil
}
```

## Responsible Disclosure

**If you discover a security vulnerability**:

1. **DO NOT** create public GitHub issue
2. **DO NOT** discuss in public channels
3. **DO** email <security@hashicorp.com>
4. **DO** include detailed reproduction steps
5. **DO** wait for security team response
