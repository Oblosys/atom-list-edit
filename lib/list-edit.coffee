{CompositeDisposable, Range} = require 'atom'

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
    editor = atom.workspace.getActiveTextEditor()
    # TODO: add null check? (should always exist because we use 'atom-text-editor' command)

    cursorPos = editor.getCursorBufferPosition()
    console.log 'cursor row ' + cursorPos.row + ' col ' + cursorPos.column
    bufferRange = @getListRange editor.getBuffer(), cursorPos
    console.log bufferRange

    if bufferRange?
      editor.setSelectedBufferRange(bufferRange)

  cut: ->
    console.log 'Executing command list-edit-cut'

  copy: ->
    console.log 'Executing command list-edit-copy'

  paste: ->
    console.log 'Executing command list-edit-paste'

  delete: ->
    console.log 'Executing command list-edit-delete'

  getListRange: (textBuffer, pos) ->
    bufferText = textBuffer.getText()
    ix =  textBuffer.characterIndexForPosition(pos)

    listStartIx = null
    listEndIx = null
    console.log 'index is ' + ix + ', char is ' + bufferText[ix]
    for i in [ix-1...0]
      if bufferText[i] == '['
        listStartIx = i+1
        break
    for i in [ix...bufferText.length-1]
      if bufferText[i] == ']'
        listEndIx = i
        break

    console.log 'list starts at ' + listStartIx
    if listStartIx? and listEndIx?
      listStartPos = textBuffer.positionForCharacterIndex listStartIx
      listEndPos   = textBuffer.positionForCharacterIndex listEndIx
      new Range(listStartPos, listEndPos)
