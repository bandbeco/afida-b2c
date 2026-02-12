# Seed site settings with branding images from existing static assets
puts "Seeding site settings..."

site_setting = SiteSetting.instance

branding_images_data = [
  { file: "DSC_6621.webp", alt: "Shakedown branded coffee cup" },
  { file: "DSC_6736.webp", alt: "OOO Koffee branded cup" },
  { file: "DSC_6770.webp", alt: "La Gelatiera branded gelato cup" },
  { file: "DSC_6898.webp", alt: "Branded cup detail" },
  { file: "DSC_6872.webp", alt: "Collection of branded cups" },
  { file: "DSC_7193.webp", alt: "La Gelatiera branded cups display" },
  { file: "DSC_7239.webp", alt: "Branded gelato cups with gelato" },
  { file: "DSC_7110.webp", alt: "Branded cups arrangement" },
  { file: "DSC_7159.webp", alt: "Branded cups display" }
]

branding_images_data.each_with_index do |data, index|
  file_path = Rails.root.join("app", "frontend", "images", "branding", data[:file])
  next unless File.exist?(file_path)

  # Skip if an image with this alt text already exists
  next if site_setting.branding_images.exists?(alt_text: data[:alt])

  image = site_setting.branding_images.create!(
    alt_text: data[:alt],
    position: index + 1
  )
  image.image.attach(
    io: File.open(file_path),
    filename: data[:file],
    content_type: "image/webp"
  )
  puts "  Added branding image: #{data[:alt]}"
end

puts "  Site settings seeded with #{site_setting.branding_images.count} branding images"
