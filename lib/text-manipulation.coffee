{Range} = require 'atom'
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
    @leadingWhitespace  = TextManipulation.getLeadingWhitespace(element)
    @trailingWhitespace = if @leadingWhitespace.length is element.length
                            '' # element is all whitespace, which we take to be the leading whitespace
                          else
                            TextManipulation.getTrailingWhitespace(element)
    @eltStart = @start + @leadingWhitespace.length
    @eltEnd = @end - @trailingWhitespace.length
    @strippedElement = bufferText.slice @eltStart, @eltEnd

  # TODO: Override toString? Could be confusing.
  show: ->
    'ListElement: <' + @start + ' - ' + @end + '> ' +
      'stripped: <' + @eltStart + ' - ' + @eltEnd + '> : ' +
      '"' + (if @strippedElement.length <= 8 then @strippedElement else
                (@strippedElement.slice 0, 3) + '..' + (@strippedElement.slice -3)) + '"'

module.exports = TextManipulation =
  ListElement: ListElement

  # Computing the layout for all elements is a bit overkill, but can be optimized later, if necessary.
  getElementList: (bufferText, ignoreRanges, ixRange) ->
    containingList = @getListContainingRange bufferText, ignoreRanges, ixRange
    if not containingList?
      null
    else
      {listRange: [listStartIx,listEndIx], nonNestedRanges: nonNestedIxRanges} = containingList
      listRangeTxt = bufferText.slice listStartIx, listEndIx
      initialWhitespace = @getLeadingWhitespace listRangeTxt
      finalWhitespace = if initialWhitespace.length is listRangeTxt.length
                          '' # listRangeTxt is all whitespace, which we take to be the leading whitespace
                        else
                          @getTrailingWhitespace(listRangeTxt)
      listEltsStartIx = listStartIx + initialWhitespace.length
      listEltsEndIx   = listEndIx   - finalWhitespace.length
      elementRanges = @getElementRangesFromNonNested bufferText, listEltsStartIx, listEltsEndIx, nonNestedIxRanges
      # @showIxRanges bufferText, elementRanges
      listElements =
          _.map elementRanges, (r) ->
            new ListElement(bufferText, r)

      separator =
        if listElements.length <= 1
          null
        else
          sepLeadingWhitespace = listElements[0].trailingWhitespace
          sepChar = bufferText[listElements[1].start-1]
          sepTrailingWhitespace = listElements[1].leadingWhitespace
          {leadingWhitespace: sepLeadingWhitespace, sepChar: sepChar, trailingWhitespace: sepTrailingWhitespace}

      # sep will be null for empty lists and singletons
      { startIx: listStartIx, endIx: listEndIx # start and end of the range inside the brackets
      , openBracket: bufferText[listStartIx-1]
      , initialWhitespace: initialWhitespace   # whitespace trailing opening bracket
      , finalWhitespace:   finalWhitespace     # whitespace leading closing bracket
      , separator: separator                   # {leadingWhitespace: string, sepChar: string, trailingWhitespace: string}
      , elts: listElements
      }

  # Get inner range and non-nested subranges for nearest enclosing list that contains
  # both range start and range end (which may be at different depth levels).
  getListContainingRange: (bufferText, ignoreRanges, range) ->
    leftIx = rightIx = range[0]
    loop
      # Repeatedly take enclosing lists, until the range is included or we arrive at the document bounds
      list = @getEnclosingList bufferText, ignoreRanges, leftIx, rightIx
      break unless list? and list.listRange[0] > 0 and list.listRange[1] < range[1] # no need to check for end of file, because of range[1] check
      leftIx = list.listRange[0] - 1
      rightIx = list.listRange[1] + 1
    list

  # Get inner range and non-nested subranges for nearest enclosing list that holds [start, end>
  # PRECONDITION: [start, end> is either empty or a well-formed list
  getEnclosingList: (bufferText, ignoreRanges, start, end) ->
    rangesToOpen = @findMatchingOpeningBracket bufferText, ignoreRanges, start, false
    rangesToClose = @findMatchingClosingBracket bufferText, ignoreRanges, end, false

    if rangesToOpen? and rangesToClose? and
       (@getClosingBracketFor bufferText[rangesToOpen.bracketIx]) == bufferText[rangesToClose.bracketIx]
      { listRange: [rangesToOpen.bracketIx+1, rangesToClose.bracketIx]
      , nonNestedRanges: rangesToOpen.ranges.concat rangesToClose.ranges
      }
    else
      null

  findMatchingOpeningBracket: (bufferText, ignoreRanges, startIx, isNested, closingBracket) ->
    # console.log "findMatchingclosingBracket: " + startIx + ' ' + (if closingBracket? then closingBracket else "any closing bracket")
    ranges = []
    ix = @backwardSkipIgnored ignoreRanges, startIx
    rangeEnd = ix
    while ix > 0
      currentChar = bufferText[ix-1] # NOTE: ix is after the current character, unlike findMatchingClosingBracket

      if @isOpeningBracket currentChar
        if closingBracket? && currentChar != @getOpeningBracketFor closingBracket
          return null
        else
          @unshiftRange ranges, ix, rangeEnd, isNested
          return {bracketIx: ix-1, ranges: ranges}

      if @isClosingBracket currentChar
        @unshiftRange ranges, ix, rangeEnd, isNested
        res = @findMatchingOpeningBracket bufferText, ignoreRanges, ix-1, true, currentChar
        break if not res?
        ix = res.bracketIx+1
        rangeEnd = res.bracketIx

      beforeSkipIx = ix-1
      ix = @backwardSkipIgnored ignoreRanges, beforeSkipIx
      if ix != beforeSkipIx
        @unshiftRange ranges, beforeSkipIx, rangeEnd, isNested
        rangeEnd = ix

    return null # list not well formed, or no list

  unshiftRange: (ranges, rangeStart, rangeEnd, isNested) ->
    ranges.unshift [rangeStart,rangeEnd] if not isNested && rangeStart != rangeEnd

  findMatchingClosingBracket: (bufferText, ignoreRanges, startIx, isNested, openingBracket) ->
    # console.log "findMatchingClosingBracket: " + startIx + (if openingBracket? then openingBracket else "any opening bracket")
    ranges = []
    ix = @forwardSkipIgnored ignoreRanges, startIx
    rangeStart = ix
    while ix < bufferText.length
      currentChar = bufferText[ix]

      if @isClosingBracket currentChar
        if openingBracket? && currentChar != @getClosingBracketFor openingBracket
          return null
        else
          @pushRange ranges, rangeStart, ix, isNested
          return {bracketIx: ix, ranges: ranges}

      if @isOpeningBracket currentChar
        @pushRange ranges, rangeStart, ix, isNested
        res = @findMatchingClosingBracket bufferText, ignoreRanges, ix+1, true, currentChar
        break if not res?
        ix = res.bracketIx
        rangeStart = res.bracketIx+1

      beforeSkipIx = ix+1
      ix = @forwardSkipIgnored ignoreRanges, beforeSkipIx
      if ix != beforeSkipIx
        @pushRange ranges, rangeStart, beforeSkipIx, isNested
        rangeStart = ix

    return null # list not well formed, or no list)

  pushRange: (ranges, rangeStart, rangeEnd, isNested) ->
    ranges.push [rangeStart,rangeEnd] if not isNested && rangeStart != rangeEnd

  # Use binary search to return the element of ignoreRanges that contains targetIx, or null
  findRangeForIndex: (ignoreRanges, targetIx) ->
    startIx = 0
    endIx = ignoreRanges.length - 1
    while endIx >= startIx
      ix =  startIx + Math.floor (endIx - startIx) / 2
      if targetIx < ignoreRanges[ix][0]
        endIx = ix - 1
      else if targetIx >= ignoreRanges[ix][1]
        startIx = ix + 1
      else
        return ignoreRanges[ix]
    null

  # PRECONDITION: ranges do not connect (i.e. there is at least one element in between)
  forwardSkipIgnored: (ignoreRanges, ix) ->
    (@findRangeForIndex ignoreRanges, ix)?[1] ? ix

  # PRECONDITION: ranges do not connect (i.e. there is at least one element in between)
  # NOTE: for backwardSkipIgnored, ix denotes a position after the character, so it skips
  #       if the preceding character is in a skip range: e.g. backwardSkipIgnored([[1,2]],2) == 1
  backwardSkipIgnored: (ignoreRanges, ix) ->
    (@findRangeForIndex ignoreRanges, ix-1)?[0] ? ix

  # Convert list of ranges that cover the entire list except its sublists, to ranges for its elements.
  # The first separator encountered is expected to be the separator for the entire list.
  # NOTE: nonNestedRanges may start before startIx and end after endIx, but only element ranges in the
  #       range [startIx, endIx> will be returned.
  getElementRangesFromNonNested: (bufferText, startIx, endIx, nonNestedRanges) ->
    # Because lists with empty elements are not uncommon, we return empty element ranges for empty or whitespace-only
    # ranges between separators. If the entire list is empty, however, we return no element ranges.
    if startIx == endIx
      return []

    elementRanges = []
    elementStart = startIx
    separator = null

    # By using nonNestedRanges, we can easily skip the sublists
    for [rangeStart, rangeEnd] in nonNestedRanges
      # console.log 'range: ' + rangeStart + ' ' + rangeEnd
      ix = rangeStart

      while ix < rangeEnd
        if not separator? && @isSeparator bufferText[ix]
          separator = bufferText[ix]

        if (separator? && bufferText[ix] == separator)
          elementRanges.push [elementStart, ix]
          elementStart = ix+1
        ix++

    elementRanges.push [elementStart, endIx]
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
    i = 0
    while i < listElements.length
      elt = listElements[i]
      # console.log 'getSelectionForRange, start: ' + i + ' ' + elt.eltStart + ' ' + elt.eltEnd
      break if rangeStart < elt.eltEnd
      i++
    selectionStart = i
    while i < listElements.length
      elt = listElements[i]
      # console.log 'getSelectionForRange, end:  ' + i + ' ' + elt.eltStart + ' ' + elt.eltEnd
      break if rangeEnd <= elt.eltStart
      i++
    return [selectionStart, i]

  showIxRanges: (bufferText, ranges) ->
    console.log 'showIxRanges:'
    for ixRange in ranges
      console.log 'ixRange: ['+ ixRange[0] + ',' + ixRange[1] + '>:  >>' + bufferText.substr(ixRange[0], ixRange[1] - ixRange[0]) + '<<'

  # Convert index-based range array [start, end] to row/column-based Range
  getRangeForIxRange: (textBuffer, ixRange) ->
    new Range (textBuffer.positionForCharacterIndex ixRange[0]),
              (textBuffer.positionForCharacterIndex ixRange[1])

  # Convert row/column-based Range to index-based range array [start, end]
  getIxRangeForRange: (textBuffer, range) ->
    [ (textBuffer.characterIndexForPosition range.start)
    , (textBuffer.characterIndexForPosition range.end) ]


  # hacky first versions of bracket-character functions:

  # assumes c is character
  isSeparator: (c) ->
    ',;'.indexOf(c) != -1 # ':' is sometimes a separator, but allowing it breaks list-edit for JSON objects
  # TODO: Use priorities for determining the separator, so we only take ':' when there is no ',' or ';'?

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

  # TODO: Allow these to be configured
  getDefaultSeparatorFor: (openingBracket) ->
    switch openingBracket
      when '{' then ';'
      when '[' then ','
      when '(' then ','
      else console.error 'Unknown opening bracket \'' + openingBracket + '\''

  getLeadingWhitespace: (text) ->
    (/^\s*/.exec(text) ? [''])[0]

  getTrailingWhitespace: (text) ->
    (/\s*$/.exec(text) ? [''])[0]

  stripLeadingWhitespace: (text) ->
    text.replace(/^\s+/, '')

  stripTrailingWhitespace: (text) ->
    text.replace(/\s+$/, '')
