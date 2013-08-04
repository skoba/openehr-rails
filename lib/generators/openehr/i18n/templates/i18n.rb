I18n.default_locale = :<%= original_language[:code] %>

LANGUAGES = [
  ['<%= original_language[:text] %>', '<%= original_language[:code] %>'],
<% translations.each do |t|%>  ['<%= t[:text] %>', '<%= t[:code] %>'],
<% end %>]
