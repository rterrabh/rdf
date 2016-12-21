jQuery ($) ->
  # Payment model
  order_id = $('#payments').data('order-id')
  class Payment
    constructor: (id) ->
      @url  = Spree.url("#{Spree.routes.payments_api(order_id)}/#{id}.json" + '?token=' + Spree.api_key)
      @json = $.getJSON @url.toString(), (data) =>
        @data = data

    if_editable: (callback) ->
      @json.done (data) ->
        callback() if data.state in ['checkout', 'pending']

    update: (attributes, success) ->
      jqXHR = $.ajax
        type: 'PUT'
        url:  @url.toString()
        data: { payment: attributes }
      jqXHR.done (data) =>
        @data = data
      jqXHR.fail ->
        response = $.parseJSON(jqXHR.responseText)
        show_flash('error', response.error)

    amount:         -> @data.amount
    display_amount: -> @data.display_amount

  # Payment base view
  class PaymentView
    constructor: (@$el, @payment) ->
      @render()

    render: ->
      @add_action_button()

    show: ->
      @remove_buttons()
      new ShowPaymentView(@$el, @payment)

    edit: ->
      @remove_buttons()
      new EditPaymentView(@$el, @payment)

    add_action_button: ->
      @$actions().prepend @$new_button(@action)

    remove_buttons: ->
      @$buttons().remove()

    $new_button: (action) ->
      $("<a><span class='icon icon-#{action}'></span></a>")
        .attr
          class: "payment-action-#{action} btn btn-default btn-sm icon-link no-text with-tip"
          title: Spree.translations[action]
        .data
          action: action
        .one
          click: (event) ->
            event.preventDefault()
          mousedown: ->
            $(@).data('clicked', true)
          mouseup: =>
            @[action]()

    $buttons: ->
      @$actions().find(".payment-action-#{@action}, .payment-action-cancel")

    $actions: ->
      @$el.find('.actions')

    $amount: ->
      @$el.find('td.amount')

  # Payment show view
  class ShowPaymentView extends PaymentView
    action: 'edit'

    render: ->
      super
      @set_actions_display()
      @show_actions()
      @show_amount()

    set_actions_display: ->
      width = @$actions().width()
      @$actions().width(width).css('text-align', 'left')

    show_actions: ->
      @$actions().find('a').show()

    show_amount: ->
      amount = $('<span />')
        .html(@payment.display_amount())
        .one('click', => @edit().$input().focus())
      @$amount().html(amount)

  # Payment edit view
  class EditPaymentView extends PaymentView
    action: 'save'

    render: ->
      super
      @hide_actions()
      @edit_amount()
      @add_cancel_button()

    add_cancel_button: ->
      @$actions().append @$new_button('cancel')

    hide_actions: ->
      @$actions().find('a').not(@$buttons()).hide()

    edit_amount: ->
      amount = @$amount()
      amount.html(@$new_input(amount.find('span').width()))

    save: (event) ->
      @payment.update(amount: @$input().val())
        .done(=> @show())

    cancel: @::show

    $new_input: (width) ->
      amount = @constructor.normalize_amount(@payment.display_amount())
      $('<input />')
        .prop(id: 'amount', value: amount)
        .width(width)
        .one
          blur: =>
            clicked = (@$buttons().filter -> $(@).data('clicked')).length
            @save() unless clicked
        .css('text-align': 'right')

    $input: ->
      @$amount().find('input')

    @normalize_amount: (amount) ->
      separator = Spree.translations.currency_separator
      amount.replace(///[^\d#{separator}]///g, '')

  # Attach ShowPaymentView to each editable payment in the table
  $('.admin tr[data-hook=payments_row]').each ->
    $el = $(@)
    payment = new Payment($el.prop('id').match(/\d+$/))
    payment.if_editable -> new ShowPaymentView($el, payment)
