{Range, TextBuffer} = require 'atom'
_ = require 'underscore-plus'

class ListElement
  start: 0
  eltStart: 0
  eltEnd: 0
  end: 0
  leadingWhitespace: ''
  strippedElement: ''
  trailingWhitespace: ''

  constructor: (bufferText, range) ->
    [@start, @end] = range
    element = bufferText.slice @start, @end
    @leadingWhitespace  = (/^\s*/.exec(element) ? [''])[0]
    @trailingWhitespace = (/\s*$/.exec(element) ? [''])[0]
    @eltStart = @start + @leadingWhitespace.length
    @eltEnd = @end - @trailingWhitespace.length
    @strippedElement = bufferText.slice @eltStart, @eltEnd

  # TODO: Override toString? Could be confusing.
  show: ->
    'ListElement: <' + @start + ' - ' + @end + '> ' +
      'stripped: <' + @eltStart + ' - ' + @eltEnd + '> : ' +
      '"' + (if @strippedElement.length <= 8 then @strippedElement else
                (@strippedElement.slice 0, 3) + '..' + (@strippedElement.slice -3)) + '"'

module.exports =
  ListElement: ListElement

  # Computing the layout for all elements is a bit overkill, but can be optimized later, if necessary.
  getListElements: (bufferText, ix) ->
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

      # @showIxRanges bufferText, nonNestedIxRanges

      elementRanges = @getElementRanges bufferText, listStartIx, listEndIx, nonNestedIxRanges

      # @showIxRanges bufferText, elementRanges

      _.map elementRanges, (r) ->
        new ListElement(bufferText, r)
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
      # console.log 'range: ' + rangeStart + ' ' + rangeEnd
      ix = rangeStart

      while ix < rangeEnd
        if not separator? && @isSeparator bufferText[ix]
          separator = bufferText[ix]

        if (separator? && bufferText[ix] == separator)
          elementRanges.push [elementStart, ix] if elementStart != ix # TODO: empty check prob. not necessary
          elementStart = ix+1
        ix++

    elementRanges.push [elementStart, endIx] if elementStart != endIx
    # console.log elementRanges
    elementRanges

  # PRECONDITION: rangeStart <= rangeEnd
  # NOTE: selection does not include end, so selection [1,2] of [a,b,c,d] = [b]
  # TODO: Allow empty selection when in whitespace
  #        Maybe need booleans for distinguishing "one><, two"  "one, ><two" "one>, <two"
  #       these are empty for paste, but we may interpret them as ">one<, two" "one, >two" and ">one, two<" for select, cut, and copy.
  #       Not only for empty selections: ">one,< two" may be more intuitive as ">one, two<"
  #       maybe startIsBeforeSep and endIsBeforeSep? and add an expandListSelection function?
  #       Not immediately necessary, it may even be possible that letting these selections include the extra element is confusing.
  getSelectionForRange: (listElements, [rangeStart,rangeEnd]) ->
    index = 0
    while index < listElements.length
      elt = listElements[index]
      # console.log 'getSelectionForRange, start: ' + index + ' ' + elt.eltStart + ' ' + elt.eltEnd
      break if rangeStart <= elt.eltEnd
      index++
    selectionStart = index
    while index < listElements.length
      elt = listElements[index]
      # console.log 'getSelectionForRange, end:  ' + index + ' ' + elt.eltStart + ' ' + elt.eltEnd
      break if rangeEnd <= elt.eltEnd
      index++
    return [selectionStart, index+1]

  # Return the index of the list element that cursorIx is part of
  # NOTE: Range is inclusive also at the end, to let a cursor at the end of an element select that element.
  getElementIndexInList: (listElements, cursorIx) ->
    index = 0
    for elt in listElements
      # console.log 'getElementIndexInList: ' + index + ' ' + elt.eltStart + ' ' + elt.eltEnd
      return index if elt.eltStart <= cursorIx && cursorIx <= elt.eltEnd
      index++
    return null

  showIxRanges: (bufferText, ranges) ->
    console.log 'showIxRanges:'
    for ixRange in ranges
      console.log 'ixRange: '+ ixRange[0] + ' <-> ' + ixRange[1] + ': >>' + bufferText.substr(ixRange[0], ixRange[1] - ixRange[0]) + '<<'

  # Convert index-based range array [start, end] to row/column-based Range
  getRangeForIxRange: (textBuffer, ixRange) ->
    new Range( (textBuffer.positionForCharacterIndex ixRange[0])
             , (textBuffer.positionForCharacterIndex ixRange[1]) )

  # Convert row/column-based Range to index-based range array [start, end]
  getIxRangeForRange: (textBuffer, range) ->
    [ (textBuffer.characterIndexForPosition range.start)
    , (textBuffer.characterIndexForPosition range.end) ]


  # hacky first versions of bracket-character functions:

  # assumes c is character
  isSeparator: (c) ->
    ',;:'.indexOf(c) != -1

  # Strings (using whitespace as separator) are tricky, as they can be mistakenly assumed to be open/close bracket
  # e.g. '["Blinky", Inky, "Pinky"]' with cursor on Inky may recognize '", Inky ,"' as list.
  # Disabled, as we also cannot use the same element/whitespace selection for strings with whitespace as separator.

  # < .. > lists also tricky, as unbalanced < and > are quite common in code.
  # Disabled for now, <> lists are not that prevalent anyway.

  # assumes c is character
  isOpeningBracket: (c) ->
    '{[('.indexOf(c) != -1

  # assumes c is character
  isClosingBracket: (c) ->
    '}])'.indexOf(c) != -1

  getClosingBracketFor: (openingBracket) ->
    switch openingBracket
      when '{' then '}'
      when '[' then ']'
      when '(' then ')'
      else console.error 'Unknown opening bracket \'' + openingBracket + '\''

  getOpeningBracketFor: (closingBracket) ->
    switch closingBracket
      when '}' then '{'
      when ']' then '['
      when ')' then '('
      else console.error 'Unknown closing bracket \'' + closingBracket + '\''

  stripLeadingWhitespace: (source) ->
    source.replace(/^\s+/, '')

  stripTrailingWhitespace: (source) ->
    source.replace(/\s+$/, '')
