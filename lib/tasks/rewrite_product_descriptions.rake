require "csv"
require "http"
require "json"

namespace :products do
  desc "Rewrite Product#description_short for all products using Anthropic Sonnet 4.6. Writes to tmp/description_short_rewrites.csv. Idempotent: re-running skips ids already in the output CSV."
  task rewrite_description_short: :environment do
    api_key = Rails.application.credentials.anthropic_api_key.presence ||
              Rails.application.credentials.dig(:anthropic, :api_key).presence ||
              ENV["ANTHROPIC_API_KEY"].presence
    abort("Missing Anthropic API key. Set credentials.anthropic_api_key or ANTHROPIC_API_KEY env var.") if api_key.blank?

    output_path = Rails.root.join("tmp", "description_short_rewrites.csv")
    existing_ids = load_existing_ids(output_path)

    ensure_header(output_path) if existing_ids.empty?

    products = Product.includes(:category).order(:id).reject { |p| existing_ids.include?(p.id) }
    if ENV["LIMIT"].present?
      products = products.first(ENV["LIMIT"].to_i)
      puts "LIMIT=#{ENV["LIMIT"]} set: processing first #{products.size} products only."
    end
    puts "Rewriting #{products.size} products (skipping #{existing_ids.size} already done)."
    puts "Output: #{output_path}"
    puts

    started = Time.now
    succeeded = 0
    failed = 0

    CSV.open(output_path, "a") do |csv|
      products.each_with_index do |product, idx|
        new_short = rewrite_description_short(product, api_key)
        csv << [ product.id, product.sku, product.description_short.to_s, new_short, new_short.length ]
        csv.flush
        succeeded += 1
        printf("[%3d/%d] %s  (%d chars) %s\n", idx + 1, products.size, product.sku, new_short.length, new_short.truncate(60))
      rescue => e
        failed += 1
        warn "[#{idx + 1}/#{products.size}] #{product.sku}: #{e.class}: #{e.message}"
        csv << [ product.id, product.sku, product.description_short.to_s, "", "ERROR: #{e.message}" ]
        csv.flush
      end
    end

    elapsed = (Time.now - started).round(1)
    puts
    puts "Done in #{elapsed}s. Succeeded: #{succeeded}, failed: #{failed}."
    puts "Review #{output_path} then run: bin/rails products:apply_description_short_rewrites"
  end

  desc "Apply approved rewrites from tmp/description_short_rewrites.csv to Product#description_short. Skips rows with empty or ERROR new value."
  task apply_description_short_rewrites: :environment do
    path = Rails.root.join("tmp", "description_short_rewrites.csv")
    abort("Not found: #{path}") unless File.exist?(path)

    updated = 0
    skipped = 0
    CSV.foreach(path, headers: true) do |row|
      new_value = row["new"].to_s.strip
      if new_value.empty? || new_value.start_with?("ERROR:")
        skipped += 1
        next
      end
      product = Product.find_by(id: row["id"])
      next skipped += 1 unless product
      product.update_columns(description_short: new_value)
      updated += 1
    end
    puts "Updated #{updated} products, skipped #{skipped}."
  end
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ANTHROPIC_MODEL = "claude-sonnet-4-6".freeze
ANTHROPIC_URL   = "https://api.anthropic.com/v1/messages".freeze
MAX_LENGTH      = 113
MAX_RETRIES     = 3

def load_existing_ids(path)
  return [] unless File.exist?(path)
  ids = []
  CSV.foreach(path, headers: true) { |row| ids << row["id"].to_i if row["id"] }
  ids
end

def ensure_header(path)
  CSV.open(path, "w") { |csv| csv << %w[id sku old new length] }
end

def rewrite_description_short(product, api_key)
  base_prompt = build_prompt(product)
  prompt = base_prompt
  last_candidate = nil

  attempts = 0
  loop do
    attempts += 1
    response = HTTP.headers(
      "x-api-key" => api_key,
      "anthropic-version" => "2023-06-01",
      "content-type" => "application/json"
    ).post(ANTHROPIC_URL, json: {
      model: ANTHROPIC_MODEL,
      max_tokens: 300,
      messages: [ { role: "user", content: prompt } ]
    })

    body = JSON.parse(response.body.to_s)
    if response.status.success?
      text = body.dig("content", 0, "text").to_s.strip
      candidate = sanitise(text)
      return candidate if valid?(candidate, product)
      last_candidate = candidate
      raise "validation failed for #{product.sku}: #{candidate.inspect}" if attempts >= MAX_RETRIES
      # On retry, tell the model what was wrong so it can correct
      prompt = retry_prompt(base_prompt, candidate, product)
      sleep(0.5)
      next
    else
      raise "Anthropic API error #{response.status}: #{body.inspect}" if attempts >= MAX_RETRIES
      sleep(2 ** attempts)
    end
  end
end

def retry_prompt(base, candidate, product)
  reasons = []
  reasons << "Your previous attempt was #{candidate.length} characters; the limit is #{MAX_LENGTH}. Shorten by removing a clause or tightening phrasing." if candidate.length > MAX_LENGTH
  reasons << "Your previous attempt was empty. Write at least one sentence." if candidate.empty?
  reasons << "Your previous attempt contains an em dash. Use commas, full stops, or semicolons instead." if candidate.include?("—")
  title = product.generated_title.to_s.downcase
  reasons << "Your previous attempt echoes the full product title verbatim. Lead with a benefit or feature instead." if title.length >= 12 && candidate.downcase.include?(title)

  "#{base}\n\nRETRY FEEDBACK\nYour previous attempt:\n#{candidate}\n\nReasons it was rejected:\n- #{reasons.join("\n- ")}\n\nTry again. Return only the corrected description_short."
end

def build_prompt(product)
  facts = {
    title: product.generated_title,
    category: product.category&.name,
    certifications: product.certifications.presence,
    pac_size: product.pac_size,
    size: product.size.presence,
    colour: product.colour.presence,
    material: product.material.presence,
    brand: product.brand.presence,
    volume_in_ml: product.volume_in_ml,
    diameter_in_mm: product.diameter_in_mm,
    height_in_mm: product.height_in_mm,
    width_in_mm: product.width_in_mm,
    length_in_mm: product.length_in_mm,
    description_short: product.description_short.presence,
    description_standard: product.description_standard.presence,
    description_detailed: product.description_detailed.presence
  }.compact

  facts_block = facts.map { |k, v| "- #{k}: #{v}" }.join("\n")

  <<~PROMPT
    Rewrite the Product#description_short field for an e-commerce product page
    on Afida (afida.com), a UK B2B compostable / eco packaging supplier.

    PRODUCT FACTS
    #{facts_block}

    GOAL
    Write a single description_short that will be shown on the product page
    AND used inside the page's meta description tag for Google SERPs.

    HARD CONSTRAINTS (any violation = reject)
    1. One sentence or two short sentences. Plain text. No markdown.
    2. Maximum #{MAX_LENGTH} characters total. Count strictly. If over,
       remove a clause or shorten a phrase.
    3. Do not echo the full product title verbatim at the start (e.g. do not
       open with "Vegware 12oz Kraft Paper Hot Cup"). Naming the product
       category in the description is fine.
    4. No em dashes ("—"). Use commas, full stops, or semicolons.
    5. No "we cover delivery" or "free delivery" wording (already appended
       elsewhere by the template).
    6. B2B tone. Talk to a cafe, restaurant, or catering buyer. No "perfect
       for your home" or "you'll love".

    STYLE
    - Lead with a buyer benefit, use case, or specific feature drawn from the
      description_detailed field.
    - Vary sentence openings. Do not start every product with the same hook
      phrase (e.g. "Stays rigid in..." or "Insulated..."). The opening should
      reflect this specific product's most distinctive feature.
    - Include the relevant capacity, dimension, or material detail only if it
      adds information not in the title.
    - Mention the certification (compostable / recyclable / biodegradable)
      only if it adds info not already in the title.
    - End with a concrete operational detail (stackable, hinged lid,
      grease-resistant, fits compatible lids, etc.) when available.

    Return ONLY the description_short text, no preamble, no quotes, no
    explanation. Do not exceed #{MAX_LENGTH} characters.
  PROMPT
end

def sanitise(text)
  text.gsub(/\A["']|["']\z/, "").gsub("—", ", ").strip
end

def valid?(text, product)
  return false if text.empty?
  return false if text.length > MAX_LENGTH
  return false if text.include?("—")
  title = product.generated_title.to_s.downcase
  return false if title.length >= 12 && text.downcase.include?(title)
  true
end
