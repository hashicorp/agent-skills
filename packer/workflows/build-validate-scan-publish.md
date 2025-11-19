# Workflow: Build → Validate → Scan → Publish

1. Init
   - Ensure creds via env; never commit secrets
   - `packer fmt` and `packer validate`

2. Build
   - `packer build -var-file=vars/<env>.pkrvars.hcl .`
   - Collect logs and manifest

3. SBOM + Scan
   - Generate SBOM and run vulnerability scanner
   - Fail on high/critical unless approved exception

4. Publish
   - Push to HCP Packer registry bucket
   - Attach metadata (SBOM URI, scan summary, git SHA)

5. Review & Approve
   - Human approval gate for promotion to `staging`/`prod`

6. Promote
   - Promote version to channel; notify consumers (Terraform modules)

7. Verify
   - Smoke tests using instance launch and basic health checks