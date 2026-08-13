namespace :pseo do
  desc "Generate business type pages from niche taxonomy using Claude API"
  task generate_business_pages: :environment do
    require "net/http"
    require "json"
    require "uri"

    niches_dir = Rails.root.join("lib/data/pseo/niches")
    output_dir = Rails.root.join("lib/data/pseo/pages/for")
    FileUtils.mkdir_p(output_dir)

    api_key = ENV.fetch("ANTHROPIC_API_KEY") do
      Rails.application.credentials.dig(:anthropic, :api_key)
    end

    unless api_key.present?
      puts "ERROR: ANTHROPIC_API_KEY not set. Set via environment variable or Rails credentials."
      exit 1
    end

    niche_files = Dir.glob(niches_dir.join("*.json")).sort
    if niche_files.empty?
      puts "ERROR: No niche files found in #{niches_dir}"
      exit 1
    end

    # Allow filtering to specific slugs via SLUGS env var
    if ENV["SLUGS"].present?
      target_slugs = ENV["SLUGS"].split(",").map(&:strip)
      niche_files = niche_files.select { |f| target_slugs.include?(File.basename(f, ".json")) }
    end

    total = niche_files.size
    successes = 0
    failures = []

    niche_files.each_with_index do |niche_file, index|
      slug = File.basename(niche_file, ".json")
      output_path = output_dir.join("#{slug}.json")

      # Skip if already generated (use FORCE=1 to regenerate)
      if output_path.exist? && ENV["FORCE"] != "1"
        puts "[#{index + 1}/#{total}] SKIP #{slug} (already exists, use FORCE=1 to regenerate)"
        successes += 1
        next
      end

      puts "[#{index + 1}/#{total}] Generating #{slug}..."

      niche_context = JSON.parse(File.read(niche_file))
      retries = 0
      max_retries = 2

      begin
        page_data = generate_page(api_key, niche_context)

        # Validate the generated page
        validator = PseoPageValidatorService.new(page_data)
        result = validator.validate

        unless result[:valid]
          raise "Validation failed: #{result[:errors].join(', ')}"
        end

        File.write(output_path, JSON.pretty_generate(page_data))
        puts "  ✓ Generated and validated #{slug}"
        successes += 1

      rescue => e
        retries += 1
        if retries <= max_retries
          puts "  ✗ Error (attempt #{retries}/#{max_retries + 1}): #{e.message}"
          puts "  Retrying..."
          sleep(2 * retries)
          retry
        else
          puts "  ✗ FAILED after #{max_retries + 1} attempts: #{e.message}"
          failures << { slug: slug, error: e.message }
        end
      end

      # Rate limiting: pause between API calls
      sleep(1) if index < total - 1
    end

    puts "\n#{'=' * 60}"
    puts "Generation complete: #{successes}/#{total} succeeded"
    if failures.any?
      puts "\nFailed pages:"
      failures.each { |f| puts "  - #{f[:slug]}: #{f[:error]}" }
    end
  end

  desc "Validate all generated PSEO pages against schema"
  task validate: :environment do
    pages_dir = Rails.root.join("lib/data/pseo/pages/for")

    unless pages_dir.exist?
      puts "No pages directory found at #{pages_dir}"
      exit 1
    end

    page_files = Dir.glob(pages_dir.join("*.json")).sort
    if page_files.empty?
      puts "No page files found in #{pages_dir}"
      exit 1
    end

    total = page_files.size
    valid_count = 0
    invalid_pages = []

    page_files.each do |file|
      slug = File.basename(file, ".json")
      data = JSON.parse(File.read(file), symbolize_names: true)

      validator = PseoPageValidatorService.new(data)
      result = validator.validate

      if result[:valid]
        puts "  ✓ #{slug}"
        valid_count += 1
      else
        puts "  ✗ #{slug}"
        result[:errors].each { |e| puts "    - #{e}" }
        invalid_pages << { slug: slug, errors: result[:errors] }
      end
    end

    puts "\n#{'=' * 60}"
    puts "Validation complete: #{valid_count}/#{total} valid"
    if invalid_pages.any?
      puts "\n#{invalid_pages.size} invalid page(s) need attention."
      exit 1
    end
  end

  desc "List all available niche slugs"
  task list_niches: :environment do
    niches_dir = Rails.root.join("lib/data/pseo/niches")
    pages_dir = Rails.root.join("lib/data/pseo/pages/for")

    niche_files = Dir.glob(niches_dir.join("*.json")).sort
    puts "Available niches (#{niche_files.size} total):\n\n"

    niche_files.each do |file|
      slug = File.basename(file, ".json")
      generated = pages_dir.join("#{slug}.json").exist?
      status = generated ? "✓" : "·"
      puts "  #{status} #{slug}"
    end

    generated_count = Dir.glob(pages_dir.join("*.json")).size
    puts "\n#{generated_count}/#{niche_files.size} pages generated"
  end
end

def generate_page(api_key, niche_context)
  uri = URI("https://api.anthropic.com/v1/messages")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 120

  system_prompt = <<~PROMPT
    You are a packaging industry expert writing genuinely useful content for the Afida website (afida.com), a UK eco-friendly packaging supplier.

    You are generating a structured page for the business type: #{niche_context["name"]}.

    Context about this business type:
    - Target audience: #{niche_context["audience"]}
    - Key pain points: #{niche_context["pain_points"].join("; ")}
    - Top product categories: #{niche_context["top_products"].join(", ")}
    - Compliance concerns: #{niche_context["compliance_concerns"].join("; ")}
    - Order frequency: #{niche_context["order_frequency"]}
    - Average order size: #{niche_context["avg_order_size"]}
    - Sustainability pressure: #{niche_context["sustainability_pressure"]}
    - Branding interest: #{niche_context["branding_interest"]}

    Afida context:
    - UK eco-friendly packaging for food businesses
    - USPs: Free delivery over £100, competitive wholesale pricing, eco/Vegware range, custom branding
    - Notable clients: The Ritz, Marriott, Hawksmoor, La Gelatiera, Vincenzo's Pizzeria
    - Categories: Cups & Drinks, Hot Food, Cold Food & Salads, Tableware, Bags & Wraps, Supplies & Essentials, Vegware, Branded

    STRICT CONSTRAINTS:
    - Exactly 4-6 packaging_needs entries (choose based on what's relevant to this business type)
    - Exactly 5 faqs entries
    - hero.intro: EXACTLY 150-200 words (count carefully)
    - Each FAQ answer: EXACTLY 60-100 words (count carefully)
    - All content must be specific to #{niche_context["name"]} — no generic packaging copy
    - Write in a helpful, expert tone — this should be a useful guide, not an ad
    - Use UK English spelling
    - recommended_products should be slugified product names that would exist in a packaging catalogue
  PROMPT

  user_prompt = <<~PROMPT
    Generate a complete page data JSON for "#{niche_context["name"]}" following this exact schema. Return ONLY valid JSON, no markdown code fences, no explanation.

    {
      "meta": {
        "slug": "#{niche_context["slug"]}",
        "business_type": "#{niche_context["name"]}",
        "seo_title": "Packaging Supplies for #{niche_context["name"]} | Afida",
        "seo_description": "...",
        "keywords": ["...", "...", "...", "...", "..."]
      },
      "hero": {
        "headline": "...",
        "subheadline": "...",
        "intro": "... (EXACTLY 150-200 words)"
      },
      "packaging_needs": [
        {
          "category": "...",
          "why_it_matters": "...",
          "recommended_products": ["slug-1", "slug-2"],
          "buying_tip": "..."
        }
      ],
      "sustainability_section": {
        "intro": "...",
        "options": [
          { "name": "...", "benefit": "..." }
        ]
      },
      "faqs": [
        { "question": "...", "answer": "... (EXACTLY 60-100 words)" }
      ],
      "social_proof": {
        "relevant_clients": ["The Ritz", "Hawksmoor"],
        "testimonial_angle": "..."
      }
    }
  PROMPT

  request = Net::HTTP::Post.new(uri)
  request["Content-Type"] = "application/json"
  request["x-api-key"] = api_key
  request["anthropic-version"] = "2023-06-01"
  request.body = {
    model: "claude-sonnet-4-20250514",
    max_tokens: 4096,
    system: system_prompt,
    messages: [
      { role: "user", content: user_prompt }
    ]
  }.to_json

  response = http.request(request)

  unless response.code.to_i == 200
    raise "API error (#{response.code}): #{response.body}"
  end

  response_data = JSON.parse(response.body)
  content = response_data.dig("content", 0, "text")

  raise "Empty response from API" if content.blank?

  # Strip markdown code fences if present
  content = content.gsub(/\A```(?:json)?\s*\n?/, "").gsub(/\n?```\s*\z/, "")

  JSON.parse(content, symbolize_names: true)
end
