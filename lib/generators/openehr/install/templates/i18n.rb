#encoding: utf-8
I18n.default_locale = <%=  %>

LANGUAGES = [
  <% for lang in languages %>
    [<%= lang.code %>, <%= lang.description %>],
  <% end %>
]
