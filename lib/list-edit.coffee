{CompositeDisposable, Range, TextBuffer} = require 'atom'
_ = require 'underscore-plus'


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

    # Not cut, but some test code to easily visualize ranges
    editor = atom.workspace.getActiveTextEditor()
    # TODO: add null check? (should always exist because we use 'atom-text-editor' command)

    cursorPos = editor.getCursorBufferPosition()
    console.log 'cursor row ' + cursorPos.row + ' col ' + cursorPos.column
    textBuffer = editor.getBuffer()
    bufferText = textBuffer.getText()

    listIxRanges = @getListIxRanges bufferText, textBuffer.characterIndexForPosition(cursorPos)

    # Atom bug?
    # fn = textBuffer.positionForCharacterIndex
    # console.log (textBuffer.positionForCharacterIndex)
    # console.log (fn)
    # console.log (textBuffer.positionForCharacterIndex 2)
    # console.log (fn 2 ) #fails

    bufferRanges =_.map listIxRanges, (ixRange) ->
                    _.map ixRange, (ix) -> textBuffer.positionForCharacterIndex ix
                                           # TODO: eta-reduce yields error, why?

    console.log 'bufferRanges:'
    console.log bufferRanges

    if bufferRanges? && bufferRanges.length > 0
      editor.setSelectedBufferRanges(bufferRanges)

  copy: ->
    console.log 'Executing command list-edit-copy'

  paste: ->
    console.log 'Executing command list-edit-paste'

  delete: ->
    console.log 'Executing command list-edit-delete'

  getListIxRanges: (bufferText, ix) ->

    res1 = @findMatchingOpeningBracket bufferText, ix, false
    res2 = @findMatchingClosingBracket bufferText, ix, false

    if res1? && res2?
      [listStartIx, leftIxRanges]  = res1
      [listEndIx,   rightIxRanges] = res2
      nonNestedIxRanges = leftIxRanges.reverse().concat rightIxRanges

      # console.log 'leftIxRanges:'
      # @showIxRanges bufferText, leftIxRanges
      # console.log 'rightIxRanges:'
      # @showIxRanges bufferText, rightIxRanges

      console.log 'nonNestedIxRanges:'
      @showIxRanges bufferText, nonNestedIxRanges

      elementRanges = @getElementRanges bufferText, listStartIx, listEndIx, nonNestedIxRanges

      console.log 'elementRanges:'
      @showIxRanges bufferText, elementRanges

      elementRanges
    else
      return null

  findMatchingOpeningBracket: (bufferText, startIx, isNested, closingBracket) ->
    # console.log "findMatchingclosingBracket: " + startIx + ' ' + (if closingBracket? then closingBracket else "any closing bracket")
    ranges = []
    ix = startIx
    rangeEnd = ix
    while ix > 0
      currentChar = bufferText[ix-1]

      if (closingBracket? && (currentChar == @getOpeningBracketFor closingBracket)) ||
         @isOpeningBracket currentChar
        @addRange ranges, ix, rangeEnd, isNested
        return [ix, ranges]

      if @isClosingBracket currentChar
        @addRange ranges, ix, rangeEnd, isNested
        res = @findMatchingOpeningBracket bufferText, ix-1, true, currentChar
        break if not res?
        [ix, ...] = res
        rangeEnd = ix-1

      ix--

    return null # syntax error in list (or no list)

  findMatchingClosingBracket: (bufferText, startIx, isNested, openingBracket) ->
    # console.log "findMatchingClosingBracket: " + startIx + (if openingBracket? then openingBracket else "any opening bracket")
    ranges = []
    ix = startIx
    rangeStart = ix
    while ix < bufferText.length
      currentChar = bufferText[ix]

      if (openingBracket? && (currentChar == @getClosingBracketFor openingBracket)) ||
         @isClosingBracket currentChar
        @addRange ranges, rangeStart, ix, isNested
        return [ix, ranges]

      if @isOpeningBracket currentChar
        @addRange ranges, rangeStart, ix, isNested
        res = @findMatchingClosingBracket bufferText, ix+1, true, currentChar
        break if not res?
        [ix, ...] = res
        rangeStart = ix+1

      ix++

    return null # syntax error in list (or no list)

  addRange: (ranges, rangeStart, rangeEnd, isNested) ->
    ranges.push [rangeStart,rangeEnd] if not isNested && rangeStart != rangeEnd

  getElementRanges: (bufferText, startIx, endIx, nonNestedRanges) ->
    elementRanges = []
    elementStart = startIx
    separator = null

    for nonNestedRange in nonNestedRanges
      [rangeStart, rangeEnd] = nonNestedRange
      console.log 'range: ' + rangeStart + ' ' + rangeEnd
      ix = rangeStart

      while ix < rangeEnd
        if not separator? && @isSeparator bufferText[ix]
          separator = bufferText[ix]

        if (separator? && bufferText[ix] == separator)
          elementRanges.push [elementStart, ix] if elementStart != ix # TODO: empty check prob. not necessary
          elementStart = ix+1
        ix++

    elementRanges.push [elementStart, endIx] if elementStart != endIx
    console.log elementRanges
    elementRanges

  showIxRanges: (bufferText, ranges) ->
    for ixRange in ranges
      console.log 'ixRange: '+ ixRange[0] + ' <-> ' + ixRange[1] + ': >>' + bufferText.substr(ixRange[0], ixRange[1] - ixRange[0]) + '<<'


  # hacky first versions of bracket-character functions:

  # assumes c is character
  isSeparator: (c) ->
    ',;:'.indexOf(c) != -1

  # strings are tricky, as they can be mistakenly assumed to be open/close bracket
  # e.g. '["Blinky", Inky, "Pinky"]' with cursor on Inky may recognize '", Inky ,"' as list
  # assumes c is character
  isOpeningBracket: (c) ->
    '{[(<'.indexOf(c) != -1

  # assumes c is character
  isClosingBracket: (c) ->
    '}])>'.indexOf(c) != -1

  getClosingBracketFor: (openingBracket) ->
    switch openingBracket
      when '{' then '}'
      when '[' then ']'
      when '(' then ')'
      when '<' then '>'
      else console.error 'Unknown opening bracket \'' + openingBracket + '\''

  getOpeningBracketFor: (closingBracket) ->
    switch closingBracket
      when '}' then '{'
      when ']' then '['
      when ')' then '('
      when '>' then '<'
      else console.error 'Unknown closing bracket \'' + closingBracket + '\''

# for testing in console:
# > atom.packages.activatePackage('list-edit')
# > atom.packages.activePackages['list-edit'].mainModule.<function>

# Some test lists:
# [1,[1,2,[ ,, ]]]
# [dsd,[kdd], "ddd"]
# [ Blinky, Inky; [some, inner, nesting], Pinky,[ j] ,kjl, (1,2,3), jkj]
