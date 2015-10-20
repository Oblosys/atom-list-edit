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
    console.error 'Range.fromObj parameter is Range nor Array: '
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
    console.error 'Point.fromObj parameter is Point nor Array: '
    console.dir obj

class Buffer
  $editableDiv: null

  constructor: ($editableDiv) ->
    @$editableDiv = $editableDiv

  ###*
   * Traverse the content-editable node, and return a list of text nodes for each line.
   * Empty lines will consist of a single <BR> node, and non-empty lines are optionally
   * terminated by a <BR> node.
   *
   * @return {Node[][]} List of list of text nodes, possibly terminated by a <BR> node.
  ###
  getNodeLines: ->
    root = @$editableDiv[0]
    @traverse root.childNodes


  # Different browsers edit the node tree differently, sometimes inserting divs for line breaks (Chrome/Safari)
  # or unnecessary spans on paste (Chrome). Empty lines are always represented by a <BR> though, so we can
  # reconstruct the text lines without a full div/span layout engine.
  traverse: (nodes) ->
    nodeLines = []
    currentLine = []
    for node,i in nodes
      switch node.nodeType
        when Node.TEXT_NODE
          currentLine.push node
        when Node.ELEMENT_NODE
          switch node.tagName
            when 'DIV'
              if currentLine.length > 0
                nodeLines.push currentLine
                currentLine = []
              nodeLines = nodeLines.concat @traverse node.childNodes
            when 'SPAN' # Chrome sometimes insert spans on a paste
              spanNodeLines = @traverse node.childNodes
              if spanNodeLines.length > 0
                currentLine = currentLine.concat spanNodeLines[0]
              if spanNodeLines.length > 1 # span contained line breaks.
                nodeLines.push currentLine
                nodeLines = nodeLines.concat _.initial spanNodeLines
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

  ###*
   * Convert node-based position to row/column-based position. End of line can be represented
   * by a right-most offset on the last text node on the line, or the index of the <BR> node on
   * the line (Chrome)
   *
   * @param  {Node[][]} nodeLines  Node lines for the content-editable tree
   * @param  {Number}   baseNode   Base node for the selection
   * @param  {Number}   offset     Offset in node
   * @return {Point}    The row and column for the selected node in content-editable text
  ###
  getNodePos: (nodeLines, baseNode, offset) ->
    console.log 'NODELINES\n' + @showNodeLines nodeLines
    [baseNode, nodeOffset] =
      switch
        when baseNode.nodeType == Node.TEXT_NODE
          # offset is position in text node
          [baseNode, offset]
        when baseNode.nodeType == Node.ELEMENT_NODE
          # offset is index of <BR> child in parent node (which gets offset 0)
          [baseNode.childNodes[offset], 0]
        else
          console.error 'getNodePos: unhandled baseNode nodeType: ' + baseNode.nodeType
          null

    for line, lineNr in nodeLines
      ix = line.indexOf baseNode
      if ix >= 0
        precedingNodes = line.slice 0, ix
        precedingLength = 0
        for n in precedingNodes
          if n.nodeType == Node.TEXT_NODE
            precedingLength += n.textContent.length
          else
            console.error 'getNodePos: unhandled node type ' + node.nodeType
        return new Point(lineNr, precedingLength + nodeOffset)
    return null

  ###*
   * Convert row/column-based position to node based-position
   *
   * @param  {Node[][]} nodeLines Node lines for the content-editable tree
   * @param {Point}     pos       Position in the content-editable text
   * @return {{node: Node, offset: number}}  Node and offset corresponding to pos
  ###
  getNodeAndOffsetForPos: (nodeLines, pos) ->
    {row: rowNr, column: colNr} = Point.fromObj pos
    nodeLine = nodeLines[rowNr]
    textNodes = _.where nodeLine, {nodeType: Node.TEXT_NODE}
    if textNodes.length > 0
      relativeCol = colNr
      for node in nodeLine
        textLen = node.textContent.length
        if relativeCol <= textLen
          return {node: node, offset: relativeCol} # somewhere in a text node
        else
          relativeCol -= textLen
      lastTextNode = _.last textNodes
      return {node: lastTextNode, offset: lastTextNode.length} # beyond the last text node

    else
      brNode = nodeLine?[0]
      if brNode?
        return {node: brNode, offset: 0} # no text nodes, so return <BR> node with offset 0
      else
        console.error 'getNodeAndOffsetForPos: line not terminated by <BR>'
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

  getSelectionRange: ->
    sel = window.getSelection()
    nodeLines = @getNodeLines()
    # console.dir nodeLines
    anchorPos = @getNodePos nodeLines, sel.anchorNode, sel.anchorOffset
    focusPos  = @getNodePos nodeLines, sel.focusNode,  sel.focusOffset
    if anchorPos? and focusPos?
      # Always return lexicographicaly ordered selection (ie. start is before end)
      if anchorPos.row < focusPos.row ||
         anchorPos.row == focusPos.row && anchorPos.column <= focusPos.column
        new Range(anchorPos, focusPos)
      else
        new Range(focusPos, anchorPos)
    else
      # if any of the selection points is not in the editable div, return empty selection at [0,0]
      new Range([0,0], [0,0])

  setSelectionRange: (range) ->
    range = Range.fromObj(range)
    nodeLines = @getNodeLines()

    {node: startNode, offset: startOffset} = @getNodeAndOffsetForPos nodeLines, range.start
    {node: endNode,   offset: endOffset}   = @getNodeAndOffsetForPos nodeLines, range.end

    docRange = document.createRange()
    winSelection = window.getSelection()
    docRange.setStart startNode, startOffset
    docRange.setEnd endNode, endOffset
    winSelection.removeAllRanges()
    winSelection.addRange docRange

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
    if text != ''
      try
        # Firefox sometime throws exceptions on inserting '\n', even if we fist call delete,
        # so we need to ignore these :-(
        document.execCommand 'insertText', false, text
      catch
    else
      document.execCommand 'delete'

    console.log 'new selection:' + JSON.stringify [@positionForCharacterIndex(selStartIx),@positionForCharacterIndex(selEndIx)]

    @setSelectionRange [@positionForCharacterIndex(selStartIx), @positionForCharacterIndex(selEndIx)]

    # TODO: check if okay when selection was null

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
    addFatalError: (msg) ->
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
