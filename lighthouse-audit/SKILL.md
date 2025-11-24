---
name: lighthouse-audit
description: Use when auditing webpage performance, accessibility, SEO, or best practices with timing dependencies, score comparisons, or prioritization needs - runs Google Lighthouse CLI with impact-weighted recommendations and proper baseline comparison methodology for reliable web quality assessment
---

# Lighthouse Audit

## Overview

Run Google Lighthouse audits with proper baseline comparison and impact-weighted prioritization. Prevents common mistakes: desktop-only testing, missing baselines, ignoring mobile, single-run unreliability.

## When to Use

Use when:
- Debugging performance issues (slow page loads, poor Core Web Vitals)
- Validating accessibility compliance (WCAG requirements)
- Optimizing SEO (meta tags, structured data)
- Comparing before/after optimization work
- Prioritizing fixes by impact weight

**Don't use when:**
- Running one-off checks (use PageSpeed Insights web UI)
- Only need screenshot testing (different tool)

## Prerequisites

```bash
npm install -g lighthouse
lighthouse --version
```

## Core Technique: Baseline-Compare-Prioritize

### Step 1: Save Baseline FIRST (Before Anything Else)

**FIRST step - do this before running any other audits:**

```bash
# Save baseline with timestamp
python3 scripts/run_lighthouse.py https://example.com \
  --output baseline-$(date +%Y%m%d).json \
  --format all
```

**Why:** Can't measure improvement without baseline. Agents skip this under time pressure - don't.

**Don't:**
- "I'll run a quick check first" (save baseline FIRST)
- "I'll save it after I see the results" (too late - save FIRST)
- "I already know it's slow" (still save baseline FIRST)

### Step 2: Test BOTH Desktop AND Mobile

Desktop scores are misleading. Mobile is typically 10-20 points lower:

```bash
# Desktop
python3 scripts/run_lighthouse.py https://example.com --preset desktop

# Mobile (REQUIRED - don't skip)
python3 scripts/run_lighthouse.py https://example.com --preset mobile
```

**Mobile failures agents make:**
- "I'll test desktop first" (then forget mobile)
- "Desktop is good enough" (wrong - mobile is stricter)
- "User said desktop" (audit both anyway, report both)

### Step 3: Use --format actionable for Prioritization

Get impact-weighted recommendations (not just random list):

```bash
python3 scripts/run_lighthouse.py https://example.com --format actionable
```

**Output shows:**
- Top 15 issues sorted by weight (higher weight = bigger score impact)
- Category labels (Performance/Accessibility/SEO/Best Practices)
- Scores and specific fix descriptions

**Don't:**
- Use --format detailed and manually prioritize (waste of time)
- Fix issues in order discovered (ignore weight)
- Mix high and low weight issues (focus on high first)

### Step 4: Run 3-5 Times, Average Scores

**REQUIRED: Run multiple times.** Single run is unreliable (±5-10 point variance):

```bash
# Run 3 times minimum
for i in {1..3}; do
  python3 scripts/run_lighthouse.py https://example.com --format summary
done
```

Average the scores. Report range if variance > 5 points.

**Don't:**
- "One run is probably fine" (it's not - scores vary)
- "I'll run again if scores look weird" (run 3x regardless)
- "This will take too long" (3 runs = 3 minutes, worth it)

## Quick Reference

| Task | Command | Notes |
|------|---------|-------|
| Save baseline | `--output baseline.json` | ALWAYS do this first |
| Mobile audit | `--preset mobile` | REQUIRED, not optional |
| Desktop audit | `--preset desktop` | Do AFTER mobile |
| Prioritize fixes | `--format actionable` | Sorted by impact weight |
| Quick check | `--format summary` | For rapid iteration |
| Accessibility only | `--categories accessibility` | Focus one category |

## Local Development vs Production

**Local (http://localhost:3000):**
- Use for rapid iteration
- Scores DON'T reflect production (no minification, no CDN)
- **Test mobile too - REQUIRED even for localhost** (agents skip this)
- Save baseline before changes

**Localhost mobile testing:**
```bash
# Desktop
python3 scripts/run_lighthouse.py http://localhost:3000 --preset desktop

# Mobile (REQUIRED - don't skip for local)
python3 scripts/run_lighthouse.py http://localhost:3000 --preset mobile
```

**Production (https://example.com):**
- Use for final validation
- Scores reflect real user experience
- Always test before deployment
- Compare against staging

**Don't:**
- Trust local scores as production-accurate
- Skip production testing "because local is good"
- Test only one environment

## Common Mistakes

| Mistake | Reality |
|---------|---------|
| "I'll save baseline later" | You'll forget. Save FIRST, before any other audits. |
| "Desktop is enough" | Mobile is stricter. Test both, even on localhost. |
| "One audit is fine" | Scores vary ±5-10 points. Run 3-5x minimum. |
| "I'll run mobile if desktop is bad" | Test mobile regardless. It's always stricter. |
| "I'll prioritize manually" | Use `--format actionable`. It's sorted by weight. |
| "Local scores predict production" | They don't. Test staging/production too. |
| "Fix everything" | Fix high-weight issues first. |
| "I'll run again if needed" | Run 3x upfront, not reactively. |

## Score Interpretation

| Range | Color | Meaning |
|-------|-------|---------|
| 90-100 | 🟢 Green | Good - minor issues only |
| 50-89 | 🟡 Yellow | Needs improvement - optimization opportunities |
| 0-49 | 🔴 Red | Poor - significant issues requiring immediate attention |

**Performance score weights (Lighthouse 10):**
- Total Blocking Time (TBT): 30%
- Largest Contentful Paint (LCP): 25%
- Cumulative Layout Shift (CLS): 25%
- First Contentful Paint (FCP): 10%
- Speed Index: 10%

Focus on TBT, LCP, CLS for maximum impact.

## Real-World Example

**Scenario:** Homepage is slow, launching tomorrow.

**Wrong approach (agents do this):**
```bash
# ❌ Desktop only, no baseline, no prioritization
python3 scripts/run_lighthouse.py https://example.com
# Read through detailed report, pick random issues
```

**Correct approach:**
```bash
# 1. Save baseline
python3 scripts/run_lighthouse.py https://example.com \
  --output baseline.json --format all

# 2. Test mobile (strictest)
python3 scripts/run_lighthouse.py https://example.com \
  --preset mobile --format actionable

# 3. Test desktop
python3 scripts/run_lighthouse.py https://example.com \
  --preset desktop --format actionable

# 4. Focus on top 5 high-weight issues from mobile
# 5. Fix those
# 6. Re-run mobile audit, save new report
# 7. Compare scores
```

## Metrics Reference

For detailed metrics explanations:
```bash
cat references/metrics_guide.md
```

Covers:
- Core Web Vitals definitions (LCP, FCP, CLS, TBT targets)
- Accessibility audit types (ARIA, contrast, keyboard nav)
- SEO requirements (meta tags, structured data)
- Optimization strategies by impact

## Resources

**Bundled:**
- `scripts/run_lighthouse.py` - Audit runner with formatted output
- `references/metrics_guide.md` - Comprehensive metrics guide

**External:**
- [Lighthouse Docs](https://developer.chrome.com/docs/lighthouse/)
- [Core Web Vitals](https://web.dev/vitals/)
- [Lighthouse Scorer](https://googlechrome.github.io/lighthouse/scorecalc/)
