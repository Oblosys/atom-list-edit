{CompositeDisposable} = require 'atom'

module.exports = ListEdit =
  listEditView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'list-edit:select': => @select()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @listEditView.destroy()

  serialize: ->
    listEditViewState: @listEditView.serialize()

  select: ->
    console.log 'Executing command list-edit-select'
