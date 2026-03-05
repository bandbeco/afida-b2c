class AddMissingCategoryMetadata < ActiveRecord::Migration[8.1]
  def up
    categories = {
      "bagasse-eco-range" => {
        meta_title: "Bagasse Eco Packaging | Compostable Food Containers | Bulk UK | Afida",
        meta_description: "Compostable bagasse food packaging for cafes and takeaways. Clamshells burger boxes and food containers made from sugarcane fibre. Bulk pricing with free UK delivery over £100.",
        description: "Eco-friendly bagasse food packaging made from sugarcane fibre for restaurants cafes and takeaway businesses. Our compostable range includes clamshell boxes burger boxes gourmet containers and food boxes in a variety of sizes. Bagasse is naturally grease-resistant microwave-safe and fully compostable making it the ideal alternative to polystyrene and plastic food packaging. Perfect for businesses looking to reduce their environmental impact without compromising on quality. Bulk pricing with free UK delivery on orders over £100."
      },
      "bags" => {
        meta_title: "Paper Bags & Carrier Bags | Kraft & Plastic | Bulk UK | Afida",
        meta_description: "Paper bags carrier bags and kraft bags for takeaway and retail. Flat handle and twisted handle bags in all sizes. Bulk pricing with free UK delivery over £100.",
        description: "Paper bags and carrier bags for takeaway food delivery and retail. Our range includes kraft flat handle bags in small and large sizes twisted handle paper bags and plastic carrier bags for heavier items. Paper bags with handles are the eco-friendly choice for cafes bakeries and restaurants. Available in kraft brown black and white finishes to match your brand. Bulk pricing with free UK delivery on orders over £100."
      },
      "cutlery" => {
        meta_title: "Disposable Wooden Cutlery | Bamboo & Compostable | Bulk UK | Afida",
        meta_description: "Disposable wooden cutlery and bamboo cutlery for cafes and takeaways. Forks knives spoons and cutlery kits. Eco-friendly and compostable. Free UK delivery over £100.",
        description: "Eco-friendly disposable cutlery for restaurants cafes and takeaway businesses. Our range includes wooden forks knives and spoons made from sustainable birchwood bamboo chopsticks and compostable cornstarch cutlery kits. Available as individual items or convenient multi-piece kits wrapped with napkins for grab-and-go service. All our disposable cutlery is biodegradable and compostable providing a sustainable alternative to single-use plastic. Bulk pricing with free UK delivery on orders over £100."
      },
      "food-containers" => {
        meta_title: "Food Containers & Deli Pots | Portion Pots & Lids | Bulk UK | Afida",
        meta_description: "Disposable food containers portion pots and deli containers with lids. PLA paper and compostable options for cafes and restaurants. Free UK delivery over £100.",
        description: "Disposable food containers and deli pots for cafes restaurants and food-to-go businesses. Our range includes portion pots for sauces and dressings soup cups with secure lids deli containers and food storage pots in sizes from 1oz to 32oz. Available in PLA paper and compostable materials with matching lids for a secure seal. Perfect for grab-and-go counters salad bars and catering operations. Bulk pricing with free UK delivery on orders over £100."
      },
      "plates-trays" => {
        meta_title: "Disposable Plates & Trays | Palm Leaf & Bagasse | Bulk UK | Afida",
        meta_description: "Eco-friendly disposable plates and trays for catering and events. Palm leaf plates bagasse plates and platter boxes. Bulk pricing with free UK delivery over £100.",
        description: "Eco-friendly disposable plates and serving trays for catering events and food service. Our range includes premium palm leaf plates in round oval and rectangular shapes compostable bagasse plates and platter boxes for buffets and corporate catering. Palm leaf plates offer a natural elegant look perfect for weddings events and upscale food service. All our disposable plates and trays are biodegradable and compostable. Bulk pricing with free UK delivery on orders over £100."
      },
      "takeaway-boxes" => {
        meta_title: "Takeaway Boxes | Burger Boxes & Chip Boxes | Kraft | Bulk UK | Afida",
        meta_description: "Kraft takeaway boxes for restaurants and takeaways. Burger boxes chip boxes fish and chip boxes and deli boxes. Bulk pricing with free UK delivery over £100.",
        description: "Kraft takeaway boxes for fish and chip shops burger bars and takeaway restaurants. Our range includes burger boxes chip boxes leakproof food pots and folded board trays in a variety of sizes. Made from recyclable kraft board these takeaway boxes keep food warm and secure during transport. The natural kraft finish is popular with eco-conscious customers and works well with custom stamps or stickers for branding. Bulk pricing with free UK delivery on orders over £100."
      }
    }

    categories.each do |slug, data|
      execute <<-SQL.squish
        UPDATE categories
        SET meta_title = #{connection.quote(data[:meta_title])},
            meta_description = #{connection.quote(data[:meta_description])},
            description = #{connection.quote(data[:description])},
            updated_at = NOW()
        WHERE slug = #{connection.quote(slug)}
          AND (meta_title IS NULL OR meta_title = '')
      SQL
    end
  end

  def down
    %w[bagasse-eco-range bags cutlery food-containers plates-trays takeaway-boxes].each do |slug|
      execute <<-SQL.squish
        UPDATE categories
        SET meta_title = NULL, meta_description = NULL, description = NULL, updated_at = NOW()
        WHERE slug = #{connection.quote(slug)}
      SQL
    end
  end
end
