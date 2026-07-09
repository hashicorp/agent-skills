---
name: run-acceptance-tests
description: Guide for running acceptance tests for a Terraform provider. Use this when asked to run an acceptance test or to run a test with the prefix `TestAcc`, when a test fails with missing environment variables, or when diagnosing a failing or suspiciously passing acceptance test.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

An acceptance test is a Go test function with the prefix `TestAcc`.

Before running: acceptance tests create **real infrastructure** against the
provider's live API, which may incur cost. Confirm the configured
credentials point at a test account before proceeding.

To run a focused acceptance test named `TestAccFeatureHappyPath`:

1. Run `go test -run=TestAccFeatureHappyPath -timeout 60m` with the
   following environment variables:
   - `TF_ACC=1`

   Default to non-verbose test output. Always pass an explicit `-timeout`:
   `go test` kills any test run after 10 minutes by default, and acceptance
   tests routinely exceed that.
1. The acceptance tests may require additional environment variables for
   specific providers. To discover which ones:
   - Read the test's `PreCheck` / `testAccPreCheck` function and search the
     test files: `grep -rn "os.Getenv" --include="*_test.go"`.
   - Check the repository's README, CONTRIBUTING, or `.env.example` for
     documented test setup.
   - The provider's `Configure` method shows how credentials are resolved;
     use the `provider-configuration` skill (if available) to understand a
     credential provider chain.

   Set the variables for the single test invocation
   (`EXAMPLE_API_KEY=... TF_ACC=1 go test ...`) rather than exporting them
   into the shell profile, and never write secret values into files inside
   the repository.

To diagnose a failing acceptance test, use these options, in order. These
options are cumulative: each option includes all the options above it.

1. Run the test again. Use the `-count=1` option to ensure that `go test` does
   not use a cached result.
1. Offer verbose `go test` output. Use the `-v` option.
1. Offer debug-level logging. Enable debug-level logging with the environment
   variable `TF_LOG=debug`.
1. Offer to persist the acceptance test's Terraform workspace. Enable
   persistence with the environment variable `TF_ACC_WORKING_DIR_PERSIST=1`.

A passing acceptance test may be a false negative. To "flip" a passing
acceptance test named `TestAccFeatureHappyPath`:

1. Edit the value of one of the TestCheckFuncs in one of the TestSteps in the
   TestCase.
1. Run the acceptance test. Expect the test to fail.
1. If the test fails, then undo the edit and report a successful flip. Else,
   keep the edit and report an unsuccessful flip.

If a test run is interrupted, real resources may be left behind; run the
provider's sweepers if it registers them (see the `provider-test-patterns`
skill's sweeper reference, if available). For writing or restructuring
tests, use the `provider-test-patterns` skill.
