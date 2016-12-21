$ ->
  # Toggle button. Show/hide content inside parent container.
  # Button does not change visibility. If button has icon - it changes chevron style.
  #
  # %div.js-toggle-container
  #   %a.js-toggle-button
  #   %div.js-toggle-content
  #
  $("body").on "click", ".js-toggle-button", (e) ->
    $(@).find('i').
      toggleClass('fa fa-chevron-down').
      toggleClass('fa fa-chevron-up')
    $(@).closest(".js-toggle-container").find(".js-toggle-content").toggle()
    e.preventDefault()
