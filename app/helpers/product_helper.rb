module ProductHelper
  # Display product/variant photo with placeholder if missing
  # Usage: product_photo_tag(product.primary_photo, alt: "Product name", class: "w-20 h-20", fetchpriority: "high", width: 800, height: 800, data: { product_options_target: "imageDisplay" })
  def product_photo_tag(photo, options = {})
    css_class = options[:class] || "w-full h-full object-contain"
    alt_text = options[:alt] || "Product photo"
    variant_options = options[:variant] || { resize_and_pad: [ 400, 400, { background: [ 255, 255, 255 ] } ] }
    data_attributes = options[:data] || {}

    # Extract image tag specific options
    image_options = { class: css_class, alt: alt_text, data: data_attributes }
    image_options[:fetchpriority] = options[:fetchpriority] if options[:fetchpriority]
    image_options[:width] = options[:width] if options[:width]
    image_options[:height] = options[:height] if options[:height]
    image_options[:loading] = options[:loading] if options[:loading]

    if photo&.attached?
      image_tag photo.variant(variant_options), **image_options
    else
      # Show placeholder SVG
      content_tag :div, { class: "#{css_class} bg-base-200 flex items-center justify-center", data: data_attributes } do
        content_tag :svg, xmlns: "http://www.w3.org/2000/svg", class: "h-1/2 w-1/2 text-base-content/20", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor" do
          tag.path stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
        end
      end
    end
  end
end
