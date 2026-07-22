module RespondentsHelper
  THEME_CSS_VARIABLES = {
    theme_background_color: "--org-bg",
    theme_primary_text_color: "--org-primary-text",
    theme_secondary_text_color: "--org-secondary-text",
    theme_button_color: "--org-button"
  }.freeze

  # Inline style carrying the loop's organization theme as CSS custom properties,
  # so respondent.css (plain CSS, not run through sass) can fall back to its
  # defaults when a color is blank rather than needing Ruby at the stylesheet layer.
  def respondent_theme_style(loop_record)
    organization = loop_record&.organization
    return "" if organization.nil?

    declarations = THEME_CSS_VARIABLES.filter_map do |attribute, css_variable|
      value = organization.public_send(attribute)
      "#{css_variable}: #{value}" if value.present?
    end

    declarations << "--org-heading-font: #{font_stack(organization.theme_heading_font)}"
    declarations << "--org-body-font: #{font_stack(organization.theme_body_font)}"
    declarations.join("; ")
  end

  # Google Fonts CSS2 lets multiple families share one request, so the respondent
  # layout only ever makes a single font request regardless of which fonts are chosen.
  def respondent_google_font_families(loop_record)
    organization = loop_record&.organization
    keys = [organization&.theme_heading_font, organization&.theme_body_font].compact.presence || ["atkinson"]

    keys.filter_map { |key| Organization::FONT_CHOICES.dig(key, :google_family) }.uniq
  end

  # Organization logo when one's uploaded; nil otherwise so the layout can fall
  # back to Loop AI's own favicon instead of a broken/missing icon link.
  def respondent_favicon_url(loop_record)
    organization = loop_record&.organization
    return nil unless organization&.logo&.attached?

    url_for(organization.logo.variant(resize_to_limit: [64, 64]))
  end

  private

  def font_stack(key)
    Organization::FONT_CHOICES.dig(key, :stack) || Organization::FONT_CHOICES.dig("atkinson", :stack)
  end
end
