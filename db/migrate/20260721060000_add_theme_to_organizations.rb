class AddThemeToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :theme_background_color, :string, default: "#f7f8fb", null: false
    add_column :organizations, :theme_primary_text_color, :string, default: "#1f1f1f", null: false
    add_column :organizations, :theme_secondary_text_color, :string, default: "#55607a", null: false
    add_column :organizations, :theme_button_color, :string, default: "#2f3437", null: false
  end
end
