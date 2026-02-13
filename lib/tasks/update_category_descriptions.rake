namespace :copy do
  desc "Update category descriptions with rebellious brand voice (medium volume)"
  task update_category_descriptions: :environment do
    descriptions = {
      "cups-and-lids" => "Hot drinks need good cups. These are compostable, sturdy, and won't embarrass your coffee. Single wall, double wall, ripple wall, with matching lids.",
      "straws" => "Bio fibre straws that don't go soggy. Yes, that's the whole pitch. Paper and bamboo options too.",
      "pizza-boxes" => "Kraft pizza boxes in four sizes. Strong enough to survive a delivery driver, recyclable enough to survive your conscience.",
      "ice-cream-cups" => "Paper ice cream cups that don't go soggy or leak. From 4oz tasters to 10oz generous portions. Your gelato deserves better than a polystyrene tub.",
      "napkins" => "Eco-friendly napkins. They do the job and then they disappear. As napkins should. Cocktail to dinner sizes, paper to linen-feel.",
      "takeaway-containers" => "Boxes, containers, and trays that hold your food and your reputation together. Kraft, biodegradable, available with lids.",
      "takeaway-extras" => "Paper bags, wooden cutlery, drink carriers. The stuff that completes a takeaway order. All eco-friendly, all available in bulk."
    }

    puts "Updating category descriptions with brand voice copy..."
    puts "=" * 60

    updated = 0
    skipped = 0

    ActiveRecord::Base.transaction do
      descriptions.each do |slug, new_description|
        category = Category.find_by(slug: slug)

        if category.nil?
          puts "  Skipped (not found): #{slug}"
          skipped += 1
          next
        end

        old_description = category.description
        category.update!(description: new_description)
        updated += 1

        puts "\n  #{category.name} (#{slug}):"
        puts "    OLD: #{old_description&.truncate(80) || '(blank)'}"
        puts "    NEW: #{new_description.truncate(80)}"
      end
    end

    puts "\n" + "=" * 60
    puts "Done! Updated: #{updated}, Skipped: #{skipped}"
    puts "=" * 60
  end
end
