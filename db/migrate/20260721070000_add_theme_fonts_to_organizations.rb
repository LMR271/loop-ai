class AddThemeFontsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :theme_heading_font, :string, default: "atkinson", null: false
    add_column :organizations, :theme_body_font, :string, default: "atkinson", null: false
  end
end
