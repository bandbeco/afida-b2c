# frozen_string_literal: true

module ProductsHelper
  # Get the display label for an option value
  # Falls back to the value itself if no label is set
  def option_value_label(option_name, value)
    return value if value.blank?

    option = ProductOption.find_by(name: option_name)
    return value unless option

    option_value = option.values.find_by(value: value)
    return value unless option_value

    option_value.label.presence || value
  end
end
