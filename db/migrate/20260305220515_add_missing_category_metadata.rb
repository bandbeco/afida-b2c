class AddMissingCategoryMetadata < ActiveRecord::Migration[8.1]
  def up
    categories = {
      "bagasse-eco-range" => {
        meta_title: "Bagasse Food Containers | Compostable Takeaway Containers | Bulk UK | Afida",
        meta_description: "Compostable bagasse food containers and biodegradable food packaging for cafes and takeaways. Sugarcane clamshells burger boxes and bagasse boxes. Sustainable food packaging with free UK delivery over £100.",
        description: "Compostable bagasse food containers and sustainable food packaging for restaurants cafes and takeaway businesses. Our biodegradable food packaging range includes bagasse boxes clamshells burger boxes and gourmet containers made from sugarcane fibre. Bagasse is naturally grease-resistant microwave-safe and fully compostable making it the ideal eco friendly food packaging alternative to polystyrene and plastic. Perfect for businesses switching to compostable takeaway containers without compromising on quality. Bulk pricing with free UK delivery on orders over £100."
      },
      "bags" => {
        meta_title: "Paper Bags with Handles | Brown Paper Bags & Carrier Bags | Bulk UK | Afida",
        meta_description: "Paper bags with handles for takeaway and retail. Brown paper bags kraft paper bags and paper carrier bags in all sizes. Printed paper bags available. Free UK delivery over £100.",
        description: "Paper bags with handles and paper carrier bags for takeaway food delivery and retail businesses. Our range includes brown paper bags with flat and twisted handles kraft paper bags in small and large sizes and carrier bags for heavier items. Looking for printed paper bags with your branding? We offer custom options too. White paper bags and kraft paper bags are the eco-friendly choice for cafes bakeries and restaurants replacing single-use plastic bags. Bulk pricing with free UK delivery on orders over £100."
      },
      "cutlery" => {
        meta_title: "Disposable Wooden Cutlery | Bamboo Cutlery & Compostable Cutlery | Bulk UK | Afida",
        meta_description: "Disposable wooden cutlery bamboo cutlery and compostable cutlery for cafes and takeaways. Wooden forks knives spoons and eco friendly cutlery kits. Free UK delivery over £100.",
        description: "Disposable wooden cutlery and bamboo cutlery for restaurants cafes and takeaway businesses. Our compostable cutlery range includes wooden forks wooden knives and spoons made from sustainable birchwood bamboo chopsticks and cornstarch cutlery kits. Available as individual items or convenient eco friendly cutlery sets wrapped with napkins for grab-and-go service. All our disposable wooden cutlery is biodegradable and compostable providing a sustainable alternative to single-use plastic cutlery. Wholesale wooden cutlery available with bulk pricing and free UK delivery on orders over £100."
      },
      "food-containers" => {
        meta_title: "Food Containers & Lids | Disposable Food Containers | Bulk UK | Afida",
        meta_description: "Disposable food containers and food containers with lids for cafes and restaurants. Takeaway containers portion pots and deli pots in PLA paper and compostable materials. Free UK delivery over £100.",
        description: "Disposable food containers and takeaway containers for cafes restaurants and food-to-go businesses. Our food containers with lids range includes portion pots for sauces and dressings soup cups with secure lids deli containers and food storage pots in sizes from 1oz to 32oz. Available in PLA paper and compostable materials for eco friendly food packaging. Perfect for grab-and-go counters salad bars and catering operations needing reliable food containers and lids. Bulk pricing with free UK delivery on orders over £100."
      },
      "plates-trays" => {
        meta_title: "Disposable Plates | Paper Plates & Bamboo Plates | Catering | Bulk UK | Afida",
        meta_description: "Disposable plates for catering and events. Paper plates bamboo disposable plates bagasse plates catering plates and platter boxes. Disposable bowls available. Free UK delivery over £100.",
        description: "Disposable plates and catering plates for events food service and hospitality. Our range includes bamboo disposable plates with a natural elegant finish paper plates for everyday use compostable bagasse plates and platter boxes for buffets and corporate catering. We also stock disposable bowls in various sizes. Palm leaf plates offer a premium look perfect for weddings events and upscale food service. All our disposable plates and serving trays are biodegradable and compostable. Bulk pricing with free UK delivery on orders over £100."
      },
      "takeaway-boxes" => {
        meta_title: "Takeaway Boxes | Takeaway Food Boxes & Burger Boxes | Kraft | Bulk UK | Afida",
        meta_description: "Takeaway boxes and takeaway food boxes for restaurants and takeaways. Kraft burger boxes cardboard food boxes chip boxes and carry out boxes. Free UK delivery over £100.",
        description: "Takeaway boxes and takeaway food boxes for fish and chip shops burger bars and takeaway restaurants. Our range of cardboard food boxes includes burger boxes chip boxes carry out boxes leakproof food pots and folded board trays in a variety of sizes. Made from recyclable kraft board these takeaway food containers keep food warm and secure during delivery. The natural kraft finish is popular with eco-conscious customers and works well with custom stamps or stickers for branding. Bulk pricing with free UK delivery on orders over £100."
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
