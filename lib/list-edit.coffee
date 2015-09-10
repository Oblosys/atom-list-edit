{CompositeDisposable} = require 'atom'

module.exports =
  subscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register package commands
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'list-edit:select': => @select()
      'list-edit:cut':    => @cut()
      'list-edit:copy':   => @copy()
      'list-edit:paste':  => @paste()
      'list-edit:delete': => @delete()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    listEditViewState: @listEditView.serialize()

  select: ->
    console.log 'Executing command list-edit-select'

  cut: ->
    console.log 'Executing command list-edit-cut'

  copy: ->
    console.log 'Executing command list-edit-copy'

  paste: ->
    console.log 'Executing command list-edit-paste'

  delete: ->
    console.log 'Executing command list-edit-delete'
