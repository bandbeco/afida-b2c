require "http"
require "csv"
require "set"

namespace :ppp do
  desc "Fuzzy-match unmatched PPP-sourced products to live PPP Store API products " \
       "(name + size + colour + tier-aware price) and emit a review CSV. Read-only; writes no DB."
  task match_supplier_sku: :environment do
    api_base = "https://purpleplanetpackaging.co.uk/wp-json/wc/store/v1/products"
    out_path = ENV["OUT"].presence || Rails.root.join("tmp", "ppp_supplier_sku_fuzzy_review.csv").to_s

    # --- 1. Fetch the full live API catalogue (native JSON: exact prices, no transcription) ---
    api = []
    page = 1
    loop do
      resp = HTTP.timeout(30).headers(accept: "application/json")
                 .get(api_base, params: { per_page: 100, page: page, _fields: "sku,name,prices,images" })
      batch = JSON.parse(resp.to_s)
      break if !batch.is_a?(Array) || batch.empty?

      batch.each do |p|
        prices = p["prices"] || {}
        minor = (prices["currency_minor_unit"] || 2).to_i
        div = 10.0**minor
        pack = prices["price"].to_s.empty? ? nil : prices["price"].to_f / div
        # case price = top of range when present, else the single price
        range = prices["price_range"]
        kase = range && range["max_amount"] ? range["max_amount"].to_f / div : pack
        image = (p["images"] || []).first&.dig("src")
        api << { sku: p["sku"].to_s, name: p["name"].to_s, pack: pack, case: kase, image: image }
      end
      page += 1
      break if page > 12 # safety backstop
    end
    puts "Fetched #{api.size} live API products across #{page - 1} pages."

    # --- 2. Identify already-claimed API SKUs (don't re-assign) ---
    claimed = Product.unscoped.where.not(supplier_sku: [ nil, "" ]).pluck(:supplier_sku).map(&:strip).to_set
    api.reject! { |a| claimed.include?(a[:sku]) }
    puts "Unclaimed API pool: #{api.size}"

    # --- 3. Candidates: PPP-sourced production rows still missing supplier_sku ---
    # PPP-sourced = brand present and not one of the original Afida SKUs; we approximate by
    # "has supplier_sku blank AND brand is a known manufacturer". Adjust the filter if needed.
    candidates = Product.unscoped.where(supplier_sku: [ nil, "" ])
                        .where.not(brand: [ nil, "" ])
    puts "Candidate products (no supplier_sku, branded): #{candidates.count}"

    use_images = ENV["IMAGES"] == "1"
    img_cache = {} # url -> dhash (or nil if unfetchable)

    rows = candidates.map do |p|
      tiers = (p.pricing_tiers || []).map { |t| [ t["quantity"].to_i, t["price"].to_f ] }.sort
      pack = tiers.first&.last
      kase = tiers.last&.last || p.price&.to_f
      title = (p.generated_title rescue p.name).to_s

      scored = api.map { |a| score_candidate(title, pack, kase, a) }
                  .sort_by { |h| -h[:total] }

      # --- Optional image refinement: among the top text/price candidates, prefer the one
      # whose PPP photo matches the production photo (low perceptual-hash distance). ---
      img_distance = nil
      if use_images && scored.first && scored.first[:total] >= 5
        prod_hash = product_dhash(p)
        if prod_hash
          top = scored.first(4).select { |h| h[:api][:image] }
          ranked = top.map do |h|
            url = h[:api][:image]
            ah = (img_cache[url] ||= url_dhash(url))
            dist = ah ? hamming(prod_hash, ah) : 99
            h.merge(img_dist: dist)
          end.sort_by { |h| h[:img_dist] }
          # If a clearly-matching image exists (<=12) and it beats the text-best, adopt it.
          if ranked.first && ranked.first[:img_dist] <= 12
            chosen = ranked.first
            img_distance = chosen[:img_dist]
            scored = [ chosen ] + (scored - [ chosen ])
          end
        end
      end

      best = scored.first
      second = scored[1]
      margin = best[:total] - (second ? second[:total] : 0)
      # An image confirmation (<=10) promotes confidence even if text margin is thin.
      img_confirmed = img_distance && img_distance <= 10
      tier = if (best[:total] >= 9 && margin >= 2 && !best[:size_conflict] && !best[:colour_conflict]) || img_confirmed
               "auto"
      elsif best[:total] >= 5
               "review"
      else
               "no-match"
      end

      {
        production_sku: p.sku,
        current_title: title,
        proposed_ppp_sku: best[:total] >= 5 ? best[:api][:sku] : "",
        proposed_ppp_name: best[:total] >= 5 ? best[:api][:name] : "",
        your_pack: pack, your_case: kase,
        ppp_pack: best[:total] >= 5 ? best[:api][:pack] : "",
        ppp_case: best[:total] >= 5 ? best[:api][:case] : "",
        total: best[:total], text: best[:text], price_bonus: best[:price_bonus],
        img_dist: img_distance || "",
        margin: margin, tier: tier,
        alt_ppp_sku: (second && second[:total] >= 5) ? second[:api][:sku] : ""
      }
    end

    # --- 4. Flag collisions (same API sku proposed for >1 product) ---
    counts = Hash.new(0)
    rows.each { |r| counts[r[:proposed_ppp_sku]] += 1 if r[:proposed_ppp_sku] != "" }
    rows.each { |r| r[:collision] = (r[:proposed_ppp_sku] != "" && counts[r[:proposed_ppp_sku]] > 1) ? "DUP" : "" }

    order = { "no-match" => 0, "review" => 1, "auto" => 2 }
    rows.sort_by! { |r| [ order[r[:tier]], -r[:total] ] }

    CSV.open(out_path, "w") do |csv|
      csv << rows.first.keys
      rows.each { |h| csv << h.values }
    end

    puts "=" * 60
    puts "Wrote #{rows.size} rows to #{out_path}"
    rows.group_by { |r| r[:tier] }.sort_by { |_, v| -v.size }.each { |k, v| puts "  #{k}: #{v.size}" }
    auto = rows.select { |r| r[:tier] == "auto" }
    puts "  AUTO clean 1:1: #{auto.count { |r| r[:collision] != 'DUP' }}/#{auto.size}"
    puts "  AUTO price-confirmed: #{auto.count { |r| r[:price_bonus].to_i > 0 }}"
  end
end

STOPWORDS = %w[the and a of for with compostable recyclable takeaway hot cold cup cups lid lids
               series paper pla cpla rpet pe lined case pack vegware planetware edenware
               oz ml in inch mm x].to_set
COLOUR_TOKENS = %w[kraft white black brown green tree britain blue clear].freeze

def extract_sizes(s)
  s.downcase.scan(/(\d+(?:\.\d+)?)\s*(oz|ml|in|inch|cm|mm|l)\b/).map { |n, u| "#{n}#{u.sub('inch', 'in')}" } +
    s.scan(/\b(\d{2,3})\s*series\b/i).flatten.map { |n| "s#{n}" }
end

def extract_colours(s)
  d = s.downcase
  COLOUR_TOKENS.select { |c| d.include?(c) }
end

# Tier-aware price bonus: reward a candidate whose pack OR case price ratio sits in a
# plausible band (~same price). Never penalize - price only adds confidence.
def price_bonus(your_pack, your_case, api_pack, api_case)
  bonus = 0
  [ [ your_pack, api_pack ], [ your_case, api_case ] ].each do |you, ppp|
    next unless you && ppp && you > 0 && ppp > 0
    r = you / ppp
    bonus += 3 if r.between?(0.85, 1.20)
    bonus += 1 if !r.between?(0.85, 1.20) && r.between?(0.6, 1.6)
  end
  bonus
end

# --- Perceptual hashing (dHash) for image-based disambiguation ---
# Images are the same source photo at different sizes, so a resize-invariant
# perceptual hash + Hamming distance separates same-product (<=~10) from different (>=~16).
require "open3"
require "tempfile"

def dhash_from_blob(bytes)
  return nil if bytes.nil? || bytes.empty?
  Tempfile.create([ "ppimg", ".img" ]) do |f|
    f.binmode
    f.write(bytes)
    f.flush
    out, _err, st = Open3.capture3("magick", f.path, "-resize", "9x8!",
                                   "-colorspace", "Gray", "-depth", "8", "GRAY:-")
    return nil unless st.success?
    px = out.bytes
    return nil if px.size < 72
    bits = +""
    8.times do |row|
      8.times do |col|
        bits << (px[row * 9 + col] < px[row * 9 + col + 1] ? "1" : "0")
      end
    end
    bits
  end
rescue StandardError
  nil
end

def url_dhash(url)
  return nil if url.to_s.empty?
  resp = HTTP.timeout(20).follow.get(url)
  return nil unless resp.status.success?
  dhash_from_blob(resp.to_s)
rescue StandardError
  nil
end

def product_dhash(product)
  return nil unless product.respond_to?(:product_photo) && product.product_photo.attached?
  dhash_from_blob(product.product_photo.download)
rescue StandardError
  nil
end

def hamming(a, b)
  return 99 if a.nil? || b.nil? || a.length != b.length
  a.chars.zip(b.chars).count { |x, y| x != y }
end

def score_candidate(title, your_pack, your_case, api_product)
  ct = title.downcase.gsub(/[^a-z0-9 ]/, " ").split.to_set
  at = api_product[:name].downcase.gsub(/[^a-z0-9 ]/, " ").split.to_set
  meaningful = (ct & at).reject { |t| STOPWORDS.include?(t) }
  base = meaningful.size

  csz = extract_sizes(title).to_set
  asz = extract_sizes(api_product[:name]).to_set
  size_overlap = (csz & asz).size
  size_conflict = csz.any? && asz.any? && (csz & asz).empty?

  ccol = extract_colours(title).to_set
  acol = extract_colours(api_product[:name]).to_set
  colour_overlap = (ccol & acol).size
  colour_conflict = ccol.any? && acol.any? && (ccol & acol).empty?

  text = base + size_overlap * 3 + colour_overlap * 2
  text -= 5 if size_conflict
  text -= 3 if colour_conflict

  pb = price_bonus(your_pack, your_case, api_product[:pack], api_product[:case])

  {
    api: api_product, text: text, price_bonus: pb, total: text + pb,
    size_conflict: size_conflict, colour_conflict: colour_conflict
  }
end
