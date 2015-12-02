###*
 * Classes and methods for analyzing and manipulating list elements.
 *
 * @module TextManipulation
###

{Range} = require 'atom'
_ = require 'underscore-plus'

class ListElement
  start: 0               # buffer text index of start of leading whitespace
  eltStart: 0            # buffer text index of start of actual element (and end of leading whitespace)
  eltEnd: 0              # buffer text index of end of actual element (and start of trailing whitespace)
  end: 0                 # buffer text index of end of trailing whitespace
  leadingWhitespace: ''
  strippedElement: ''    # element string without whitespace
  trailingWhitespace: ''

  ###*
   * @param  {string}   bufferText - Buffer text that contains the list element
   * @param  {number[]} range      - Index range in bufferText: [start, end]
   * @constructs ListElement
  ###
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

  ###*
   * @return {string}
  ###
  show: ->
    'ListElement: [' + @start + ' - ' + @end + '> ' +
      'stripped: [' + @eltStart + ' - ' + @eltEnd + '> : ' +
      '"' + (if @strippedElement.length <= 8 then @strippedElement else
                (@strippedElement.slice 0, 3) + '..' + (@strippedElement.slice -3)) + '"'

class ElementList
  startIx: 0                # start and end of the range inside the brackets
  endIx: 0                  #
  openBracket: null
  initialWhitespace: ''     # whitespace trailing opening bracket
  finalWhitespace:   ''     # whitespace leading closing bracket
  separator: null           # for lists with more than 1 element: separator & whitespace: {leadingWhitespace: string, sepChar: string, trailingWhitespace: string}
  elts: []

  ###*
   * @param  {string}     bufferText        - Buffer text that contains the element list.
   * @param  {number[]}   listRange         - Range ([startIx, endIx]) for the contents of the list, not including the brackets.
   * @param  {number[][]} nonNestedIxRanges - List of ranges for those parts of the list that are not nested sublists.
   * @constructs ElementList
  ###
  constructor:  (bufferText, listRange, nonNestedIxRanges) ->
    [listStartIx,listEndIx] = listRange
    @startIx = listStartIx
    @endIx  = listEndIx
    @openBracket = bufferText[listStartIx-1]
    listRangeTxt = bufferText.slice listStartIx, listEndIx
    @initialWhitespace = TextManipulation.getLeadingWhitespace listRangeTxt
    @finalWhitespace = if @initialWhitespace.length is listRangeTxt.length
                        '' # listRangeTxt is all whitespace, which we take to be the leading whitespace
                      else
                        TextManipulation.getTrailingWhitespace(listRangeTxt)
    listEltsStartIx = listStartIx + @initialWhitespace.length
    listEltsEndIx   = listEndIx   - @finalWhitespace.length
    elementRanges = TextManipulation.getElementRangesFromNonNested bufferText, listEltsStartIx, listEltsEndIx, nonNestedIxRanges
    # TextManipulation.logIxRanges bufferText, elementRanges

    # OPTIMIZE: Computing the layout for all elements is a bit overkill, but can be optimized later, if necessary.
    @elts =
        _.map elementRanges, (r) ->
          new ListElement(bufferText, r)

    @separator = # separator will be null for empty lists and singletons
      if @elts.length <= 1
        null
      else
        sepLeadingWhitespace = @elts[0].trailingWhitespace
        sepChar = bufferText[@elts[1].start-1]
        sepTrailingWhitespace = @elts[1].leadingWhitespace
        {leadingWhitespace: sepLeadingWhitespace, sepChar: sepChar, trailingWhitespace: sepTrailingWhitespace}

###*
 * Factory method for creating ElementList object.
 *
 * @memberof ElementList
 * @param  {string}     bufferText   - Buffer text that contains the element list
 * @param  {number[][]} ignoreRanges - List of ranges that should be ignored while recoginizing list elements.
 * @param  {number[]}   ixRange      - Range corresponding to current text selection.
 * @return {ElementList} An ElementList corresponding to the smallest list that contains ixRange, or null if ixRange is not inside a valid list.
###
ElementList.getElementList = (bufferText, ignoreRanges, ixRange) ->
    containingList = TextManipulation.getListContainingRange bufferText, ignoreRanges, ixRange
    if containingList?
      new ElementList(bufferText, containingList.listRange, containingList.nonNestedRanges)
    else
      null


TextManipulation = module.exports =
  ElementList: ElementList

  ###*
   * Get inner range and non-nested subranges for nearest enclosing list that contains
   * both range start and range end (which may be at different depth levels).
   * @param  {string}     bufferText   - Buffer text that contains the element list
   * @param  {number[][]} ignoreRanges - List of ranges that should be ignored while recoginizing list elements.
   * @param  {number[]}   range        - Range ([startIx, endIx]) corresponding to current text selection.
   * @return {{ listRange: number[], nonNestedRanges:number[][]}}
  ###
  getListContainingRange: (bufferText, ignoreRanges, range) ->
    leftIx = rightIx = range[0]
    # Starting at the range start, repeatedly take enclosing lists, until the range end is also included or we arrive at the document bounds
    loop
      list = @getEnclosingList bufferText, ignoreRanges, leftIx, rightIx
      break unless list? and list.listRange[0] > 0 and list.listRange[1] < range[1] # no need to check for end of file, because of range[1] check
      leftIx = list.listRange[0] - 1
      rightIx = list.listRange[1] + 1
    list

  ###*
   * Get inner range and non-nested subranges for nearest enclosing list that holds [start, end>.
   * PRECONDITION: [start, end> is either empty or a well-formed list.
   * @param  {string}     bufferText
   * @param  {number[][]} ignoreRanges
   * @param  {number}     start        - [description]
   * @param  {number}     end          - [description]
   * @return {{listRange: number[], nonNestedRanges:number[][]}}
  ###
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

  ###*
   * Find nearest following non-nested closing bracket and non-nested ranges.
   * @param  {string}     bufferText
   * @param  {number[][]} ignoreRanges
   * @param  {number}     startIx          - Index in bufferText to start search.
   * @param  {boolean}    isNested         - If true, this is a nested call, and no ranges are computed.
   * @param  {string}     [openingBracket] - Optional opening bracket, causing null to be returned if a closing bracket is found that does not match.
   * @return {{bracketIx: number, ranges: number[][]}} Index for first non-nested closing bracket, and list of ranges for those parts of the list that
   *                                                   are not nested sublists. (Or null if startIx is not in a  well-formed list)
  ###
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

    return null # list not well formed, or no list

  ###*
   * If not isNested and the range [rangeStart,rangeEnd] is not empty, add it at the end of ranges.
   * @param  {number[][]}  ranges
   * @param  {number}      rangeStart
   * @param  {number}      rangeEnd
   * @param  {boolean}     isNested
  ###
  pushRange: (ranges, rangeStart, rangeEnd, isNested) ->
    ranges.push [rangeStart,rangeEnd] if not isNested && rangeStart != rangeEnd

  ###*
   * Find nearest preceding non-nested closing bracket and non-nested ranges.
   * @param  {string}     bufferText
   * @param  {number[][]} ignoreRanges
   * @param  {number}     startIx          - Index in bufferText to start search.
   * @param  {boolean}    isNested         - If true, this is a nested call, and no ranges are computed.
   * @param  {string}     [closingBracket] - Optional closing bracket, causing null to be returned if an opening bracket is found that does not match.
   * @return {{bracketIx: number, ranges: number[][]}} Index for first non-nested openinging bracket, and list of ranges for those parts of the list that
   *                                           are not nested sublists. (Or null if startIx is not in a  well-formed list)
  ###
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

  ###*
   * If not isNested and the range [rangeStart,rangeEnd] is not empty, add it at the start of ranges.
   * @param  {number[][]} ranges
   * @param  {number}     rangeStart
   * @param  {number}     rangeEnd
   * @param  {boolean}    isNested
  ###
  unshiftRange: (ranges, rangeStart, rangeEnd, isNested) ->
    ranges.unshift [rangeStart,rangeEnd] if not isNested && rangeStart != rangeEnd

  ###*
   * Use binary search to return the element of ignoreRanges that contains targetIx, or null
   * @param  {number[][]} ignoreRanges
   * @param  {number}     targetIx
   * @return {number[]} Ignored range that contains targetIx (or null).
  ###
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

  ###*
   * If ix is inside an ignored range, return an index to the character following that ignored range, otherwise return ix.
   * PRECONDITION: ranges do not connect (i.e. there is at least one character in between)
   * @param  {number[][]} ignoreRanges
   * @param  {number}     ix
   * @return {number}
  ###
  forwardSkipIgnored: (ignoreRanges, ix) ->
    (@findRangeForIndex ignoreRanges, ix)?[1] ? ix

  # NOTE: for backwardSkipIgnored, ix denotes a position after the character, so it skips
  #       if the preceding character is in a skip range: e.g. backwardSkipIgnored([[1,2]],2) == 1
  ###*
   * If the character preceding ix is inside an ignored range, return an index to the start of the ignored range, otherwise return ix.
   * e.g. backwardSkipIgnored([[1,3]],3) == 1
   * PRECONDITION: ranges do not connect (i.e. there is at least one character in between)
   * @param  {number[][]} ignoreRanges
   * @param  {number}     ix
   * @return {number}
  ###
  backwardSkipIgnored: (ignoreRanges, ix) ->
    (@findRangeForIndex ignoreRanges, ix-1)?[0] ? ix


  ###*
   * Convert list of ranges that cover the entire list except its sublists, to ranges for its elements.
   * The first separator encountered is expected to be the separator for the entire list.
   * NOTE: nonNestedRanges may start before startIx and end after endIx, but only element ranges in the
   *       range [startIx, endIx> will be returned.
   * @param  {string}     bufferText
   * @param  {number}     startIx         - Start index of list contents (== index of opening bracket + 1)
   * @param  {number}     endIx           - End index of list contents (== index of closing bracket, as ranges don't include end)
   * @param  {number[][]} nonNestedRanges - List of ranges for those parts of the list that are not nested sublists.
   * @return {number[][]} List-element index ranges
  ###
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

  ###*
   * Convert a buffer-text character index range to a list-element index range.
   * PRECONDITION: rangeStart <= rangeEnd
   * NOTE: selection does not include end, so selection [1,2] of [a,b,c,d] = [b]
   * @param  {ListElement[]} listElements
   * @param  {number[]}      ixRange      - A character index range ([startIx, endIx]) in the buffer text.
   * @return {number[]} An index range ([startIx, endIx]) in the array of ListElements.
  ###
  getSelectionForRange: (listElements, ixRange) ->
    # TODO: Allow empty selection when in whitespace
    #        Maybe need booleans for distinguishing "one><, two"  "one, ><two" "one>, <two"
    #       these are empty for paste, but we may interpret them as ">one<, two" "one, >two" and ">one, two<" for select, cut, and copy.
    #       Not only for empty selections: ">one,< two" may be more intuitive as ">one, two<"
    #       maybe startIsBeforeSep and endIsBeforeSep? and add an expandListSelection function?
    #       Not immediately necessary, it may even be possible that letting these selections include the extra element is confusing.
    [rangeStart,rangeEnd] = ixRange
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

  ###*
   * @param  {string} bufferText
   * @param  {number[][]} ranges
  ###
  logIxRanges: (bufferText, ranges) ->
    console.log 'logIxRanges:'
    for ixRange in ranges
      console.log 'ixRange: ['+ ixRange[0] + ',' + ixRange[1] + '>:  >>' + bufferText.substr(ixRange[0], ixRange[1] - ixRange[0]) + '<<'

  ###*
   * Convert index-based range array [startIx, endIx] to row/column-based Range.
   * @param  {string}   textBuffer
   * @param  {number[]} ixRange    - Index range: [startIx, endIx]
   * @return {Range} Row/column based Range
  ###
  getRangeForIxRange: (textBuffer, ixRange) ->
    new Range (textBuffer.positionForCharacterIndex ixRange[0]),
              (textBuffer.positionForCharacterIndex ixRange[1])

  ###*
   * Convert row/column-based Range to index-based range array [startIx, endIx]
   * @param  {string}   textBuffer
   * @param  {number[]} ixRange    - Row/column based Range
   * @return {Range} Index range: [startIx, endIx]
  ###
  getIxRangeForRange: (textBuffer, range) ->
    [ (textBuffer.characterIndexForPosition range.start)
    , (textBuffer.characterIndexForPosition range.end) ]


  # TODO: Create a datastructure for these so we can take them from config.cson
  # TODO: Not exactly sure if JSdoc's verbose syntax actually makes things clearer here..
  ###*
   * @constant {String}
  ###
  separatorChars: ';,'

  ###*
   * @constant {String}
  ###
  openBracketChars:  '[{('
  ###*
   * @constant {String}
  ###
  closeBracketChars: ']})'
  ###*
   * @constant {String}
  ###
  defaultSepChars:   ',;,'

  ###*
   * PRECONDITION: c is a 1-character string.
   * @param  {string} c
   * @return {boolean}
  ###
  isSeparator: (c) ->
    @separatorChars.indexOf(c) != -1
    # ':' is sometimes a separator, but allowing it breaks list-edit for JSON objects
    # TODO: Use priorities for determining the separator, so we only take ':' when there is no ',' or ';'?

  # Strings (using whitespace as separator) are tricky, as they can be mistakenly assumed to be open/close bracket
  # e.g. '["Blinky", Inky, "Pinky"]' with cursor on Inky may recognize '", Inky ,"' as list.
  # Disabled, as we also cannot use the same element/whitespace selection for strings with whitespace as separator.

  # < .. > lists also tricky, as unbalanced < and > are quite common in code.
  # Disabled for now, <> lists are not that prevalent anyway.

  ###*
   * PRECONDITION: c is a 1-character string.
   * @param  {string} c
   * @return {boolean}
  ###
  isOpeningBracket: (c) ->
    @openBracketChars.indexOf(c) != -1

  ###*
   * PRECONDITION: c is a 1-character string.
   * @param  {string} c
   * @return {boolean}
  ###
  isClosingBracket: (c) ->
    @closeBracketChars.indexOf(c) != -1

  ###*
   * PRECONDITION: openingBracket is a 1-character string.
   * @param  {string} openingBracket
   * @return {string}
  ###
  getClosingBracketFor: (openingBracket) ->
    ix = @openBracketChars.indexOf(openingBracket)
    if ix >= 0
      @closeBracketChars[ix]
    else
      atom.notifications.addFatalError 'List-edit: Unknown opening bracket \'' + openingBracket + '\''
      undefined

  ###*
   * PRECONDITION: closingBracket is a 1-character string.
   * @param  {string} closingBracket
   * @return {string}
  ###
  getOpeningBracketFor: (closingBracket) ->
    ix = @closeBracketChars.indexOf(closingBracket)
    if ix >= 0
      @openBracketChars[ix]
    else
      atom.notifications.addFatalError 'List-edit: Unknown closing bracket \'' + closingBracket + '\''
      undefined

  ###*
   * PRECONDITION: openingBracket is a 1-character string.
   * @param  {string} openingBracket
   * @return {string}
  ###
  getDefaultSeparatorFor: (openingBracket) ->
    ix = @openBracketChars.indexOf(openingBracket)
    if ix >= 0
      @defaultSepChars[ix]
    else
      atom.notifications.addFatalError 'List-edit: Unknown opening bracket \'' + openingBracket + '\''
      undefined

  ###*
   * @param  {string} text
   * @return {string}
  ###
  getLeadingWhitespace: (text) ->
    (/^\s*/.exec(text) ? [''])[0]

  ###*
   * @param  {string} text
   * @return {string}
  ###
  getTrailingWhitespace: (text) ->
    (/\s*$/.exec(text) ? [''])[0]
