---
name: lighthouse-audit
description: Use when auditing webpage performance, accessibility, SEO, or best practices with Google Lighthouse. Supports comprehensive analysis of both local development servers and production URLs, providing actionable recommendations for improving web quality metrics.
---

# Lighthouse Audit

## Overview

Run Google Lighthouse audits to analyze webpage performance, accessibility, best practices, and SEO. Generate comprehensive reports with actionable recommendations for improving web quality metrics and user experience.

## When to Use This Skill

Use this skill when:
- Auditing page load performance and Core Web Vitals (LCP, FCP, CLS, TBT)
- Evaluating accessibility compliance (WCAG, ARIA, screen reader support)
- Checking SEO optimization (meta tags, structured data, mobile-friendliness)
- Validating best practices (security, modern web standards)
- Analyzing both local development servers (http://localhost:3000) and production URLs
- Prioritizing performance optimizations based on impact
- Generating baseline metrics before/after optimization work
- Continuous performance monitoring in development workflows

## Prerequisites

Ensure Google Lighthouse CLI is installed before running audits:

```bash
npm install -g lighthouse
```

Verify installation:
```bash
lighthouse --version
```

## Core Capabilities

### 1. Run Comprehensive Audits

Execute full Lighthouse audits covering all four categories:

```bash
python3 scripts/run_lighthouse.py https://example.com
```

**Output includes:**
- Summary report with category scores (Performance, Accessibility, Best Practices, SEO)
- Detailed analysis with performance opportunities and failed audits
- Actionable recommendations sorted by impact weight

**Key flags:**
- `--format` or `-f`: Choose output format (summary, detailed, actionable, all)
- `--preset` or `-p`: Device preset (desktop or mobile)
- `--output` or `-o`: Save full JSON report to file
- `--categories` or `-c`: Specific categories to audit

### 2. Generate Summary Reports

Quick score overview for rapid assessment:

```bash
python3 scripts/run_lighthouse.py https://example.com --format summary
```

**Provides:**
- URL and fetch time
- Color-coded scores for all categories (🟢 90-100, 🟡 50-89, 🔴 0-49)
- Quick pass/fail assessment

**Use when:**
- Running quick checks during development
- Comparing scores before/after changes
- Getting baseline metrics for new pages

### 3. Generate Detailed Reports

Comprehensive breakdown of audit results:

```bash
python3 scripts/run_lighthouse.py https://example.com --format detailed
```

**Provides:**
- Summary scores
- Performance opportunities with potential time savings
- Failed audits by category with impact weights
- Display values showing specific measurements

**Use when:**
- Investigating specific performance bottlenecks
- Understanding why scores are low
- Planning optimization work
- Deep-diving into category-specific issues

### 4. Generate Actionable Recommendations

Prioritized list of fixes sorted by impact:

```bash
python3 scripts/run_lighthouse.py https://example.com --format actionable
```

**Provides:**
- Top 15 issues sorted by impact weight across all categories
- Category labels for each issue (Performance, Accessibility, etc.)
- Scores and descriptions for each recommendation
- Clear action items for developers

**Use when:**
- Planning sprint work or optimization tasks
- Prioritizing fixes based on impact
- Communicating issues to development teams
- Creating technical debt backlog items

### 5. Audit Local Development Servers

Test pages during development before deployment:

```bash
python3 scripts/run_lighthouse.py http://localhost:3000
```

**Supports:**
- Rails servers (http://localhost:3000)
- Vite dev servers (http://localhost:5173)
- Any local HTTP server
- Custom ports

**Important notes:**
- Local performance may not reflect production accurately
- Network throttling still applies (simulated 4G for mobile)
- Test both desktop and mobile presets
- Consider testing on staging/production for realistic results

### 6. Mobile vs Desktop Audits

Compare performance across device types:

```bash
# Desktop audit (default)
python3 scripts/run_lighthouse.py https://example.com --preset desktop

# Mobile audit (with throttling)
python3 scripts/run_lighthouse.py https://example.com --preset mobile
```

**Key differences:**
- Mobile uses 4G network throttling and slower CPU simulation
- Mobile scores typically lower than desktop
- Mobile has stricter performance requirements
- Desktop scoring curves differ from mobile (Lighthouse 6+)

**Best practice:** Audit both presets, prioritize mobile optimization

### 7. Category-Specific Audits

Focus on specific aspects of page quality:

```bash
# Performance only
python3 scripts/run_lighthouse.py https://example.com --categories performance

# Accessibility and SEO
python3 scripts/run_lighthouse.py https://example.com --categories accessibility seo

# All categories (default)
python3 scripts/run_lighthouse.py https://example.com
```

**Available categories:**
- `performance` - Page load speed, Core Web Vitals
- `accessibility` - WCAG compliance, assistive technology
- `best-practices` - Security, modern standards
- `seo` - Search engine optimization, discoverability

### 8. Save JSON Reports

Preserve audit data for tracking and comparison:

```bash
python3 scripts/run_lighthouse.py https://example.com --output audit-report.json
```

**Use saved reports for:**
- Version control (track improvements over time)
- CI/CD pipeline integration
- Automated regression detection
- Historical comparison
- Sharing with [Lighthouse Viewer](https://googlechrome.github.io/lighthouse/viewer/)

## Interpreting Results

### Score Ranges

- **90-100 (🟢 Green)**: Good - No major issues
- **50-89 (🟡 Yellow)**: Needs Improvement - Optimization opportunities exist
- **0-49 (🔴 Red)**: Poor - Significant issues requiring attention

### Performance Score Weights (Lighthouse 10)

Understand which metrics contribute most to performance scores:

- **Total Blocking Time (TBT)**: 30% - JavaScript execution blocking interactivity
- **Largest Contentful Paint (LCP)**: 25% - Time to render main content
- **Cumulative Layout Shift (CLS)**: 25% - Visual stability during load
- **First Contentful Paint (FCP)**: 10% - Time to first visible content
- **Speed Index**: 10% - Visual completeness speed

**Prioritization strategy:** Focus on high-weight metrics (TBT, LCP, CLS) for maximum score improvement.

### Impact Weights

Failed audits include weight values indicating impact on category scores:
- Higher weights = bigger impact on score
- Focus on high-weight issues first for efficient optimization
- Zero-weight audits are informational only

## Common Workflows

### Workflow 1: Baseline Performance Assessment

Establish baseline metrics for a page:

1. Run comprehensive audit with all formats:
   ```bash
   python3 scripts/run_lighthouse.py https://example.com --output baseline.json
   ```

2. Review summary scores to identify problem categories

3. Examine actionable report to prioritize fixes

4. Reference `references/metrics_guide.md` for optimization strategies

5. Save JSON report for future comparison

### Workflow 2: Pre-Deployment Validation

Validate changes before deploying to production:

1. Audit staging environment:
   ```bash
   python3 scripts/run_lighthouse.py https://staging.example.com --format actionable
   ```

2. Compare scores against baseline or requirements

3. Review failed audits for regressions

4. Address critical issues (score < 50) before deployment

5. Document improvements in commit messages or PR descriptions

### Workflow 3: Accessibility Audit

Focus on WCAG compliance and assistive technology support:

1. Run accessibility-focused audit:
   ```bash
   python3 scripts/run_lighthouse.py https://example.com --categories accessibility --format detailed
   ```

2. Review failed audits in detailed report

3. Check `references/metrics_guide.md` for accessibility guidance:
   - Color contrast requirements
   - ARIA attribute best practices
   - Form element labeling
   - Heading hierarchy
   - Keyboard navigation

4. Test fixes manually with screen readers and keyboard-only navigation

5. Re-run audit to verify improvements

### Workflow 4: Performance Optimization Sprint

Systematic performance improvement:

1. Generate baseline actionable report:
   ```bash
   python3 scripts/run_lighthouse.py https://example.com --format actionable --output before.json
   ```

2. Identify quick wins from `references/metrics_guide.md`:
   - Add image dimensions (fixes CLS)
   - Enable compression
   - Defer offscreen images
   - Add cache headers

3. Implement high-impact, quick fixes first

4. Re-run audit after each change batch:
   ```bash
   python3 scripts/run_lighthouse.py https://example.com --format summary
   ```

5. Track score improvements and iterate

6. Save final report for comparison:
   ```bash
   python3 scripts/run_lighthouse.py https://example.com --output after.json
   ```

### Workflow 5: Local Development Testing

Audit during development:

1. Start local development server (e.g., `rails server`, `bin/dev`)

2. Run audit on local server:
   ```bash
   python3 scripts/run_lighthouse.py http://localhost:3000/products --preset desktop
   ```

3. Review summary scores for immediate feedback

4. Note: Local scores may not reflect production (no CDN, different network conditions)

5. Validate critical changes on staging before production deployment

## Metrics Reference

For detailed information about Lighthouse metrics, scoring, and optimization strategies, refer to:

```bash
# View comprehensive metrics guide
cat references/metrics_guide.md
```

**The guide covers:**
- Core Web Vitals (LCP, FCP, CLS, TBT) definitions and targets
- Accessibility audit categories and WCAG requirements
- Best practices for security and modern web standards
- SEO optimization recommendations
- Common optimization strategies with implementation details
- Score weight distribution and prioritization frameworks
- Quick wins vs long-term optimization projects

## Best Practices

### Testing Strategy

1. **Test both desktop and mobile presets** - Mobile typically has stricter requirements
2. **Run multiple audits** - Scores can vary due to network conditions; average 3-5 runs
3. **Test in production-like environments** - Local dev scores may be misleading
4. **Audit key user journeys** - Homepage, product pages, checkout flows
5. **Set performance budgets** - Define minimum acceptable scores per category

### Score Interpretation

1. **Focus on user experience, not just scores** - A score of 95 vs 100 rarely impacts users
2. **Prioritize high-impact metrics** - TBT, LCP, CLS have highest weight
3. **Don't ignore yellow scores** - 50-89 range still has optimization opportunities
4. **Track trends over time** - One audit is a snapshot; trends reveal patterns
5. **Consider page context** - E-commerce pages have different priorities than marketing pages

### Optimization Workflow

1. **Start with actionable report** - Sorted by impact for efficient prioritization
2. **Fix high-weight issues first** - Bigger impact on scores per unit of effort
3. **Batch related fixes** - Group similar optimizations (e.g., all image work together)
4. **Test incrementally** - Verify each batch before moving to next
5. **Document baselines** - Save JSON reports for comparison and regression detection

### Common Pitfalls

1. **Testing only on desktop** - Mobile performance often significantly worse
2. **Optimizing in isolation** - Test on real devices and networks periodically
3. **Ignoring third-party scripts** - Third-party code can dominate performance impact
4. **One-time optimization** - Performance requires ongoing monitoring
5. **Chasing perfect 100 scores** - Diminishing returns beyond 90-95 range

## Troubleshooting

### Lighthouse Not Installed

**Error:** `❌ Error: Lighthouse CLI is not installed.`

**Fix:**
```bash
npm install -g lighthouse
```

### Chrome Not Found

**Error:** Lighthouse cannot find Chrome browser

**Fix:** Install Google Chrome or specify Chrome path:
```bash
export CHROME_PATH=/path/to/chrome
```

### Connection Refused (Local Server)

**Error:** Connection refused when auditing localhost

**Fix:**
1. Verify server is running (`rails server`, `bin/dev`)
2. Check correct port in URL
3. Ensure no firewall blocking localhost connections

### Inconsistent Scores

**Symptom:** Large score variations between runs

**Causes:**
- Network variability
- Background processes
- Browser extensions
- A/B testing or dynamic ads

**Fix:**
1. Close unnecessary browser tabs/extensions
2. Run multiple audits and average results
3. Test on consistent network conditions
4. Disable A/B tests during auditing

## Resources

### Bundled Resources

- **`scripts/run_lighthouse.py`**: Python script for running Lighthouse audits with formatted output
- **`references/metrics_guide.md`**: Comprehensive guide to Lighthouse metrics, scoring, and optimization strategies

### External Resources

- [Lighthouse Documentation](https://developer.chrome.com/docs/lighthouse/)
- [Web.dev Performance](https://web.dev/performance/)
- [Core Web Vitals](https://web.dev/vitals/)
- [PageSpeed Insights](https://pagespeed.web.dev/) (online Lighthouse runner)
- [Lighthouse Viewer](https://googlechrome.github.io/lighthouse/viewer/) (view saved JSON reports)
- [Lighthouse Scoring Calculator](https://googlechrome.github.io/lighthouse/scorecalc/) (explore score calculations)

## Integration Examples

### CI/CD Pipeline Integration

```bash
# In GitHub Actions, GitLab CI, etc.
- name: Run Lighthouse Audit
  run: |
    npm install -g lighthouse
    python3 scripts/run_lighthouse.py https://staging.example.com --format actionable
    # Fail build if performance score < 80
    SCORE=$(python3 scripts/run_lighthouse.py https://staging.example.com --output report.json | grep Performance | awk '{print $2}')
    if [ $SCORE -lt 80 ]; then exit 1; fi
```

### Rails Development Workflow

```bash
# Start Rails server with Vite
bin/dev

# In another terminal, audit homepage
python3 lighthouse-audit/scripts/run_lighthouse.py http://localhost:3000 --format summary

# Audit specific pages
python3 lighthouse-audit/scripts/run_lighthouse.py http://localhost:3000/products --format actionable
```

### Pre-Commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
echo "Running Lighthouse audit on local server..."
python3 lighthouse-audit/scripts/run_lighthouse.py http://localhost:3000 --format summary --categories performance accessibility
```
