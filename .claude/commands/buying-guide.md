---
description: Write a comprehensive, SEO-informed buying guide for a product category
allowed-tools: mcp__gsc__get_search_analytics, mcp__gsc__get_search_by_page_query, mcp__gsc__get_performance_overview, mcp__gsc__compare_search_periods, mcp__firecrawl__firecrawl_scrape, Read, Glob, Grep, Edit, Write, Bash
---

Write a comprehensive buying guide for the product category: $ARGUMENTS

## Category & Product Research

Before writing, gather information about the category and its products from the live site:

1. Determine whether the category is a top-level parent or a subcategory:
   - Parent categories live at `https://afida.com/categories/{slug}` (e.g. `/categories/cups-and-drinks`).
   - Subcategories live at `https://afida.com/categories/{parent-slug}/{slug}` (e.g. `/categories/cups-and-drinks/straws`).
2. Scrape the appropriate category page to understand what products are listed, how the category is presented, and what attributes are highlighted.
3. Scrape a few representative product pages from that category to understand the range of materials, sizes, features, and price points available.
4. Use this real product data to ground the buying guide in accurate, specific details rather than generic advice.

## Keyword Research

Before writing, gather keyword data to inform the guide's language and topics:

1. First, check if a keyword research file already exists (e.g. keyword_research.csv or similar) that contains relevant keywords for this category.
2. If relevant keyword data exists, use it. If not, use the Google Search Console MCP tools to research keywords:
   - Use `get_search_analytics` to find queries that are already driving impressions and clicks for this category and related pages on afida.com.
   - Use `get_search_by_page_query` on the category page URL to see which queries users search before landing on that page.
   - Use `compare_search_periods` to identify trending queries and seasonal patterns relevant to the category.
   - Look for high-impression, low-click queries as content opportunities; these are terms where the site appears in results but the current content does not fully address the searcher's intent.
3. From the research, identify:
   - Primary keyword: the highest-volume term that matches buyer intent for this category.
   - Secondary keywords (3-6): related terms, long-tail queries, and question-based searches buyers use.
   - Content themes: topics and concerns that search data reveals buyers care about.
4. Naturally weave the primary and secondary keywords throughout the guide. Do not keyword-stuff; every usage must read naturally. Prioritize the primary keyword in the introduction and summary.

## Audience

Buyers for restaurants, cafés, caterers, event planners, and food service businesses. They are practical, cost-conscious, and need to make informed bulk purchasing decisions.

## Structure

### 1. Introduction (2-3 sentences)
What this category covers and why it matters for food service operations. Incorporate the primary keyword naturally.

### 2. Key Factors to Consider
Cover all of the following that are relevant to the category, as separate subsections with a heading and 2-4 sentences each. Use secondary keywords and content themes from the research to inform which angles to emphasize:

- Material & Composition. Available materials (plastic, paper, bagasse, PLA, etc.), pros/cons of each, and when to choose what.
- Size & Capacity. How to pick the right dimensions for the intended use. Reference common sizing conventions if they exist.
- Temperature & Use Case. Hot vs cold suitability, microwave/freezer safety, grease resistance, leak-proofing.
- Sustainability & Compliance. Compostability, recyclability, certifications (e.g. BPI, OK Compost), and relevant regulations (single-use plastic bans, PFAS-free requirements).
- Cost & Value. Bulk pricing considerations, cost-per-unit thinking, when premium materials justify the price.
- Branding & Presentation. Custom printing options, how packaging appearance affects customer perception.

Skip any subsection that is genuinely irrelevant to the category. Do not force-fit. If the keyword research reveals a recurring buyer concern not covered above, add it as an additional subsection.

### 3. Pro Tips (2-4 bullet points)
Practical, non-obvious advice that an experienced buyer would share. Things like "order samples before committing to a large run" or "check lid compatibility across suppliers."

### 4. Summary
A 2-3 sentence wrap-up reinforcing the most important takeaway. Reincorporate the primary keyword.

## Writing Style
- Authoritative but approachable. No jargon without explanation.
- Concise: every sentence should earn its place. No filler.
- Use second person ("you") to address the reader directly.
- Do not use bold or semibold formatting in the output.
- Never use em dashes. Use full stops, semicolons, commas, or colons instead, whichever best preserves the meaning.
- No bullet points in the main subsections; use flowing prose.
- Bullet points are fine for the Pro Tips section only.
- Do not mention specific brands or suppliers.
- Total length: 400-600 words.

## Output Format
Return the buying guide content as Markdown:
- `##` for section headings (Introduction needs no heading)
- `###` for subsections under "Key Factors to Consider"
- Plain paragraphs for prose
- `-` list items for Pro Tips bullets only
- No HTML tags.

Also return a short metadata block before the guide:

```
PRIMARY KEYWORD: ...
SECONDARY KEYWORDS: ...
```

This metadata is for internal reference and should not appear in the final published content.

## Save to Database

After writing the guide, create a Rails migration that sets the `buying_guide` column on the matching category record. The category already has a `buying_guide` text column.

1. Find the category's slug by looking at the categories table in `db/schema.rb` or in existing seed/migration files.
2. Create a new migration file in `db/migrate/` using the standard Rails timestamp format.
3. In the migration, use `Category.find_by(slug: ...)&.update!(buying_guide: ...)` to set the content.
4. The buying guide value should be the Markdown content only (no metadata block).
5. Use a heredoc for the content to keep the migration readable.
