class PseoPageValidatorService
  REQUIRED_SECTIONS = %i[meta hero packaging_needs sustainability_section faqs social_proof].freeze
  REQUIRED_META_FIELDS = %i[slug business_type seo_title seo_description keywords].freeze
  REQUIRED_HERO_FIELDS = %i[headline subheadline intro].freeze
  PACKAGING_NEEDS_RANGE = (4..6).freeze
  REQUIRED_FAQ_COUNT = 5
  INTRO_WORD_RANGE = (150..200).freeze
  FAQ_ANSWER_WORD_RANGE = (60..100).freeze

  def initialize(data)
    @data = data
    @errors = []
  end

  def validate
    validate_required_sections
    validate_meta if @data[:meta]
    validate_hero if @data[:hero]
    validate_packaging_needs if @data[:packaging_needs]
    validate_faqs if @data[:faqs]
    validate_sustainability_section if @data[:sustainability_section]
    validate_social_proof if @data[:social_proof]

    { valid: @errors.empty?, errors: @errors }
  end

  private

  def validate_required_sections
    REQUIRED_SECTIONS.each do |section|
      @errors << "Missing required section: #{section}" unless @data[section].present?
    end
  end

  def validate_meta
    meta = @data[:meta]
    REQUIRED_META_FIELDS.each do |field|
      @errors << "Missing or empty meta field: #{field}" if meta[field].blank?
    end
  end

  def validate_hero
    hero = @data[:hero]
    REQUIRED_HERO_FIELDS.each do |field|
      @errors << "Missing or empty hero field: #{field}" if hero[field].blank?
    end

    if hero[:intro].present?
      word_count = hero[:intro].split.size
      unless INTRO_WORD_RANGE.include?(word_count)
        @errors << "Hero intro word count is #{word_count}, must be #{INTRO_WORD_RANGE}"
      end
    end
  end

  def validate_packaging_needs
    count = @data[:packaging_needs].size
    unless PACKAGING_NEEDS_RANGE.include?(count)
      @errors << "packaging_needs count is #{count}, must be #{PACKAGING_NEEDS_RANGE}"
    end

    @data[:packaging_needs].each_with_index do |need, i|
      %i[category why_it_matters recommended_products buying_tip].each do |field|
        @errors << "packaging_needs[#{i}] missing #{field}" if need[field].blank?
      end
    end
  end

  def validate_faqs
    count = @data[:faqs].size
    if count != REQUIRED_FAQ_COUNT
      @errors << "faqs count is #{count}, must be exactly #{REQUIRED_FAQ_COUNT}"
    end

    @data[:faqs].each_with_index do |faq, i|
      @errors << "faqs[#{i}] missing question" if faq[:question].blank?
      @errors << "faqs[#{i}] missing answer" if faq[:answer].blank?

      if faq[:answer].present?
        word_count = faq[:answer].split.size
        unless FAQ_ANSWER_WORD_RANGE.include?(word_count)
          @errors << "faqs[#{i}] answer word count is #{word_count}, must be #{FAQ_ANSWER_WORD_RANGE}"
        end
      end
    end
  end

  def validate_sustainability_section
    sus = @data[:sustainability_section]
    @errors << "sustainability_section missing intro" if sus[:intro].blank?
    @errors << "sustainability_section missing options" if sus[:options].blank?
  end

  def validate_social_proof
    sp = @data[:social_proof]
    @errors << "social_proof missing relevant_clients" if sp[:relevant_clients].blank?
    @errors << "social_proof missing testimonial_angle" if sp[:testimonial_angle].blank?
  end
end
