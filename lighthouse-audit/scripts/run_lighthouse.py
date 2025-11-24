#!/usr/bin/env python3
"""
Lighthouse Audit Runner

Runs Google Lighthouse audits and formats results for analysis.
Supports performance, accessibility, best practices, and SEO audits.
"""

import json
import subprocess
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Any


def check_lighthouse_installed() -> bool:
    """Check if Lighthouse CLI is installed."""
    try:
        subprocess.run(
            ["lighthouse", "--version"],
            capture_output=True,
            check=True
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def run_lighthouse_audit(
    url: str,
    output_path: str = None,
    categories: List[str] = None,
    preset: str = "desktop",
    chrome_flags: str = "--headless"
) -> Dict[str, Any]:
    """
    Run Lighthouse audit on the specified URL.

    Args:
        url: The URL to audit
        output_path: Optional path to save JSON report
        categories: List of categories to audit (performance, accessibility, best-practices, seo)
        preset: Device preset (desktop or mobile)
        chrome_flags: Chrome flags to pass to Lighthouse

    Returns:
        Dictionary containing audit results
    """
    if categories is None:
        categories = ["performance", "accessibility", "best-practices", "seo"]

    # Build Lighthouse command
    cmd = [
        "lighthouse",
        url,
        "--output=json",
        "--output-path=stdout",
        f"--preset={preset}",
        f"--chrome-flags={chrome_flags}",
        "--quiet"
    ]

    # Add category flags
    for category in categories:
        cmd.append(f"--only-categories={category}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )

        audit_data = json.loads(result.stdout)

        # Save to file if output path specified
        if output_path:
            with open(output_path, 'w') as f:
                json.dump(audit_data, f, indent=2)

        return audit_data

    except subprocess.CalledProcessError as e:
        print(f"Error running Lighthouse: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing Lighthouse output: {e}", file=sys.stderr)
        sys.exit(1)


def format_score(score: float) -> str:
    """Format score with color indicators."""
    if score is None:
        return "N/A"

    score_percent = int(score * 100)

    if score >= 0.9:
        indicator = "🟢"
    elif score >= 0.5:
        indicator = "🟡"
    else:
        indicator = "🔴"

    return f"{indicator} {score_percent}"


def extract_summary(audit_data: Dict[str, Any]) -> Dict[str, Any]:
    """Extract summary information from audit data."""
    categories = audit_data.get("categories", {})

    summary = {
        "url": audit_data.get("finalDisplayedUrl", ""),
        "fetch_time": audit_data.get("fetchTime", ""),
        "user_agent": audit_data.get("userAgent", ""),
        "scores": {}
    }

    for category_key, category_data in categories.items():
        summary["scores"][category_key] = {
            "title": category_data.get("title", ""),
            "score": category_data.get("score"),
            "description": category_data.get("description", "")
        }

    return summary


def extract_opportunities(audit_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extract performance opportunities from audit data."""
    opportunities = []
    audits = audit_data.get("audits", {})

    for audit_key, audit_info in audits.items():
        if audit_info.get("details", {}).get("type") == "opportunity":
            opportunities.append({
                "id": audit_key,
                "title": audit_info.get("title", ""),
                "description": audit_info.get("description", ""),
                "score": audit_info.get("score"),
                "savings": audit_info.get("details", {}).get("overallSavingsMs", 0),
                "display_value": audit_info.get("displayValue", "")
            })

    # Sort by savings (highest first)
    opportunities.sort(key=lambda x: x.get("savings", 0), reverse=True)

    return opportunities


def extract_diagnostics(audit_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extract diagnostic information from audit data."""
    diagnostics = []
    audits = audit_data.get("audits", {})

    for audit_key, audit_info in audits.items():
        if audit_info.get("details", {}).get("type") == "debugdata":
            continue

        score = audit_info.get("score")
        if score is not None and score < 1.0:
            diagnostics.append({
                "id": audit_key,
                "title": audit_info.get("title", ""),
                "description": audit_info.get("description", ""),
                "score": score,
                "display_value": audit_info.get("displayValue", "")
            })

    return diagnostics


def extract_failed_audits(audit_data: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
    """Extract failed audits by category."""
    failed_by_category = {
        "performance": [],
        "accessibility": [],
        "best-practices": [],
        "seo": []
    }

    categories = audit_data.get("categories", {})
    audits = audit_data.get("audits", {})

    for category_key, category_data in categories.items():
        audit_refs = category_data.get("auditRefs", [])

        for audit_ref in audit_refs:
            audit_id = audit_ref.get("id")
            audit_info = audits.get(audit_id, {})
            score = audit_info.get("score")

            # Only include failed audits (score < 1.0 or None for informative audits)
            if score is not None and score < 1.0:
                failed_by_category[category_key].append({
                    "id": audit_id,
                    "title": audit_info.get("title", ""),
                    "description": audit_info.get("description", ""),
                    "score": score,
                    "weight": audit_ref.get("weight", 0),
                    "display_value": audit_info.get("displayValue", "")
                })

    # Sort by weight (highest impact first)
    for category in failed_by_category:
        failed_by_category[category].sort(
            key=lambda x: x.get("weight", 0),
            reverse=True
        )

    return failed_by_category


def print_summary_report(audit_data: Dict[str, Any]) -> None:
    """Print a formatted summary report."""
    summary = extract_summary(audit_data)

    print("\n" + "="*80)
    print("LIGHTHOUSE AUDIT SUMMARY")
    print("="*80)
    print(f"\n📍 URL: {summary['url']}")
    print(f"⏰ Fetch Time: {summary['fetch_time']}\n")

    print("CATEGORY SCORES")
    print("-" * 80)
    for category_key, category_info in summary["scores"].items():
        score_display = format_score(category_info["score"])
        title = category_info["title"]
        print(f"{title:20} {score_display}")

    print("\n" + "="*80)


def print_detailed_report(audit_data: Dict[str, Any]) -> None:
    """Print a detailed report with opportunities and diagnostics."""
    print_summary_report(audit_data)

    # Opportunities
    opportunities = extract_opportunities(audit_data)
    if opportunities:
        print("\n⚡ PERFORMANCE OPPORTUNITIES")
        print("-" * 80)
        for i, opp in enumerate(opportunities[:10], 1):  # Top 10
            savings = opp.get("savings", 0)
            savings_display = f"~{savings}ms" if savings > 0 else ""
            print(f"\n{i}. {opp['title']}")
            if savings_display:
                print(f"   Potential Savings: {savings_display}")
            if opp.get("display_value"):
                print(f"   {opp['display_value']}")

    # Failed audits by category
    failed_audits = extract_failed_audits(audit_data)

    print("\n\n📊 FAILED AUDITS BY CATEGORY")
    print("-" * 80)

    for category, audits in failed_audits.items():
        if audits:
            print(f"\n{category.upper().replace('-', ' ')}")
            for i, audit in enumerate(audits[:5], 1):  # Top 5 per category
                score_display = format_score(audit['score'])
                print(f"  {i}. [{score_display}] {audit['title']}")
                if audit.get("display_value"):
                    print(f"      {audit['display_value']}")

    print("\n" + "="*80)


def print_actionable_report(audit_data: Dict[str, Any]) -> None:
    """Print an actionable report focused on fixes."""
    print_summary_report(audit_data)

    failed_audits = extract_failed_audits(audit_data)

    print("\n\n🔧 ACTIONABLE RECOMMENDATIONS")
    print("-" * 80)

    # Combine all failed audits across categories
    all_failed = []
    for category, audits in failed_audits.items():
        for audit in audits:
            all_failed.append({
                **audit,
                "category": category
            })

    # Sort by weight (impact) across all categories
    all_failed.sort(key=lambda x: x.get("weight", 0), reverse=True)

    print("\nTop issues to fix (sorted by impact):\n")

    for i, audit in enumerate(all_failed[:15], 1):  # Top 15 overall
        category = audit["category"].replace("-", " ").title()
        score_display = format_score(audit['score'])
        weight = audit.get("weight", 0)

        print(f"{i}. [{category}] {audit['title']}")
        print(f"   Score: {score_display} | Impact Weight: {weight}")

        # Clean up description (remove markdown links)
        description = audit['description'].split('[Learn more](')[0].strip()
        if description:
            print(f"   → {description}")

        if audit.get("display_value"):
            print(f"   → {audit['display_value']}")
        print()

    print("="*80)
    print("\n💡 TIP: Focus on high-impact issues (higher weight) first.")
    print("    Each 10-point score improvement can significantly affect user experience.\n")


def main():
    parser = argparse.ArgumentParser(
        description="Run Google Lighthouse audit on a webpage"
    )
    parser.add_argument(
        "url",
        help="URL to audit (can be local or remote)"
    )
    parser.add_argument(
        "--output",
        "-o",
        help="Path to save JSON report",
        default=None
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["summary", "detailed", "actionable", "all"],
        default="all",
        help="Report format (default: all)"
    )
    parser.add_argument(
        "--preset",
        "-p",
        choices=["desktop", "mobile"],
        default="desktop",
        help="Device preset (default: desktop)"
    )
    parser.add_argument(
        "--categories",
        "-c",
        nargs="+",
        choices=["performance", "accessibility", "best-practices", "seo"],
        default=None,
        help="Categories to audit (default: all)"
    )

    args = parser.parse_args()

    # Check if Lighthouse is installed
    if not check_lighthouse_installed():
        print("❌ Error: Lighthouse CLI is not installed.", file=sys.stderr)
        print("\nTo install Lighthouse:", file=sys.stderr)
        print("  npm install -g lighthouse", file=sys.stderr)
        sys.exit(1)

    print(f"\n🔍 Running Lighthouse audit on: {args.url}")
    print(f"📱 Preset: {args.preset}")
    if args.categories:
        print(f"📋 Categories: {', '.join(args.categories)}")
    print("\n⏳ This may take 30-60 seconds...\n")

    # Run audit
    audit_data = run_lighthouse_audit(
        url=args.url,
        output_path=args.output,
        categories=args.categories,
        preset=args.preset
    )

    # Print report based on format
    if args.format in ["summary", "all"]:
        print_summary_report(audit_data)

    if args.format in ["detailed", "all"]:
        print_detailed_report(audit_data)

    if args.format in ["actionable", "all"]:
        print_actionable_report(audit_data)

    if args.output:
        print(f"\n💾 Full JSON report saved to: {args.output}\n")


if __name__ == "__main__":
    main()
