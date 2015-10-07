_ = require 'underscore-plus'
TextManipulation = require '../lib/text-manipulation'

describe 'TextManipulation', ->
  sourceFragment = 'Data 1 2 3'
  leadingWhitespace = ' ' #'\n\n\t '
  trailingWhitespace = ' ' #'\n\n\t '
  describe 'stripLeadingWhitespace', ->
    it 'strips leading whitespace', ->
    expect(TextManipulation.stripLeadingWhitespace (leadingWhitespace+sourceFragment+trailingWhitespace))
      .toBe(sourceFragment+trailingWhitespace)
    it 'is identity when there is no leading whitespace', ->
    expect(TextManipulation.stripLeadingWhitespace (sourceFragment+trailingWhitespace))
      .toBe(sourceFragment+trailingWhitespace)
    it 'handles whitespace-only string', ->
    expect(TextManipulation.stripLeadingWhitespace (leadingWhitespace+trailingWhitespace))
      .toBe('')

  describe 'stripTrailingWhitespace', ->
    it 'strips trailing whitespace', ->
    expect(TextManipulation.stripTrailingWhitespace (leadingWhitespace+sourceFragment+trailingWhitespace))
      .toBe(leadingWhitespace+sourceFragment)
    it 'is identity when there is no trailing whitespace', ->
    expect(TextManipulation.stripTrailingWhitespace (leadingWhitespace+sourceFragment))
      .toBe(leadingWhitespace+sourceFragment)
    it 'handles whitespace-only string', ->
    expect(TextManipulation.stripTrailingWhitespace (leadingWhitespace+trailingWhitespace))
      .toBe('')

  describe 'findMatchingOpeningBracket', ->
    #             0123456789012
    bufferText = '[1,[1,2,[]]]'
    it 'handles index at end of nested list', ->
      expect(TextManipulation.findMatchingOpeningBracket bufferText, [], 11, false)
       .toEqual({bracketIx: 0, ranges: [ [1,3] ]})
    it 'handles index at end of nested list contents', ->
      expect(TextManipulation.findMatchingOpeningBracket bufferText, [], 10, false)
       .toEqual({bracketIx: 3, ranges: [ [4,8] ]})
    it 'handles index at start of nested nested list contents', ->
      expect(TextManipulation.findMatchingOpeningBracket bufferText, [], 9, false)
       .toEqual({bracketIx: 8, ranges: [  ]})
    it 'handles index at start of nested nested list', ->
      expect(TextManipulation.findMatchingOpeningBracket bufferText, [], 8, false)
       .toEqual({bracketIx: 3, ranges: [ [4,8] ]})
    it 'handles index at start of list contents', ->
      expect(TextManipulation.findMatchingOpeningBracket bufferText, [], 1, false)
       .toEqual({bracketIx: 0, ranges: [  ]})

    #                 01234567890123
    nestedListText = '[xxx[xxx]xxx]'
    it 'handles ignoredRange preceding nested list', ->
      expect(TextManipulation.findMatchingOpeningBracket nestedListText, [[2,3]], 11, false)
       .toEqual({bracketIx: 0, ranges: [ [1, 2], [3, 4], [9, 11] ]})
    it 'handles ignoredRange immediately preceding nested list', ->
      expect(TextManipulation.findMatchingOpeningBracket nestedListText, [[2,4]], 11, false)
       .toEqual({bracketIx: 0, ranges: [ [1, 2], [9, 11] ]})
    it 'handles ignoredRange spanning start of nested list', ->
      expect(TextManipulation.findMatchingOpeningBracket nestedListText, [[2,5]], 11, false)
       .toEqual(null)
    it 'handles ignoredRange following nested list', ->
      expect(TextManipulation.findMatchingOpeningBracket nestedListText, [[10, 11]], 11, false)
       .toEqual({bracketIx: 0, ranges: [ [1, 4], [9, 10] ]})
    it 'handles ignoredRange immediately following nested list', ->
      expect(TextManipulation.findMatchingOpeningBracket nestedListText, [[9,11]], 11, false)
       .toEqual({bracketIx: 0, ranges: [ [1, 4] ]})
    it 'handles index inside ignoredRange', ->
      expect(TextManipulation.findMatchingOpeningBracket nestedListText, [[3, 11]], 10, false)
       .toEqual({bracketIx: 0, ranges: [ [1, 3] ]})

  describe 'findMatchingClosingBracket', ->
    #             01234567890123
    bufferText = '[1,[[],2,3],4]'
    it 'handles index at start of list contents', ->
      expect(TextManipulation.findMatchingClosingBracket bufferText, [], 1, false)
       .toEqual({bracketIx: 13, ranges: [ [1,3], [11,13] ]})
    it 'handles index at start of nested list', ->
      expect(TextManipulation.findMatchingClosingBracket bufferText, [], 3, false)
       .toEqual({bracketIx: 13, ranges: [ [11,13] ]})
    it 'handles index at start of nested list contents', ->
      expect(TextManipulation.findMatchingClosingBracket bufferText, [], 4, false)
       .toEqual({bracketIx: 10, ranges: [ [6,10] ]})
    it 'handles index at end of nested list', ->
      expect(TextManipulation.findMatchingClosingBracket bufferText, [], 11, false)
       .toEqual({bracketIx: 13, ranges: [ [11,13] ]})
    it 'handles index at start of list', ->
      expect(TextManipulation.findMatchingClosingBracket bufferText, [], 0, false)
       .toEqual(null)

    #                 01234567890123
    nestedListText = '[xxx[xxx]xxx]'
    it 'handles ignoredRange following nested list', ->
      expect(TextManipulation.findMatchingClosingBracket nestedListText, [[9, 11]], 2, false)
       .toEqual({bracketIx: 12, ranges: [ [2, 4], [11, 12] ]})
    it 'handles ignoredRange immediately following nested list', ->
      expect(TextManipulation.findMatchingClosingBracket nestedListText, [[10, 11]], 2, false)
       .toEqual({bracketIx: 12, ranges: [ [2, 4], [9, 10], [11, 12] ]})
    it 'handles ignoredRange spanning end of nested list', ->
      expect(TextManipulation.findMatchingClosingBracket nestedListText, [[8, 11]], 2, false)
       .toEqual(null)
    it 'handles ignoredRange preceding nested list', ->
      expect(TextManipulation.findMatchingClosingBracket nestedListText, [[2, 4]], 2, false)
       .toEqual({bracketIx: 12, ranges: [ [9, 12] ]})
    it 'handles ignoredRange immediately preceding nested list', ->
      expect(TextManipulation.findMatchingClosingBracket nestedListText, [[2, 3]], 2, false)
       .toEqual({bracketIx: 12, ranges: [ [3, 4], [9, 12] ]})
    it 'handles index inside ignoredRange', ->
      expect(TextManipulation.findMatchingClosingBracket nestedListText, [[2, 10]], 3, false)
       .toEqual({bracketIx: 12, ranges: [ [10, 12] ]})

  describe 'getEnclosingList', ->
    #             01234567890123
    bufferText = '[1,(a,b),2]'
    it 'works when surrounding a nested list', ->
      expect(TextManipulation.getEnclosingList bufferText, [], 3, 8)
        .toEqual({listRange: [1, 10], nonNestedRanges: [[1, 3], [8, 10]]})
    it 'works when inside a nested list', ->
      expect(TextManipulation.getEnclosingList bufferText, [], 5, 5)
        .toEqual({listRange: [4, 7], nonNestedRanges: [[4, 5], [5, 7]]})
    it 'fails on bracket mismatch', ->
      expect(TextManipulation.getEnclosingList '(  ]', 2, 2)
        .toEqual(null)

  describe 'getListContainingRange', ->
    #                       1         2         3         4
    #             01234567890123456789012345678901234567890123456789
    bufferText = '[one, f(a,b), two, {p1: [v1,v2], p2:v3}, three]'
    it 'handles range inside one element', ->
      expect(TextManipulation.getListContainingRange bufferText, [], [1, 1])
        .toEqual({listRange: [1, 46], nonNestedRanges : [[1, 7], [12, 19], [39, 46]]})
    it 'handles range starting inside one element and ending inside another element', ->
      expect(TextManipulation.getListContainingRange bufferText, [], [1, 15])
        .toEqual({listRange: [1, 46], nonNestedRanges : [[1, 7], [12, 19], [39, 46]]})
    it 'handles range starting in one nested list and ending in a nested list inside another nested list', ->
      expect(TextManipulation.getListContainingRange bufferText, [], [8, 25])
        .toEqual({listRange: [1, 46], nonNestedRanges : [[1, 7], [12, 19], [39, 46]]})

  describe 'getElementList', ->
    getEltRanges = (elementList) ->
      _.map elementList?.elts, (li) -> [li.eltStart, li.eltEnd]

    #             01234567890123
    bufferText = '{1,([],2,3),4}'

    it 'returns null when there is no enclosing list', ->
      expect(TextManipulation.getElementList bufferText, [], [0,0])
        .toEqual(null)

    it 'returns the elements of the enclosing list even when index is immediately after opening tag', ->
      expect(getEltRanges (TextManipulation.getElementList bufferText, [], [1,1]))
        .toEqual( [[1,2], [3,11], [12,13]] )

    it 'returns the elements of a nested list', ->
      expect(getEltRanges (TextManipulation.getElementList bufferText, [], [4,4]))
        .toEqual( [[4,6], [7,8], [9,10]] )

    it 'returns the elements (i.e. []) of an empty list', ->
      expect(getEltRanges (TextManipulation.getElementList bufferText, [], [5,5]))
        .toEqual( [] )

    it 'allows empty ranges', ->
      expect(getEltRanges (TextManipulation.getElementList '[ ,, ]', [], [1,1]))
        .toEqual( [[2,2], [3,3], [4,4]] )

    it 'allows empty ranges at start and end', ->
      expect(getEltRanges (TextManipulation.getElementList '[, ,]', [], [1,1]))
        .toEqual( [[1,1], [3,3], [4,4]] )

    #                        0123456789012345678901234
    bufferTextWithIgnores = '[ "one", "[a,b]", "two" ]'
    ignoreRanges = [[2,7], [9,16], [18,23]]
    fit 'ignores brackets and separators in ignoreRanges', ->
      expect(getEltRanges (TextManipulation.getElementList bufferTextWithIgnores, ignoreRanges, [11,14]))
        .toEqual([[2,7], [9,16], [18,23]])

  describe 'getSelectionForRange', ->
    #                                            012345678901234567890123456789012345
    listElts = (TextManipulation.getElementList '[   Blinky , Dinky , Pinky, Clyde  ]', [], [1,1]).elts

    it 'selects a single element when selection is inside the element', ->
      expect(TextManipulation.getSelectionForRange listElts, [5,5]).toEqual([0,1])

    it 'selects multiple elements when selection starts and ends inside these elements', ->
      expect(TextManipulation.getSelectionForRange listElts, [5,15]).toEqual([0,2])

    it 'selects a single element when selection surrounds the element', ->
      expect(TextManipulation.getSelectionForRange listElts, [1,13]).toEqual([0,1])

    it 'selects all elements when selection surrounds all elements', ->
      expect(TextManipulation.getSelectionForRange listElts, [1,35]).toEqual([0,4])

    it 'selects an empty range when selection is in leading whitespace', ->
      expect(TextManipulation.getSelectionForRange listElts, [2,3]).toEqual([0,0])

    it 'selects an empty range when selection is in trailing whitespace', ->
      expect(TextManipulation.getSelectionForRange listElts, [33,34]).toEqual([4,4])

    it 'selects an empty range when selection surrounds single separator', ->
      expect(TextManipulation.getSelectionForRange listElts, [11,12]).toEqual([1,1])

    it 'should select a single element when selection surrounds the element and adjoining separators', ->
      expect(TextManipulation.getSelectionForRange listElts, [11,20]).toEqual([1,2])

  describe 'findRangeForIndex', ->
    ignoreRanges = [[1,2],[3,4],[5,6],[7,8],[9,10]]

    it 'handles index before ranges', ->
      expect(TextManipulation.findRangeForIndex ignoreRanges, 0)
        .toEqual(null)

    it 'handles index after ranges', ->
      expect(TextManipulation.findRangeForIndex ignoreRanges, 10)
        .toEqual(null)

    it 'handles index between ranges', ->
      expect(TextManipulation.findRangeForIndex ignoreRanges, 4)
        .toEqual(null)

    it 'handles index inside left-most range', ->
      expect(TextManipulation.findRangeForIndex ignoreRanges, 1)
        .toEqual([1,2])

    it 'handles index inside right-most range', ->
      expect(TextManipulation.findRangeForIndex ignoreRanges, 9)
        .toEqual([9,10])

    it 'handles index inside middle range', ->
      expect(TextManipulation.findRangeForIndex ignoreRanges, 5)
        .toEqual([5,6])

    it 'handles index inside range left of middle', ->
      expect(TextManipulation.findRangeForIndex [[1,2],[3,4],[5,6],[7,8]], 3)
        .toEqual([3,4])

  describe 'backwardSkipIgnored', ->
    ignoreRanges = [[1,2],[4,6],[8,10]]

    it 'handles index after ignore', ->
      expect(TextManipulation.backwardSkipIgnored ignoreRanges, 7)
        .toEqual(7)
    it 'handles index immediately after ignore', ->
      expect(TextManipulation.backwardSkipIgnored ignoreRanges, 6)
        .toEqual(4)
    it 'handles index inside ignore', ->
      expect(TextManipulation.backwardSkipIgnored ignoreRanges, 5)
        .toEqual(4)
    it 'handles index at start of ignore', ->
      expect(TextManipulation.backwardSkipIgnored ignoreRanges, 4)
        .toEqual(4)

  describe 'forwardSkipIgnored', ->
    ignoreRanges = [[1,2],[4,6],[8,10]]

    it 'handles index before ignore', ->
      expect(TextManipulation.forwardSkipIgnored ignoreRanges, 3)
        .toEqual(3)
    it 'handles index at start of ignore', ->
      expect(TextManipulation.forwardSkipIgnored ignoreRanges, 4)
        .toEqual(6)
    it 'handles index inside ignore', ->
      expect(TextManipulation.forwardSkipIgnored ignoreRanges, 5)
        .toEqual(6)
    it 'handles index immediately after ignore', ->
      expect(TextManipulation.forwardSkipIgnored ignoreRanges, 6)
        .toEqual(6)
