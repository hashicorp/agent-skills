---
name: terraform-configuration-upload
description: >-
  Inspect and, when explicitly requested, upload a reviewed private Terraform
  staging directory to an existing HCP Terraform or Terraform Enterprise
  workspace. Use when a reviewed Terraform configuration must be uploaded
  without Terraform CLI configuration while keeping credentials and signed
  upload URLs internal.
license: MPL-2.0
metadata:
  lifecycle-status: active
  copyright: Copyright IBM Corp. 2026
  version: "0.1.0"
  compatibility: Requires Bash, jq, and standard macOS/Linux utilities; upload mode additionally requires curl
---

# Terraform Configuration Upload

This Skill supports offline file-list inspection and explicit HCP Terraform
configuration uploads. It does not create runs, inspect plans, apply changes, or
retrieve logs or state.

## Responsibilities

| Owner | Responsibility |
| --- | --- |
| Skill / agent | Select reviewed paths, invoke staging, review the file list, and approve the target and upload |
| Staging helper | Copy only explicitly selected source paths into staging |
| Upload helper | Validate staging, create the archive, and perform the upload |
| Downstream tool | Receive only the configuration-version ID |

The selected directory must be a private staging directory containing only the
reviewed Terraform configuration files. Do not copy an entire repository into
staging. Preserve the relative paths required by local modules.

The upload helper does not copy or filter the source repository. It validates
the caller-prepared staging directory and creates one private temporary `tar.gz`
archive with validated files at the archive root after upload approval. Approval
of the file list is not cryptographic proof that file contents cannot change
before packaging.

## Included files and safety rules

The upload helper reports regular files below the staging root in sorted
relative path order. It rejects, rather than silently hides, unsafe entries
including:

- `.git/` and `.terraform/`;
- Terraform state and backup state files;
- crash logs;
- `.env` files;
- Terraform CLI credentials;
- recognized key and credential-like files;
- symlinks and special files; and
- unsafe or unsupported relative paths.

The helper also enforces fixed file-count and byte limits so inspection and
upload remain bounded.

`.terraformignore` is not interpreted in this version and must not be copied
into staging. If it is present in staging, validation fails. The file list is
not equivalent to Terraform CLI or HCP Terraform's native configuration
packaging rules.

## Workflow

1. Identify the HTTPS endpoint, organization, workspace, and source
   configuration.
2. Create an owner-private temporary staging directory and invoke the bundled
   staging helper with explicit source-relative paths. Preserve local-module
   paths such as `modules/example/main.tf`; do not recursively copy a repository
   root:

   ```bash
   scripts/stage_configuration.sh \
     --source-root "$SOURCE_ROOT" \
     --staging-root "$STAGING_DIR" \
     --include main.tf \
     --include modules/example
   ```

3. Inspect the staging directory offline:

   ```bash
   scripts/upload_configuration.sh \
     --configuration-root "$STAGING_DIR" \
     --inspect
   ```

4. Review the returned sorted `files` list and `file_count`. Confirm that the
   endpoint, organization, workspace, and upload operation are also approved.
5. After separate explicit upload approval, run:

   ```bash
   scripts/upload_configuration.sh \
     --configuration-root "$STAGING_DIR" \
     --organization "$ORG" \
     --workspace "$WORKSPACE" \
     --address "$ADDRESS" \
     --upload
   ```

   `TFE_TOKEN` must already be supplied by the protected environment; never
   pass it as a command argument.
6. Treat nonzero exit as no usable handoff. The helper revalidates the staging
   directory, creates a private `tar.gz` archive whose members are at the
   archive root, verifies its regular members, creates a speculative
   non-auto-queued configuration version, uploads the archive through the signed
   URL, waits for `uploaded`, and removes only its internal temporary files. The
   caller must remove the exact caller-owned `STAGING_DIR` after success,
   failure, or cancellation.

## Output

Inspection returns only bounded file metadata, for example:

```json
{
  "status": "ready",
  "files": ["main.tf", "modules/example/main.tf"],
  "file_count": 2
}
```

Successful upload returns only sanitized handoff facts:

```json
{
  "configuration_version_id": "cv-abc123",
  "upload_status": "uploaded",
  "file_count": 2,
  "archive_bytes": 18342
}
```

The token, signed URL, raw API responses, archive path, archive content, and
Terraform configuration contents must not be passed to downstream tools or
included in output or diagnostics.

Pass only `configuration_version_id` to a separately approved `create_run`
operation with `run_type` set to `plan_only`. This Skill does not create that
Run.

## Validation

Run the bundled local tests:

```bash
scripts/test_stage_configuration.sh
scripts/test_upload_configuration.sh
scripts/test_upload_configuration_mock.sh
```

The upload tests cover inspection output, archive-member validation, unsafe-path
rejection, private staging validation, size limits, the mocked API lifecycle,
and credential/signed-URL containment.

The staging tests cover explicit file and directory selection, local-module path
preservation, unselected-file exclusion, empty selections, overlapping roots,
private permissions, size limits, nested sensitive paths, and symlink rejection.

## Known limitations

- This version uses staging-directory and file-list approval rather than
  digest-bound approval. Canonical manifest and exact archive digest approval
  are future options.
- `.terraformignore` is not supported.
- `.terraform/modules` is rejected with `.terraform`.
- No HCL dependency discovery occurs outside the selected root.
- Workspace creation, variables, policies, Runs, Plans, Apply, logs, state, and
  Git cloning are out of scope.
