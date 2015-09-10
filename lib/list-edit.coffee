ListEditView = require './list-edit-view'
{CompositeDisposable} = require 'atom'

module.exports = ListEdit =
  listEditView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @listEditView = new ListEditView(state.listEditViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @listEditView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'list-edit:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @listEditView.destroy()

  serialize: ->
    listEditViewState: @listEditView.serialize()

  toggle: ->
    console.log 'ListEdit was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
