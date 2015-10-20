jQuery = require 'jquery'

class Range
  start: null
  end: null

  constructor: (start, end) ->
    @start = Point.fromObj start
    @end   = Point.fromObj end

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

class TextManager
  $editableDiv: null

  constructor: ($editableDiv) ->
    @$editableDiv = $editableDiv

  getNodeLines: ->
    root = @$editableDiv[0]
    @traverse root.childNodes

  # span inserted by Chrome
  # <br> at end of line is used for selection, by Chrome, but selection at and of preceding text elt also works

  # TODO: check if this is really the case, and this thing works
  # because newlines are always encoded with a br (todo, maybe newline when we implement is) we don't have to
  # recreate complex line break patterns of nested divs and spans
  traverse: (nodes) ->
    nodeLines = []
    currentLine = []
    for node,i in nodes
      # console.log node,i
      switch node.nodeType
        when Node.TEXT_NODE
          # console.log '### text'
          currentLine.push node
        when Node.ELEMENT_NODE
          switch node.tagName
            when 'DIV'
              # console.log 'div'
              if currentLine.length > 0
                nodeLines.push currentLine
                currentLine = []
              nodeLines = nodeLines.concat @traverse node.childNodes
              # console.log 'd' + @showNodeLines traverse node.childNodes
            when 'SPAN'
              spanNodeLines = @traverse node.childNodes
              if spanNodeLines.length > 0
                currentLine = currentLine.concat spanNodeLines[0]
              if spanNodeLines.length > 1
                console.log 'WEIRD: line break in span'
                # TODO: check these
                nodeLines.push currentLine
                nodeLines = nodeLines.concat _.init spanNodeLines
                currentLine = _.last spanNodeLines
            when 'BR'
              currentLine.push node
              nodeLines.push currentLine
              currentLine = []
            else
              console.error 'unhandled element: '+node.tagName
        else
          console.error 'unhandled node type: ' + node.nodeType
    if currentLine.length > 0
      nodeLines.push currentLine
      currentLine = []
    # console.log 's' + @showNodeLines nodeLines
    nodeLines

  showNodeLines: (nodeLines) ->
    ls = _.map nodeLines, (nodeLine) ->
      ns =_.map nodeLine, (node) ->
        if node.nodeType == Node.TEXT_NODE
          "'" + node.textContent + "'"
        else if node.nodeType == Node.ELEMENT_NODE
          '<' + node.tagName + '>'
        else '{unhandled node type: ' + node.nodeType + '}'
      ns.join ','
    ls.join '\n'

  # only for text nodes and BR (BR only comes from Chrome)
  getNodePos: (nodeLines, selNode, offset) ->
    # console.log selNode, offset
    # offset is either position in text, or nr of BR child in parent node (which gets offset 0)
    [baseNode, nodeOffset] =
      switch selNode.nodeType
        when Node.TEXT_NODE
          [selNode, offset]
        when Node.ELEMENT_NODE
          # console.log 'Element node, offset: '+offset
          # console.log node
          # console.log node.childNodes[offset]
          [selNode.childNodes[offset], 0]
        else
          console.error 'getNodePos: unhandled node type or tagName: ' + selNode.nodeType + ' & ' + selNode.tagName
    for line, lineNr in nodeLines
      ix = line.indexOf baseNode
      if ix >= 0
        precedingNodes = line.slice 0, ix
        precedingLength = 0
        for n in precedingNodes
          # TODO: check node type?
          precedingLength += n.textContent.length
        return [lineNr, precedingLength + nodeOffset]
    return null

  getSelectionPoss: ->
    sel = window.getSelection()
    nodeLines = @getNodeLines()
    # console.dir nodeLines
    anchorPos = @getNodePos nodeLines, sel.anchorNode, sel.anchorOffset
    focusPos  = @getNodePos nodeLines, sel.focusNode,  sel.focusOffset
    if anchorPos? and focusPos?
      # Return ordered selection
      if anchorPos[0] < focusPos[0] || anchorPos[0] == focusPos[0] && anchorPos[1] <= focusPos[1]
        [anchorPos, focusPos]
      else
        [focusPos, anchorPos]
    else
      # if any of the selection points is not in the editable div, return empty selection at [0,0]
      [[0,0], [0,0]]

  setDocSelection: (startNode, startOffset, endNode, endOffset) ->
    docRange = document.createRange()
    winSelection = window.getSelection()
    docRange.setStart startNode, startOffset
    docRange.setEnd endNode, endOffset
    winSelection.removeAllRanges()
    winSelection.addRange docRange

  # TODO: use point or array
  getNodeAndOffsetForPos: (rowNr, colNr) ->
    console.log "getNodeAndOffsetForPos: #{rowNr} #{colNr}"
    nodeLines = @getNodeLines()
    nodeLine = nodeLines[rowNr]
    relativeCol = colNr
    for node, i in nodeLine
      if node.nodeType == Node.TEXT_NODE
        textLen = node.textContent.length
        if relativeCol <= textLen
          return [node, relativeCol]
        else
          relativeCol -= textLen
      else if node.nodeType == Node.ELEMENT_NODE && node.tagName == 'BR'
        return [node, 0]
        break;
      else # We should only have text and a single <br>
         console.error 'getNodeAndOffsetForPos: unhandled node type or tagName: ' + node.nodeType + ' & ' + node.tagName
    ## TODO: handle beyond end of line, and don't return br, but simply last text elt
    return null

  getText: ->
    textLines =
      for nodeLine in @getNodeLines()
        _.map nodeLine, (n) -> if n.nodeType == Node.TEXT_NODE then n.textContent else ''
          .join('')
    textLines.join('\n')

  setText: (txt) ->
    @$editableDiv.empty()
    for line in txt.split '\n'
      lineDiv = $('<div>').text line
      @$editableDiv.append lineDiv

class Buffer
  textManager: null

  constructor: ($editableDiv) ->
    @textManager = new TextManager($editableDiv)

  getText: ->
    @textManager.getText()

  setText: (txt) ->
    @textManager.setText txt

  getSelectionRange: ->
    [anchorPos,focusPos] = @textManager.getSelectionPoss()
    new Range( [anchorPos[0], anchorPos[1]], [focusPos[0], focusPos[1]] )

  setSelectionRange: (range) ->
    range = Range.fromObj(range)
    [startNode, startOffset] = @textManager.getNodeAndOffsetForPos range.start.row, range.start.column
    [endNode,   endOffset]   = @textManager.getNodeAndOffsetForPos range.end.row, range.end.column
    @textManager.setDocSelection startNode, startOffset, endNode, endOffset

  delete: (range) ->
    @setTextInRange range, ''

  setTextInRange: (range, text) ->
    range = Range.fromObj range
    rangeStartIx = @characterIndexForPosition range.start
    rangeEndIx   = @characterIndexForPosition range.end
    rangeLength = rangeEndIx - rangeStartIx
    selectionRange = @getSelectionRange()

    selStartIx = @characterIndexForPosition selectionRange.start
    selEndIx   = @characterIndexForPosition selectionRange.end
    insertedLength = text.length

    selStartIx = switch
                   when selStartIx <= rangeStartIx then selStartIx
                   when selStartIx < rangeEndIx    then rangeStartIx
                   else                                 selStartIx - rangeLength + insertedLength
    selEndIx   = switch
                   when selEndIx <= rangeStartIx then selEndIx
                   when selEndIx < rangeEndIx    then rangeStartIx
                   else                               selEndIx - rangeLength + insertedLength
    @setSelectionRange(range)
    # TODO: move to TextManager
    if text != ''
      try # Firefox sometime throws exceptions on inserting '\n', even if we fist call delete, so we need to ignore this :-(
        document.execCommand 'insertText', false, text
      catch
    else
      document.execCommand 'delete'

    console.log 'new selection:' + JSON.stringify [@positionForCharacterIndex(selStartIx),@positionForCharacterIndex(selEndIx)]

    @setSelectionRange [@positionForCharacterIndex(selStartIx), @positionForCharacterIndex(selEndIx)]

    # TODO: check if okay when selecion was null

  positionForCharacterIndex: (ix) ->
    bufferText = @getText()
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
    bufferText = @getText()
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
      $notification = jQuery('#atom-emulator .notification')
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
      @addNotification msg, '#9ed2ff', 3000
    addSuccess: (msg) ->
      @addNotification msg, '#99dba6', 3000
    addWarning: (msg) ->
      @addNotification msg, '#e8d0a1', 3000
    addError: (msg) ->
      @addNotification msg, '#ecb1b1', 4000

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

  # Stub for Jasmine testing with actual list-edit-spec.coffee
  views:
    getView: ->
      null

  # Stub for Jasmine testing with actual list-edit-spec.coffee
  packages:
    # NOTE: Does not return a promise but immediately initializes the emulator, since we don't need any asynchronous calls.
    #       See atom.workspace.open.
    activatePackage: ->
      atom.init jQuery('#atom-emulator')
      null

  workspace:
    # Stub for Jasmine testing with actual list-edit-spec.coffee
    open: ->
      then: (promiseCallback) ->
        # NOTE: promiseCallback is not a promise, but simply a callback that is executed immediately.
        #       Use open.then only with atom.packages.activatePackage.
        #       Having full promises here complicates the dummy implementation of waitsForPromise(), since
        #       Atom uses Jasmine 1.3 which is not in npm, and asynchronous testing has changed drastically in Jasmine 2.x.
        promiseCallback()

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
    $editableDiv = $atomEmulator.find '.edit-buffer'
    atom.workspace.editor.buffer = new Buffer($editableDiv)
    $editableDiv.attr 'spellcheck', false
    $editableDiv.keydown @keyHandler.bind this
    $editableDiv.focus()
    # document.execCommand 'insertText', false, '[ 111\n, 222\n, 333\n]'
    setTimeout ( ->
      atom.notifications.addSuccess 'Atom emulator initialized'
    ), 300 # Small delay to see it appear after page has loaded

  keyHandler: (event) ->
    if event.altKey and !event.shiftKey and event.metaKey and !event.ctrlKey or event.ctrlKey and !event.metaKey
      switch event.keyCode
        when 83
          # console.log '[' + window.getSelection().anchorOffset + ',' + window.getSelection().focusOffset + ']'
          # # document.execCommand 'insertText', false, 'XX'
          # $editableDiv = jQuery('.text-buffer')
          # console.log 'editableDiv: ' + $editableDiv.text();
          # el = $editableDiv[0]
          # range = document.createRange()
          # sel = window.getSelection()
          # range.setStart(el.childNodes[0], 5);
          # range.setEnd(el.childNodes[0], 107);
          # sel.removeAllRanges();
          # sel.addRange(range);

          # console.log '[' + window.getSelection().anchorOffset + ',' + window.getSelection().focusOffset + ']'
          #document.execCommand 'insertText', false, '\n'
          #console.log JSON.stringify atom.workspace.editor.buffer.getSelectionRange()
          atom.commands.dispatch(null, 'list-edit:select')
        when 88
          atom.commands.dispatch(null, 'list-edit:cut')
        when 67
          atom.commands.dispatch(null, 'list-edit:copy')
        when 86
          atom.commands.dispatch(null, 'list-edit:paste')
        else
          return true
      return false # disable event propagation after execution of list-edit command

  commands:
    dispatch: (editorView, cmd) -> # editorView is ignored
      switch cmd
        when 'list-edit:select' then ListEdit.selectCmd()
        when 'list-edit:cut'    then ListEdit.cutCmd()
        when 'list-edit:copy'   then ListEdit.copyCmd()
        when 'list-edit:paste'  then ListEdit.pasteCmd()
        else                         console.error 'Unknown command: ' + cmd
