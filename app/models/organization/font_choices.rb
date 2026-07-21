class Organization
  # A closed set rather than free text: every value here is either a system font
  # (no network request) or a Google Font already covered by respondent_google_font_families,
  # so a chosen font is guaranteed to actually render - nothing to upload, nothing to fall back from.
  # Weights are pinned to 400/700 across the board since not every family ships the same
  # set, and regular/bold is the only pairing every one of them supports.
  module FontChoices
    ALL = {
      "atkinson" => {
        label: "Atkinson Hyperlegible (default)",
        stack: '"Atkinson Hyperlegible Next", sans-serif',
        google_family: "Atkinson+Hyperlegible+Next:wght@400;700"
      },
      "inter" => { label: "Inter", stack: '"Inter", sans-serif', google_family: "Inter:wght@400;700" },
      "roboto" => { label: "Roboto", stack: '"Roboto", sans-serif', google_family: "Roboto:wght@400;700" },
      "open_sans" => {
        label: "Open Sans", stack: '"Open Sans", sans-serif', google_family: "Open+Sans:wght@400;700"
      },
      "lato" => { label: "Lato", stack: '"Lato", sans-serif', google_family: "Lato:wght@400;700" },
      "montserrat" => {
        label: "Montserrat", stack: '"Montserrat", sans-serif', google_family: "Montserrat:wght@400;700"
      },
      "poppins" => { label: "Poppins", stack: '"Poppins", sans-serif', google_family: "Poppins:wght@400;700" },
      "nunito" => { label: "Nunito", stack: '"Nunito", sans-serif', google_family: "Nunito:wght@400;700" },
      "work_sans" => {
        label: "Work Sans", stack: '"Work Sans", sans-serif', google_family: "Work+Sans:wght@400;700"
      },
      "raleway" => { label: "Raleway", stack: '"Raleway", sans-serif', google_family: "Raleway:wght@400;700" },
      "source_sans" => {
        label: "Source Sans 3", stack: '"Source Sans 3", sans-serif', google_family: "Source+Sans+3:wght@400;700"
      },
      "manrope" => { label: "Manrope", stack: '"Manrope", sans-serif', google_family: "Manrope:wght@400;700" },
      "dm_sans" => { label: "DM Sans", stack: '"DM Sans", sans-serif', google_family: "DM+Sans:wght@400;700" },
      "playfair" => {
        label: "Playfair Display (serif)",
        stack: '"Playfair Display", serif',
        google_family: "Playfair+Display:wght@400;700"
      },
      "merriweather" => {
        label: "Merriweather (serif)", stack: '"Merriweather", serif', google_family: "Merriweather:wght@400;700"
      },
      "lora" => { label: "Lora (serif)", stack: '"Lora", serif', google_family: "Lora:wght@400;700" },
      "pt_serif" => { label: "PT Serif (serif)", stack: '"PT Serif", serif', google_family: "PT+Serif:wght@400;700" },
      "libre_baskerville" => {
        label: "Libre Baskerville (serif)",
        stack: '"Libre Baskerville", serif',
        google_family: "Libre+Baskerville:wght@400;700"
      },
      "crimson_text" => {
        label: "Crimson Text (serif)", stack: '"Crimson Text", serif', google_family: "Crimson+Text:wght@400;700"
      },
      "bebas_neue" => {
        label: "Bebas Neue (display)", stack: '"Bebas Neue", sans-serif', google_family: "Bebas+Neue"
      },
      "oswald" => { label: "Oswald (display)", stack: '"Oswald", sans-serif', google_family: "Oswald:wght@400;700" },
      "pacifico" => { label: "Pacifico (handwriting)", stack: '"Pacifico", cursive', google_family: "Pacifico" },
      "caveat" => {
        label: "Caveat (handwriting)", stack: '"Caveat", cursive', google_family: "Caveat:wght@400;700"
      },
      "ibm_plex_mono" => {
        label: "IBM Plex Mono (monospace)",
        stack: '"IBM Plex Mono", monospace',
        google_family: "IBM+Plex+Mono:wght@400;700"
      },
      "jetbrains_mono" => {
        label: "JetBrains Mono (monospace)",
        stack: '"JetBrains Mono", monospace',
        google_family: "JetBrains+Mono:wght@400;700"
      },
      "space_mono" => {
        label: "Space Mono (monospace)", stack: '"Space Mono", monospace', google_family: "Space+Mono:wght@400;700"
      },
      "roboto_mono" => {
        label: "Roboto Mono (monospace)",
        stack: '"Roboto Mono", monospace',
        google_family: "Roboto+Mono:wght@400;700"
      },
      "georgia" => { label: "Georgia (serif)", stack: "Georgia, 'Times New Roman', serif", google_family: nil },
      "system" => {
        label: "System sans-serif",
        stack: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif",
        google_family: nil
      }
    }.freeze
  end
end
