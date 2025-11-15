namespace :products do
  desc "Generate descriptions for products missing them"
  task generate_descriptions: :environment do
    products_without_descriptions = Product.where(description_short: nil)

    puts "Found #{products_without_descriptions.count} products without descriptions"
    puts "Generating descriptions based on product information...\n"

    updated_count = 0

    products_without_descriptions.each do |product|
      # Generate descriptions based on product name and category
      short_desc = generate_short_description(product)
      standard_desc = generate_standard_description(product, short_desc)
      detailed_desc = generate_detailed_description(product, standard_desc)

      product.update_columns(
        description_short: short_desc,
        description_standard: standard_desc,
        description_detailed: detailed_desc
      )

      updated_count += 1
      puts "✓ #{product.name}"
    end

    puts "\n" + "=" * 60
    puts "Completed: #{updated_count} products updated with generated descriptions"
    puts "Total coverage: #{Product.where.not(description_short: nil).count}/#{Product.count} products"
    puts "=" * 60
  end

  private

  def generate_short_description(product)
    # Generate brief description based on product name pattern
    case product.name
    when /Black Twisted Handle/
      "Durable black twisted handle bags for stylish takeaway service."
    when /Kraft Deli Food Box/
      "Eco-friendly kraft deli boxes for food packaging and takeaway."
    when /Kraft Pizza Box/
      "Recyclable kraft pizza boxes protecting pizzas during delivery."
    when /Wooden Cutlery Kit/
      "Complete compostable wooden cutlery kits for eco-friendly dining."
    when /Kraft Soup Container/
      "Leak-proof kraft soup containers with matching lids included."
    when /Black Paper Straw/
      "Biodegradable black paper straws for sustainable beverage service."
    when /Wooden Fork/
      "Compostable wooden forks made from sustainable natural materials."
    when /Rectangular Kraft Food Bowl/
      "Rectangular kraft bowls perfect for salads and food service."
    when /Recyclable Sip Lid for Hot Cup/
      "Durable recyclable sip lids for secure hot beverage protection."
    when /Red.*Striped Paper Straw/
      "Classic striped paper straws adding vintage charm to drinks."
    when /Round Kraft Food Bowl/
      "Round kraft bowls ideal for soups, salads, and hot meals."
    when /Wooden Knife/
      "Compostable wooden knives for eco-conscious food service operations."
    when /Wooden Spoon/
      "Biodegradable wooden spoons made from sustainably sourced timber."
    when /White Paper Straw/
      "Clean white paper straws for elegant beverage presentation."
    when /rPET Dome Lid/
      "Crystal-clear rPET dome lids showcasing cold drinks beautifully."
    when /rPet Lid for Rectangular/
      "Clear rPET lids fitting rectangular kraft food bowls perfectly."
    when /rPet Lid for Round/
      "Transparent rPET lids designed for round kraft bowl compatibility."
    when /Kraft Flat Handle/
      "Sturdy kraft bags with flat handles for comfortable carrying."
    when /Luxury Airlaid Pocket Napkin/
      "Premium airlaid pocket napkins with built-in cutlery storage."
    when /rPET Flat Lid/
      "Recyclable rPET flat lids providing secure cold drink coverage."
    when /Recyclable Pulp Fibre Cup Carrier/
      "Eco-friendly cup carrier trays made from recycled pulp fiber."
    when /rPET Recyclable Cup/
      "Clear recyclable rPET cups for sustainable cold beverage service."
    when /Single Wall Hot Cup/
      "Cost-effective single wall hot cups for quality beverage service."
    when /Single Wall Cold Cup/
      "Refreshing single wall cold cups for chilled beverage service."
    when /Clear Recyclable Cup/
      "Transparent recyclable cups perfect for showcasing cold beverages."
    when /Greaseproof Paper/
      "Food-safe greaseproof paper for wrapping and food presentation."
    when /Ice Cream Cup/
      "Professional ice cream cups for serving frozen desserts perfectly."
    when /Pizza Box/
      "Durable pizza boxes keeping pizzas hot and protected during delivery."
    when /Kraft Container/
      "Versatile kraft containers for safe food storage and transport."
    when /Kraft Bag/
      "Eco-friendly kraft bags for sustainable takeaway packaging solutions."
    when /branded/i, /Branded/
      "Customizable branded products featuring your logo and company colors."
    else
      "Quality #{product.name.downcase} for professional food service operations."
    end
  end

  def generate_standard_description(product, short_desc)
    variant_count = product.active_variants.count
    category_context = product.category ? "ideal for #{product.category.name.downcase}" : "perfect for food service"

    base = short_desc.gsub(/\.$/, "")
    "#{base}, #{category_context}. Available in #{variant_count > 1 ? "#{variant_count} sizes" : "standard size"} to meet your business needs."
  end

  def generate_detailed_description(product, standard_desc)
    variant_count = product.active_variants.count
    sizes = product.active_variants.limit(5).pluck(:name).join(", ")

    detail_parts = []
    detail_parts << standard_desc
    detail_parts << "Perfect for restaurants, cafes, takeaways, and catering businesses seeking reliable food service supplies."

    if variant_count > 1
      detail_parts << "Choose from multiple size options including #{sizes}#{variant_count > 5 ? ' and more' : ''}."
    end

    # Add eco-friendly messaging based on product type
    if product.name =~ /compost|bamboo|bagasse|eco|green|sustain/i
      detail_parts << "Made from sustainable materials with environmental responsibility in mind."
    elsif product.name =~ /recyclable|rpet|recycl/i
      detail_parts << "Fully recyclable to support your commitment to environmental sustainability."
    elsif product.name =~ /kraft|paper/i
      detail_parts << "Crafted from quality materials for dependable performance in busy service environments."
    end

    detail_parts.join(" ")
  end
end
