# Terraform Code Quality Evaluation Report

**Feature**: `{{FEATURE_NAME}}`
**Evaluated**: `{{TIMESTAMP}}`
**Evaluator**: code-quality-judge (Claude Sonnet 4.5)
**Files Evaluated**: `{{FILE_COUNT}}` files
**Total Lines of Code**: ~`{{LOC_COUNT}}` lines

---

## Executive Summary

### Overall Code Quality Score: {{OVERALL_SCORE}}/10 - {{READINESS_BADGE}}

{{READINESS_BADGE}} options:
- ✅ **Production Ready** (8.0-10.0)
- ⚠️ **Minor Fixes Required** (6.0-7.9)
- ⚠️ **Significant Rework Needed** (4.0-5.9)
- ❌ **Not Production Ready** (0.0-3.9)

### Top 3 Strengths

1. ✅ {{STRENGTH_1}}
2. ✅ {{STRENGTH_2}}
3. ✅ {{STRENGTH_3}}

### Top 3 Critical Improvements

1. **{{PRIORITY_1}}** {{ISSUE_1}}
2. **{{PRIORITY_2}}** {{ISSUE_2}}
3. **{{PRIORITY_3}}** {{ISSUE_3}}

---

## Score Breakdown

| Dimension | Score | Weight | Weighted Score |
|-----------|-------|--------|----------------|
| 1. Module Usage & Architecture | {{DIM1_SCORE}}/10 | 25% | {{DIM1_WEIGHTED}} |
| 2. Security & Compliance | {{DIM2_SCORE}}/10 | 30% | {{DIM2_WEIGHTED}} |
| 3. Code Quality & Maintainability | {{DIM3_SCORE}}/10 | 15% | {{DIM3_WEIGHTED}} |
| 4. Variable & Output Management | {{DIM4_SCORE}}/10 | 10% | {{DIM4_WEIGHTED}} |
| 5. Testing & Validation | {{DIM5_SCORE}}/10 | 10% | {{DIM5_WEIGHTED}} |
| 6. Constitution & Plan Alignment | {{DIM6_SCORE}}/10 | 10% | {{DIM6_WEIGHTED}} |
| **Overall** | **{{OVERALL_SCORE}}/10** | **100%** | **{{OVERALL_WEIGHTED}}** |

---

## Detailed Dimension Analysis

### 1. Module Usage & Architecture: {{DIM1_SCORE}}/10 (Weight: 25%)

**Evaluation Focus**: Private registry module adoption, semantic versioning, module-first architecture

#### Strengths
{{DIM1_STRENGTHS}}

#### Issues Found
{{DIM1_ISSUES}}

#### Recommendations
{{DIM1_RECOMMENDATIONS}}

---

### 2. Security & Compliance: {{DIM2_SCORE}}/10 (Weight: 30%) 🔒 **[HIGHEST PRIORITY]**

**Evaluation Focus**: No hardcoded credentials, encryption at rest/transit, IAM least privilege, network security

#### Strengths
{{DIM2_STRENGTHS}}

#### Issues Found
{{DIM2_ISSUES}}

#### Recommendations
{{DIM2_RECOMMENDATIONS}}

---

### 3. Code Quality & Maintainability: {{DIM3_SCORE}}/10 (Weight: 15%)

**Evaluation Focus**: Formatting, naming conventions, DRY principle, documentation, logical organization

#### Strengths
{{DIM3_STRENGTHS}}

#### Issues Found
{{DIM3_ISSUES}}

#### Recommendations
{{DIM3_RECOMMENDATIONS}}

---

### 4. Variable & Output Management: {{DIM4_SCORE}}/10 (Weight: 10%)

**Evaluation Focus**: Variable declarations, type constraints, validation rules, output definitions

#### Strengths
{{DIM4_STRENGTHS}}

#### Issues Found
{{DIM4_ISSUES}}

#### Recommendations
{{DIM4_RECOMMENDATIONS}}

---

### 5. Testing & Validation: {{DIM5_SCORE}}/10 (Weight: 10%)

**Evaluation Focus**: terraform validate, test files, pre-commit hooks, example tfvars

#### Strengths
{{DIM5_STRENGTHS}}

#### Issues Found
{{DIM5_ISSUES}}

#### Recommendations
{{DIM5_RECOMMENDATIONS}}

---

### 6. Constitution & Plan Alignment: {{DIM6_SCORE}}/10 (Weight: 10%)

**Evaluation Focus**: Plan.md alignment, constitution compliance, naming conventions, git workflow

#### Strengths
{{DIM6_STRENGTHS}}

#### Issues Found
{{DIM6_ISSUES}}

#### Recommendations
{{DIM6_RECOMMENDATIONS}}

---

## Security Analysis Summary

### Critical Findings (P0) - ❌ IMMEDIATE FIX REQUIRED

{{SECURITY_P0_FINDINGS}}

### High Severity Findings (P1) - ⚠️ FIX BEFORE DEPLOYMENT

{{SECURITY_P1_FINDINGS}}

### Medium Severity Findings (P2) - 💡 SHOULD FIX

{{SECURITY_P2_FINDINGS}}

### Security Tool Compliance

| Tool | Status | Findings | Details |
|------|--------|----------|---------|
| terraform validate | {{VALIDATE_STATUS}} | {{VALIDATE_COUNT}} | {{VALIDATE_DETAILS}} |
| tflint | {{TFLINT_STATUS}} | {{TFLINT_COUNT}} | {{TFLINT_DETAILS}} |
| trivy | {{TRIVY_STATUS}} | {{TRIVY_COUNT}} | {{TRIVY_DETAILS}} |
| vault-radar-scan | {{VAULT_STATUS}} | {{VAULT_COUNT}} | {{VAULT_DETAILS}} |

**Security Recommendation**: {{SECURITY_RECOMMENDATION}}

---

## File-by-File Analysis

{{FILE_BY_FILE_ANALYSIS}}

---

## Improvement Roadmap

### Priority Definitions

- **P0 (Critical)**: Blocking issues - MUST fix before deployment
- **P1 (High)**: Important issues - SHOULD fix before deployment
- **P2 (Medium)**: Quality enhancements - Address in next iteration
- **P3 (Low)**: Nice-to-have improvements - Optional

### Critical (P0) - Fix Before Deployment

{{ROADMAP_P0}}

### High Priority (P1) - Should Fix

{{ROADMAP_P1}}

### Medium Priority (P2) - Quality Enhancements

{{ROADMAP_P2}}

### Low Priority (P3) - Nice to Have

{{ROADMAP_P3}}

---

## Constitution Compliance Report

| Principle | Section | Status | Evidence | Notes |
|-----------|---------|--------|----------|-------|
| Module-first architecture | §1.1 | {{CONST_1_STATUS}} | {{CONST_1_EVIDENCE}} | {{CONST_1_NOTES}} |
| Semantic versioning | §1.2 | {{CONST_2_STATUS}} | {{CONST_2_EVIDENCE}} | {{CONST_2_NOTES}} |
| Ephemeral credentials | §2.1 | {{CONST_3_STATUS}} | {{CONST_3_EVIDENCE}} | {{CONST_3_NOTES}} |
| Least privilege IAM | §2.2 | {{CONST_4_STATUS}} | {{CONST_4_EVIDENCE}} | {{CONST_4_NOTES}} |
| Encryption at rest | §2.3 | {{CONST_5_STATUS}} | {{CONST_5_EVIDENCE}} | {{CONST_5_NOTES}} |
| Testing framework | §6 | {{CONST_6_STATUS}} | {{CONST_6_EVIDENCE}} | {{CONST_6_NOTES}} |
| Pre-commit validation | §5.3 | {{CONST_7_STATUS}} | {{CONST_7_EVIDENCE}} | {{CONST_7_NOTES}} |

**Constitution Alignment**: {{CONSTITUTION_PERCENTAGE}}% compliant ({{CONST_PASS}}/{{CONST_TOTAL}} principles)

**Critical Violations** (MUST principles): {{CONSTITUTION_VIOLATIONS}}

---

## Next Steps

{{NEXT_STEPS_CONTENT}}

---

## Code Refinement Options

{{REFINEMENT_OPTIONS}}

---

## Evaluation Metadata

| Metric | Value |
|--------|-------|
| **Methodology** | Agent-as-a-Judge (Security-First Pattern) |
| **Evaluation Time** | {{EVAL_DURATION}} seconds |
| **Token Usage** | ~{{TOKEN_COUNT}} tokens |
| **Iteration** | {{ITERATION_NUMBER}} |
| **Files Evaluated** | {{FILE_COUNT}} |
| **Total Lines of Code** | ~{{LOC_COUNT}} |
| **Terraform Version** | {{TF_VERSION}} |
| **Judge Version** | code-quality-judge v1.0 (Claude Sonnet 4.5) |

---

## Appendix: Detailed Code Examples

{{CODE_EXAMPLES_APPENDIX}}

---

**Report Generated**: {{GENERATION_TIMESTAMP}}
**Evaluation ID**: `{{EVAL_ID}}`
**Saved to**: `{{FEATURE_DIR}}/evaluations/code-review-{{EVAL_ID}}.md`