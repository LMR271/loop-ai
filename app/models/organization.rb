class Organization < ApplicationRecord
  THEME_COLOR_ATTRIBUTES = %i[
    theme_background_color
    theme_primary_text_color
    theme_secondary_text_color
    theme_button_color
  ].freeze

  FONT_CHOICES = FontChoices::ALL

  has_one_attached :logo
  attr_accessor :remove_logo

  belongs_to :owner, class_name: "User"
  has_many :loops, dependent: :destroy
  has_many :team_memberships, class_name: "Team", dependent: :destroy

  validates(*THEME_COLOR_ATTRIBUTES,
            format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #rrggbb" })
  validates :theme_heading_font, :theme_body_font, inclusion: { in: FONT_CHOICES.keys }
end
