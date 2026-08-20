require "csv"
require "http"
require "json"

# Propose/review/apply pipeline for populating product_compatible_lids at
# scale. Flow: lids:export_inventory (run in prod, copy the CSV out) ->
# lids:propose_mappings (run locally, LLM-assisted; review/edit the CSV) ->
# lids:apply_mappings (dry-run, then APPLY=1 in prod). SKU-keyed throughout so
# the same CSV works against any environment.
namespace :lids do
  CONTAINER_CATEGORY_SLUGS = %w[
    hot-cups cold-cups-and-lids ice-cream-cups soup-containers bowls-and-lids
    portion-pots-and-lids food-containers-and-lids deli-containers
  ].freeze

  INVENTORY_PATH = "tmp/lid_mapping/inventory.csv".freeze
  PROPOSED_PATH = "tmp/lid_mapping/proposed_mappings.csv".freeze
  INVENTORY_HEADERS = %w[role sku name family_name category_slug product_type active size volume_in_ml diameter_in_mm pac_size price current_lid_skus current_default_lid_sku].freeze
  PROPOSED_HEADERS = %w[container_sku container_name lid_sku lid_name lid_family sort_order is_default confidence rationale].freeze

  desc "Export container + lid inventory to #{INVENTORY_PATH} (CATEGORIES= to override container category slugs)"
  task export_inventory: :environment do
    slugs = ENV["CATEGORIES"].presence&.split(/[,\s]+/) || CONTAINER_CATEGORY_SLUGS
    known = Category.pluck(:slug)
    missing = slugs - known
    puts "WARNING: category slugs not found: #{missing.join(', ')}" if missing.any?
    other = known - slugs
    puts "Categories present but not exported as containers: #{other.join(', ')}"

    # Union computed as id sets so the customized_instance exclusion applies
    # to BOTH branches (a naive .or scopes the exclusion to one side only).
    already_mapped_ids = ProductCompatibleLid.unscoped.distinct.pluck(:product_id)
    in_category_ids = Product.active.joins(:category).where(categories: { slug: slugs }).ids
    containers = Product.active
                        .where(id: in_category_ids | already_mapped_ids)
                        .where.not(product_type: "customized_instance")
                        .includes(:product_family, :category, product_compatible_lids: :compatible_lid)
                        .reject(&:lid_product?)
    lids = Product.active.lid_candidates.includes(:product_family, :category)

    path = Rails.root.join(INVENTORY_PATH)
    FileUtils.mkdir_p(File.dirname(path))
    CSV.open(path, "w") do |csv|
      csv << INVENTORY_HEADERS
      (containers.map { |p| [ "container", p ] } + lids.map { |p| [ "lid", p ] }).each do |role, p|
        rows = p.product_compatible_lids.includes(:compatible_lid).order(:sort_order)
        csv << [
          role, p.sku, p.generated_title, p.product_family&.name, p.category&.slug,
          p.product_type, p.active, p.size, p.volume_in_ml, p.diameter_in_mm,
          p.pac_size, p.price,
          rows.map { |r| r.compatible_lid.sku }.join("|"),
          rows.find(&:default?)&.compatible_lid&.sku
        ]
      end
    end
    puts "Wrote #{containers.size} containers + #{lids.size} lids to #{path}"
  end

  desc "LLM-propose container->lid mappings from the inventory CSV into #{PROPOSED_PATH} (idempotent; LIMIT= to cap container families)"
  task propose_mappings: :environment do
    api_key = Rails.application.credentials.anthropic_api_key.presence ||
              Rails.application.credentials.dig(:anthropic, :api_key).presence ||
              ENV["ANTHROPIC_API_KEY"].presence
    abort("Missing Anthropic API key. Set credentials.anthropic_api_key or ANTHROPIC_API_KEY env var.") if api_key.blank?

    inventory_path = ENV["INVENTORY_PATH"].presence || Rails.root.join(INVENTORY_PATH).to_s
    abort("Not found: #{inventory_path}. Run lids:export_inventory first.") unless File.exist?(inventory_path)

    rows = CSV.read(inventory_path, headers: true)
    containers = rows.select { |r| r["role"] == "container" }
    lids = rows.select { |r| r["role"] == "lid" }
    abort("Inventory has no lids") if lids.empty?

    output_path = Rails.root.join(PROPOSED_PATH)
    done_skus = File.exist?(output_path) ? CSV.read(output_path, headers: true).map { |r| r["container_sku"] }.to_set : Set.new
    CSV.open(output_path, "w") { |csv| csv << PROPOSED_HEADERS } if done_skus.empty?

    lid_index = lids.index_by { |r| r["sku"] }
    lid_inventory_text = lids.map { |l|
      "- sku=#{l['sku']} | #{l['name']} | family=#{l['family_name']} | size=#{l['size']} | diameter_mm=#{l['diameter_in_mm']} | volume_ml=#{l['volume_in_ml']}"
    }.join("\n")

    families = containers.reject { |c| done_skus.include?(c["sku"]) }.group_by { |c| c["family_name"] || c["sku"] }
    families = families.first(ENV["LIMIT"].to_i).to_h if ENV["LIMIT"].present?
    puts "Proposing for #{families.size} container families (#{done_skus.size} containers already done)."

    CSV.open(output_path, "a") do |csv|
      families.each_with_index do |(family, members), idx|
        proposals = lids_propose_for_family(family, members, lid_inventory_text, api_key)
        members.each do |container|
          container_rows = proposals.select { |p| p["container_sku"] == container["sku"] }
                                    .select { |p| lid_index.key?(p["lid_sku"]) }
          if container_rows.none? { |p| p["is_default"] == true } && container_rows.any?
            container_rows.first["is_default"] = true
          end
          container_rows.each_with_index do |p, sort_order|
            lid = lid_index[p["lid_sku"]]
            csv << [ container["sku"], container["name"], lid["sku"], lid["name"], lid["family_name"],
                     sort_order, p["is_default"] == true, p["confidence"], p["rationale"] ]
          end
          puts "  #{container['sku']}: #{container_rows.size} lids"
        end
        csv.flush
        printf("[%d/%d] %s done\n", idx + 1, families.size, family)
      rescue => e
        warn "[#{idx + 1}/#{families.size}] #{family}: #{e.class}: #{e.message}"
      end
    end
    puts "Review #{output_path}, then dry-run lids:apply_mappings"
  end

  desc "Apply reviewed mappings from CSV_PATH (default #{PROPOSED_PATH}). Dry run unless APPLY=1. Containers absent from the CSV are untouched."
  task apply_mappings: :environment do
    path = ENV["CSV_PATH"].presence || Rails.root.join(PROPOSED_PATH).to_s
    abort("Not found: #{path}") unless File.exist?(path)
    apply = ENV["APPLY"] == "1"
    puts apply ? "Applying..." : "DRY RUN (set APPLY=1 to write)"

    created = removed = updated = unchanged = 0
    unknown_skus = []
    zero_lid_containers = []

    CSV.read(path, headers: true).group_by { |r| r["container_sku"] }.each do |container_sku, rows|
      container = Product.unscoped.find_by(sku: container_sku)
      (unknown_skus << container_sku) && next unless container

      desired = rows.filter_map { |r|
        lid = Product.unscoped.find_by(sku: r["lid_sku"])
        unknown_skus << r["lid_sku"] unless lid
        { lid: lid, sort_order: r["sort_order"].to_i, default: r["is_default"].to_s == "true" } if lid
      }.uniq { |d| d[:lid].id }
      zero_lid_containers << container_sku if desired.empty?
      desired.first[:default] = true if desired.any? && desired.none? { |d| d[:default] }

      existing = ProductCompatibleLid.where(product_id: container.id).index_by(&:compatible_lid_id)
      desired_ids = desired.map { |d| d[:lid].id }

      existing.each_value do |row|
        next if desired_ids.include?(row.compatible_lid_id)
        removed += 1
        row.destroy! if apply
      end

      desired.each do |d|
        row = existing[d[:lid].id]
        if row.nil?
          created += 1
          ProductCompatibleLid.create!(product: container, compatible_lid: d[:lid], sort_order: d[:sort_order], default: d[:default]) if apply
        elsif row.sort_order != d[:sort_order] || row.default? != d[:default]
          updated += 1
          row.update!(sort_order: d[:sort_order], default: d[:default]) if apply
        else
          unchanged += 1
        end
      end
    end

    puts "#{apply ? '' : '[dry-run] '}created: #{created}, removed: #{removed}, updated: #{updated}, unchanged: #{unchanged}"
    puts "Unknown SKUs skipped: #{unknown_skus.uniq.join(', ')}" if unknown_skus.any?
    puts "Containers ending with zero lids: #{zero_lid_containers.join(', ')}" if zero_lid_containers.any?
    puts "Total mappings now: #{ProductCompatibleLid.count}"
  end
end

LIDS_ANTHROPIC_MODEL = "claude-sonnet-4-6".freeze
LIDS_ANTHROPIC_URL = "https://api.anthropic.com/v1/messages".freeze

def lids_propose_for_family(family_name, members, lid_inventory_text, api_key)
  container_text = members.map { |c|
    "- sku=#{c['sku']} | #{c['name']} | size=#{c['size']} | diameter_mm=#{c['diameter_in_mm']} | volume_ml=#{c['volume_in_ml']} | current_lids=#{c['current_lid_skus']}"
  }.join("\n")

  prompt = <<~PROMPT
    You match food-packaging containers to the lids that physically fit them, for a UK eco-packaging shop (Afida).

    CONTAINER FAMILY: #{family_name}
    #{container_text}

    FULL LID INVENTORY:
    #{lid_inventory_text}

    Rules:
    - A lid fits when its diameter matches the container's rim (diameter_mm is the best signal when present; oz sizes must correspond, e.g. an 8oz hot cup takes an 80mm sip lid, a 4oz cup a 62mm lid).
    - Lid family names often encode fit ("Fits 89 Series", "Gourmet Lid (Size 4)", "For 500, 750"); trust these hints.
    - Match material sensibly: hot cup lids for hot cups, dome/flat smoothie lids for cold cups, soup lids for soup containers, etc.
    - Only propose lids you are reasonably confident fit. It is better to propose nothing than a wrong lid; wrong fits cost the shop returns.
    - is_default: exactly one per container, the most standard everyday choice (e.g. plain sip lid over dome).
    - confidence: high | medium | low. rationale: one short clause naming the signal used.

    Return ONLY a JSON array (no markdown fences), one object per (container, lid) pair:
    [{"container_sku": "...", "lid_sku": "...", "is_default": true, "confidence": "high", "rationale": "..."}]
    Containers with no fitting lid simply get no entries.
  PROMPT

  attempts = 0
  begin
    attempts += 1
    response = HTTP.timeout(connect: 10, write: 30, read: 300)
                   .headers(
      "x-api-key" => api_key,
      "anthropic-version" => "2023-06-01",
      "content-type" => "application/json"
    ).post(LIDS_ANTHROPIC_URL, json: {
      model: LIDS_ANTHROPIC_MODEL,
      max_tokens: 8000,
      messages: [ { role: "user", content: prompt } ]
    })
    body = JSON.parse(response.body.to_s)
    raise "Anthropic API error #{response.status}: #{body.inspect}" unless response.status.success?

    text = body.dig("content", 0, "text").to_s.strip.sub(/\A```(?:json)?/, "").sub(/```\z/, "").strip
    JSON.parse(text)
  rescue => e
    raise if attempts >= 3
    sleep(2**attempts)
    retry
  end
end
