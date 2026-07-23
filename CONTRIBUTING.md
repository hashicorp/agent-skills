# Contributing

This repository is currently internal-contribution-only. HashiCorp employees and
approved internal collaborators may propose changes. This guidance does not
invite general external contributions; external contribution support requires a
future governance change.

## Review model

Structural validation, Skill review, private Waza evaluation, `CODEOWNERS`, and
maintainer review are complementary inputs. Passing one does not replace the
others. `CODEOWNERS` is the canonical ownership and review-routing source.
Product-aligned reviewers assess product correctness and recommended workflows;
`@hashicorp/team-agent-skills-ecosystem` owns repository conventions,
evaluation, distribution, supported-model and marketplace consistency, and
final repository decisions.

## Propose a new Skill or substantial rewrite

Open the internal new-Skill request template before implementation. The
proposal must identify:

- target product, bundle, Skill area, and user workflow;
- authoritative HashiCorp product documentation, release notes, or approved
  product sources;
- an inclusion driver: product novelty, supported-model capability,
  cross-model consistency, durable workflow, governance or safety, or
  opinionated product guidance;
- supported-model impact, proposed owner, and applicable product-, feature-,
  service-, workflow-, or integration-aligned reviewers;
- distribution and bundle impact;
- security, privacy, licensing, credential-handling, and operational concerns;
- a private Waza evaluation plan with routing, functional, and risk coverage.

A Waza plan is required, but passing results are advisory during the current
evaluation phase. Proposals that are too broad, stale, duplicative, unsupported
by an approved source, unowned, unevaluable, or inconsistent with model,
distribution, or marketplace policy must be rejected or deferred.

Infrastructure mutation, access control, credentials, security posture, or
production operations require explicit security, credential, and operational
review plus matching evaluation cases. Fast-changing product behavior requires
current authoritative sources and targeted evaluation. Cross-product Skills
require ecosystem-team ownership, reviewers for each affected workflow when
applicable, and an explicit decision to use one bundle, multiple bundles, or a
future governed distribution structure. Defer work until any required owner or
reviewer participation is confirmed.

## Add a new Skill

After proposal acceptance:

1. Add the Skill under `plugins/<product>/skills/<skill-name>/` with `name`,
   `description`, and `metadata.lifecycle-status` frontmatter.
2. Add the Skill to `SKILLS.md`, its product bundle, and `CODEOWNERS`.
3. Add private evaluation assets under `proj-agent-skills/evals/<skill-name>/`;
   do not commit eval tasks, fixtures, transcripts, or raw results here.
4. Record the product source, supported-model impact, owner and reviewers,
   security review, and distribution impact in the pull request.
5. Run structural, Skill, example, link, installation, and applicable harness
   checks.

## Update an existing Skill

Describe the affected product, bundle, Skill, user workflow, authoritative
source, ownership, evaluation evidence, supported-model impact, security
considerations, and marketplace impact. Update private acceptance scenarios
before changing behavior. Review or reevaluate the Skill whenever it changes or
the supported model matrix changes.

## Remove a Skill

Follow the governed lifecycle: `active`, `deprecation-candidate`, `deprecated`,
then `retired`. Normal retirement requires owner approval, replacement guidance
when applicable, non-telemetry usage/support review, and paired supported-model
evidence. The default deprecation window is three months after the deprecation
change merges and must align with a release cycle. Emergency security or safety
removal must record the reason, approving owner, date, and mitigation.

Remove a retired Skill from `SKILLS.md`, `CODEOWNERS`, individual installation,
both product manifests, and both marketplaces. A historical copy may remain
only in a clearly non-installable archive.

## Other repository changes

Pull requests may also update product READMEs, plugin or marketplace manifests,
validation workflows, private Waza integration references, supporting Skill
resources, repository governance, or supported-model and marketplace policy.
Explain the affected contract and keep both marketplace targets aligned.
Governance-policy changes must first be reconciled in the project context
repository.

## Pull request checklist

Use `.github/pull_request_template.md`. Run:

```bash
./scripts/validate-structure.sh
git diff --check
```

Also run targeted executable-example checks, link checks, both marketplace
installation checks when plugin definitions change, and private paired Waza
runs when required by the project evaluation plan. Never use real production
credentials or create real infrastructure for repository fixtures.
