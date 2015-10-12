class Range
  start: null
  end: null

  constructor: (start, end) ->
    @start = start
    @end = end

# Not in prototype, because fromObj is a static method
Range.fromObj = (obj) ->
  if obj instanceof this
    return obj
  else if Array.isArray(obj)
    return new (atom.Range)(obj[0], obj[1])
  else
    console.error 'rangeFromObj parameter is Range nor Array: '
    console.dir obj

class Point
  row: null
  column: null

  constructor: (row, column) ->
    @row = row
    @column = column

# Not in prototype, because fromObj is a static method
Point.fromObj = (obj) ->
  if obj instanceof atom.Point
    return obj
  else if Array.isArray(obj)
    return new (atom.Point)(obj[0], obj[1])
  else
    console.error 'fromObj parameter is Point nor Array: '
    console.dir obj

class Buffer
  $textArea = null
  constructor: ($textArea) ->
    @$textArea = $textArea

  setText: (txt) ->
    @$textArea.val(txt)

  getText: ->
    @$textArea.val();

  getSelectionRange: ->
      new Range( @positionForCharacterIndex(@$textArea.get(0).selectionStart)
               , @positionForCharacterIndex(@$textArea.get(0).selectionEnd)
               )

  setSelectionRange: (range) ->
    range = Range.fromObj(range)
    @$textArea.get(0).selectionStart = @characterIndexForPosition range.start
    @$textArea.get(0).selectionEnd   = @characterIndexForPosition range.end

  delete: (range) ->
    range = Range.fromObj range
    rangeStartIx = @characterIndexForPosition range.start
    rangeEndIx   = @characterIndexForPosition range.end
    rangeLength = rangeEndIx - rangeStartIx
    selStartIx = @$textArea.get(0).selectionStart
    selEndIx   = @$textArea.get(0).selectionEnd

    selStartIx = switch
                   when selStartIx <= rangeStartIx then selStartIx
                   when selStartIx < rangeEndIx    then rangeStartIx
                   else selStartIx - rangeLength
    selEndIx   = switch
                   when selEndIx <= rangeStartIx then selEndIx
                   when selEndIx < rangeEndIx    then rangeStartIx
                   else selEndIx - rangeLength
    @setTextInRange range, ''
    @$textArea.get(0).selectionStart = selStartIx
    @$textArea.get(0).selectionEnd   = selEndIx

  setTextInRange: (range, text) ->
    range = Range.fromObj range
    rangeStartIx = @characterIndexForPosition range.start
    rangeEndIx   = @characterIndexForPosition range.end
    bufferText = @$textArea.val()
    @setText (bufferText.slice 0, rangeStartIx) + text + (bufferText.slice rangeEndIx, bufferText.length)

  positionForCharacterIndex: (ix) ->
    bufferText = @$textArea.val()
    row = 0
    col = 0
    i = 0
    while i < ix
      if bufferText[i] == '\n'
        row++
        col = 0
      else
        col++
      i++
    new Point(row, col)

  # Note: does note handle column position past line end (returned ix is on following lines)
  characterIndexForPosition: (pos) ->
    pos = Point.fromObj(pos)
    bufferText = @$textArea.val()
    ix = 0
    row = pos.row
    col = pos.column
    r = 0
    while r < row
      nextNewline = bufferText.indexOf '\n', ix
      if nextNewline < 0
        return bufferText.length
      else
        ix = nextNewline + 1
      r++
    Math.min ix + col, bufferText.length


module.exports = atom =
  Range: Range
  Point: Point
  Buffer: Buffer

  notifications:
    hideTimer: null

    addNotification: (msg, bgColor, duration) ->
      $notification = $('#atom-Emulator .notification')
      $notification.text msg
      $notification.css 'background-color', bgColor
      $notification.hide()
      $notification.fadeIn 50
      if @hideTimer
        clearTimeout @hideTimer

      @hideTimer = setTimeout ( ->
        $notification.fadeOut 100
      ), duration

    addInfo: (msg) ->
      @addNotification msg, '9ed2ff', 3000
    addSuccess: (msg) ->
      @addNotification msg, '99dba6', 3000
    addWarning: (msg) ->
      @addNotification msg, 'e8d0a1', 3000
    addError: (msg) ->
      @addNotification msg, 'ecb1b1', 4000

  clipboard:
    clipboard:
      text: null
      meta: null

    readWithMetadata: ->
      @clipboard

    write: (text, metadata) ->
      @clipboard =
        text: text
        metadata: if metadata then metadata else null

  workspace:
    getActiveTextEditor: ->
      @editor

    editor:
      grammar:
        tokenizeLine: ->
          { tags: [], ruleStack: [] }
        registry: idsByScope: {}

      getGrammar: ->
        @grammar

      buffer: new Buffer


      getBuffer: ->
        @buffer
      setCursorBufferPosition: (pos) ->
        @setSelectedBufferRange [pos, pos]

      getSelectedBufferRange: ->
        @buffer.getSelectionRange()

      setSelectedBufferRange: (range) ->
        @buffer.setSelectionRange range

      getText: ->
        @buffer.getText()

      setText: (txt) ->
        @buffer.setText txt

  init: ($atomEmulator) ->
    $textArea = $atomEmulator.find 'textarea'
    atom.workspace.editor.buffer.$textArea = $textArea
    $textArea.attr 'spellcheck', false
    $textArea.keydown @keyHandler.bind this
    setTimeout ( ->
      atom.notifications.addSuccess 'Atom emulator initialized'
    ), 300
    # Small delay to see it appear after page has loaded

  keyHandler: (event) ->
    # console.log(event.charCode);
    # console.log(event.keyCode);
    # console.log(event.altKey);
    # console.log(event.metaKey);
    # console.log(event.ctrlKey);
    if event.ctrlKey and event.charCode == 115
      # CTRL-S, just for testing
      @listSelect()
      return false
    if event.altKey and !event.shiftKey and event.metaKey and !event.ctrlKey or event.ctrlKey and !event.metaKey
      switch event.keyCode
        when 83
          @listSelect()
        when 88
          @listCut()
        when 67
          @listCopy()
        when 86
          @listPaste()
        else
          return true
      return false # disable event propagation after execution of list-edit command

  listSelect: ->
    console.log 'list-select'
    ListEdit.selectCmd()

  listCut: ->
    console.log 'list-cut'
    ListEdit.cutCmd()

  listCopy: ->
    console.log 'list-copy'
    ListEdit.copyCmd()

  listPaste: ->
    console.log 'list-paste'
    ListEdit.pasteCmd()
