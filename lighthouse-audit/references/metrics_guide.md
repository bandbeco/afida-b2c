# Lighthouse Metrics Reference Guide

This reference provides detailed information about Lighthouse metrics, scoring, and recommendations for improving audit scores.

## Overview

Lighthouse audits four main categories:
- **Performance**: Page load speed and runtime performance
- **Accessibility**: WCAG compliance and assistive technology support
- **Best Practices**: Modern web standards and security
- **SEO**: Search engine optimization and discoverability

## Score Interpretation

- **90-100 (Green 🟢)**: Good - No major issues
- **50-89 (Yellow 🟡)**: Needs Improvement - Some optimization opportunities
- **0-49 (Red 🔴)**: Poor - Significant issues requiring attention

## Performance Metrics

### Core Web Vitals

#### Largest Contentful Paint (LCP)
- **What**: Time until the largest content element is visible
- **Target**: < 2.5 seconds
- **Weight**: High (25% of performance score)
- **User Impact**: Measures perceived load speed
- **Common Issues**:
  - Large images not optimized
  - Render-blocking JavaScript/CSS
  - Slow server response times
  - No CDN for static assets

#### First Contentful Paint (FCP)
- **What**: Time until first text/image is painted
- **Target**: < 1.8 seconds
- **Weight**: Medium (10% of performance score)
- **User Impact**: First visual feedback for users
- **Common Issues**:
  - Render-blocking resources
  - Slow server response
  - Large CSS files
  - Excessive DOM size

#### Cumulative Layout Shift (CLS)
- **What**: Visual stability - measures unexpected layout shifts
- **Target**: < 0.1
- **Weight**: High (25% of performance score)
- **User Impact**: Prevents accidental clicks and frustration
- **Common Issues**:
  - Images without dimensions
  - Ads/embeds without reserved space
  - Dynamically injected content
  - Web fonts causing FOIT/FOUT

#### Total Blocking Time (TBT)
- **What**: Time the main thread is blocked from responding
- **Target**: < 200ms
- **Weight**: High (30% of performance score)
- **User Impact**: Measures interactivity and responsiveness
- **Common Issues**:
  - Large JavaScript bundles
  - Long-running JavaScript tasks
  - Unoptimized third-party scripts
  - Heavy computational work on main thread

#### Speed Index
- **What**: How quickly content is visually displayed
- **Target**: < 3.4 seconds
- **Weight**: Medium (10% of performance score)
- **User Impact**: Visual completeness perception
- **Common Issues**:
  - Render-blocking resources
  - Large network payloads
  - Inefficient cache policies
  - Unoptimized images

### Other Performance Metrics

#### Time to Interactive (TTI)
- **What**: Time until page is fully interactive
- **Target**: < 3.8 seconds
- **User Impact**: When users can reliably interact with page
- **Common Issues**:
  - JavaScript blocking main thread
  - Excessive polyfills
  - Heavy framework overhead

#### Max Potential First Input Delay (FID)
- **What**: Maximum estimated delay for first user interaction
- **Target**: < 100ms
- **User Impact**: Responsiveness to user input
- **Common Issues**: Similar to TBT

## Accessibility Audits

### Critical Accessibility Issues

#### Color Contrast
- **What**: Background and foreground colors must have sufficient contrast
- **Standard**: WCAG AA requires 4.5:1 for normal text, 3:1 for large text
- **Fix**: Use tools like Contrast Checker or adjust colors

#### ARIA Attributes
- **What**: Proper use of ARIA roles, states, and properties
- **Common Issues**:
  - Invalid ARIA attribute values
  - Unsupported ARIA roles
  - Conflicting ARIA and HTML semantics
- **Fix**: Follow WAI-ARIA authoring practices

#### Form Elements
- **What**: All form elements need associated labels
- **Fix**: Use `<label>` elements or `aria-label`/`aria-labelledby`

#### Image Alt Text
- **What**: Images need descriptive alternative text
- **Fix**: Add meaningful `alt` attributes to `<img>` tags

#### Heading Hierarchy
- **What**: Headings must be in sequential descending order
- **Fix**: Don't skip heading levels (e.g., h1 → h3)

#### Keyboard Navigation
- **What**: All interactive elements must be keyboard accessible
- **Fix**: Ensure focusable elements have visible focus indicators

#### Screen Reader Support
- **What**: Content must be announced correctly by screen readers
- **Common Issues**:
  - Missing landmarks (`main`, `nav`, `aside`)
  - Improper heading structure
  - Interactive elements without labels
  - Hidden content not properly managed

### Language and Document Structure

#### Document Language
- **What**: `<html>` element must have valid `lang` attribute
- **Fix**: `<html lang="en">` for English content

#### Title Element
- **What**: Page must have unique, descriptive `<title>`
- **Fix**: Add meaningful page title in `<head>`

#### Meta Viewport
- **What**: Viewport meta tag for responsive design
- **Fix**: `<meta name="viewport" content="width=device-width, initial-scale=1">`

## Best Practices Audits

### Security

#### HTTPS
- **What**: Page served over secure connection
- **Fix**: Configure SSL/TLS certificate

#### Mixed Content
- **What**: HTTPS pages shouldn't load HTTP resources
- **Fix**: Update all resource URLs to HTTPS

#### Vulnerable Libraries
- **What**: No JavaScript libraries with known vulnerabilities
- **Fix**: Update dependencies regularly

#### Content Security Policy (CSP)
- **What**: CSP header to prevent XSS attacks
- **Fix**: Implement proper CSP headers

### Modern Web Standards

#### Document Mode
- **What**: Page shouldn't use legacy `DOCTYPE`
- **Fix**: Use HTML5 doctype: `<!DOCTYPE html>`

#### Console Errors
- **What**: No browser errors logged to console
- **Fix**: Debug and resolve all console errors

#### Deprecated APIs
- **What**: Avoid deprecated web platform APIs
- **Fix**: Modernize code to use current APIs

#### Image Aspect Ratios
- **What**: Images displayed with correct aspect ratios
- **Fix**: Set width/height or use CSS aspect-ratio

### User Experience

#### Password Fields
- **What**: Password inputs on secure pages
- **Fix**: Only show password fields on HTTPS pages

#### Links to Cross-Origin Destinations
- **What**: Links to cross-origin pages should use `rel="noopener"`
- **Fix**: Add `rel="noopener noreferrer"` to external links

## SEO Audits

### Crawlability

#### Robots.txt
- **What**: Valid robots.txt if present
- **Fix**: Test with Google Search Console

#### Indexability
- **What**: Page not blocked from indexing
- **Fix**: Remove blocking `meta robots` or `X-Robots-Tag`

#### Canonical URL
- **What**: Valid canonical URL if present
- **Fix**: Ensure `<link rel="canonical">` points to correct URL

### Content

#### Title Tag
- **What**: Unique, descriptive title under 60 characters
- **Fix**: Write compelling, keyword-rich titles

#### Meta Description
- **What**: Unique description under 160 characters
- **Fix**: Write compelling meta descriptions

#### Heading Elements
- **What**: Page has at least one `<h1>` element
- **Fix**: Add semantic heading structure

### Mobile Optimization

#### Viewport Meta Tag
- **What**: Proper viewport configuration
- **Fix**: Add responsive viewport meta tag

#### Font Sizes
- **What**: Text large enough to read on mobile
- **Fix**: Use relative units (em, rem) and test on mobile

#### Tap Targets
- **What**: Interactive elements sized appropriately for touch
- **Target**: At least 48x48 CSS pixels with adequate spacing
- **Fix**: Increase touch target sizes and spacing

### Structured Data

#### Valid Structured Data
- **What**: Schema.org markup without errors
- **Fix**: Test with Google's Rich Results Test

#### Hreflang
- **What**: Valid hreflang attributes for multilingual content
- **Fix**: Ensure proper hreflang implementation

## Performance Opportunities

### Common Optimization Strategies

#### 1. Optimize Images
- Use modern formats (WebP, AVIF)
- Implement responsive images with `srcset`
- Add lazy loading for off-screen images
- Compress images (target: 85-90% quality)
- Specify width/height dimensions

#### 2. Minify and Compress
- Minify CSS, JavaScript, HTML
- Enable gzip/brotli compression
- Remove unused CSS/JavaScript
- Tree-shake dependencies

#### 3. Optimize Loading
- Defer non-critical JavaScript
- Use `async` or `defer` for scripts
- Inline critical CSS
- Preload key resources
- Use resource hints (preconnect, dns-prefetch)

#### 4. Reduce Network Payloads
- Enable HTTP/2 or HTTP/3
- Implement efficient caching strategies
- Use a CDN for static assets
- Split code bundles
- Remove duplicate modules

#### 5. Optimize Fonts
- Use `font-display: swap` or `optional`
- Subset fonts to needed characters
- Self-host fonts when possible
- Limit font variations

#### 6. Optimize Third-Party Code
- Lazy load third-party resources
- Use facade pattern for embeds
- Limit third-party domains
- Monitor third-party impact

#### 7. Reduce JavaScript Execution
- Split long tasks (> 50ms)
- Use web workers for heavy computation
- Implement code splitting
- Reduce polyfills for modern browsers

## Weight and Impact

Lighthouse calculates scores based on weighted metrics. Understanding these weights helps prioritize fixes:

### Performance Score Weights
- LCP: 25%
- TBT: 30%
- CLS: 25%
- FCP: 10%
- Speed Index: 10%

### Prioritization Strategy

1. **High Impact, Quick Fixes** (Do First)
   - Add image dimensions (fixes CLS)
   - Enable compression
   - Defer offscreen images
   - Add cache headers

2. **High Impact, Medium Effort**
   - Optimize images (format, size, lazy loading)
   - Minify CSS/JavaScript
   - Remove unused code
   - Optimize fonts

3. **High Impact, High Effort**
   - Code splitting
   - Migrate to modern frameworks
   - Redesign layout patterns
   - Server infrastructure improvements

## Testing Strategy

### Desktop vs Mobile
- Mobile typically has stricter requirements
- Run both desktop and mobile audits
- Mobile uses simulated 4G throttling
- Consider mobile-first optimization

### Testing Environments
- **Production**: Real-world performance
- **Staging**: Pre-deployment validation
- **Local**: Development-time checks (may not reflect production accurately)

### Continuous Monitoring
- Run Lighthouse in CI/CD pipelines
- Set performance budgets
- Track metrics over time
- Alert on regressions

## Resources

- [Web.dev Performance](https://web.dev/performance/)
- [Chrome Lighthouse Documentation](https://developer.chrome.com/docs/lighthouse/)
- [Web Vitals](https://web.dev/vitals/)
- [PageSpeed Insights](https://pagespeed.web.dev/)
- [WebPageTest](https://www.webpagetest.org/)

## Score Improvement Tips

### Quick Wins (30 minutes - 2 hours)
- Add missing meta tags
- Fix color contrast issues
- Add image alt text
- Enable compression
- Add cache headers

### Medium Effort (1-3 days)
- Optimize images
- Defer JavaScript
- Implement lazy loading
- Fix accessibility issues
- Optimize fonts

### Long-term Projects (1+ weeks)
- Implement code splitting
- Redesign for performance
- Migrate to modern stack
- Implement service workers
- Build comprehensive monitoring

## Common Pitfalls

1. **Testing Local Development**: Local performance doesn't reflect production
2. **Ignoring Mobile**: Mobile scores often much lower than desktop
3. **Focusing Only on Score**: Focus on user experience, not just numbers
4. **One-time Optimization**: Performance requires ongoing attention
5. **Optimizing in Isolation**: Test on real devices and networks
6. **Ignoring Third-Party Impact**: Third-party scripts can dominate performance
