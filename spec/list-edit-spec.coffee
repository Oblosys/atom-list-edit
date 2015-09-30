_ = require 'underscore-plus'
ListEdit = require '../lib/list-edit'
TextManipulation = require '../lib/text-manipulation'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe 'TextManipulation', ->
  sourceFragment = 'Data 1 2 3'
  leadingWhitespace = ' ' #'\n\n\t '
  trailingWhitespace = ' ' #'\n\n\t '
  describe 'stripLeadingWhitespace', ->
    it 'strips leading whitespace', ->
    expect(TextManipulation.stripLeadingWhitespace (leadingWhitespace+sourceFragment+trailingWhitespace))
      .toEqual(sourceFragment+trailingWhitespace)
    it 'is identity when there is no leading whitespace', ->
    expect(TextManipulation.stripLeadingWhitespace (sourceFragment+trailingWhitespace))
      .toEqual(sourceFragment+trailingWhitespace)
    it 'handles whitespace-only string', ->
    expect(TextManipulation.stripLeadingWhitespace (leadingWhitespace+trailingWhitespace))
      .toEqual('')

  describe 'stripTrailingWhitespace', ->
    it 'strips trailing whitespace', ->
    expect(TextManipulation.stripTrailingWhitespace (leadingWhitespace+sourceFragment+trailingWhitespace))
      .toEqual(leadingWhitespace+sourceFragment)
    it 'is identity when there is no trailing whitespace', ->
    expect(TextManipulation.stripTrailingWhitespace (leadingWhitespace+sourceFragment))
      .toEqual(leadingWhitespace+sourceFragment)
    it 'handles whitespace-only string', ->
    expect(TextManipulation.stripTrailingWhitespace (leadingWhitespace+trailingWhitespace))
      .toEqual('')

  describe 'findMatchingOpeningBracket', ->
    # TODO: split into separate 'it' clauses
    it 'works', ->
      #             012345678901
      bufferText = '[1,[1,2,[]]]'
      expect(TextManipulation.findMatchingOpeningBracket bufferText, 11, false)
       .toEqual({bracketIx: 1, ranges: [ [1,3] ]})
      expect(TextManipulation.findMatchingOpeningBracket bufferText, 10, false)
       .toEqual({bracketIx: 4, ranges: [ [4,8] ]})
      expect(TextManipulation.findMatchingOpeningBracket bufferText, 9, false)
       .toEqual({bracketIx: 9, ranges: [  ]})
      expect(TextManipulation.findMatchingOpeningBracket bufferText, 8, false)
       .toEqual({bracketIx: 4, ranges: [ [4,8] ]})
      expect(TextManipulation.findMatchingOpeningBracket bufferText, 1, false)
       .toEqual({bracketIx: 1, ranges: [  ]})

  describe 'findMatchingClosingBracket', ->
    # TODO: split into separate 'it' clauses
    it 'works', ->
      #             01234567890123
      bufferText = '[1,[[],2,3],4]'
      expect(TextManipulation.findMatchingClosingBracket bufferText, 1, false)
       .toEqual({bracketIx: 13, ranges: [ [1,3], [11,13] ]})
      expect(TextManipulation.findMatchingClosingBracket bufferText, 3, false)
       .toEqual({bracketIx: 13, ranges: [ [11,13] ]})
      expect(TextManipulation.findMatchingClosingBracket bufferText, 4, false)
       .toEqual({bracketIx: 10, ranges: [ [6,10] ]})
      expect(TextManipulation.findMatchingClosingBracket bufferText, 11, false)
       .toEqual({bracketIx: 13, ranges: [ [11,13] ]})
      expect(TextManipulation.findMatchingClosingBracket bufferText, 0, false)
       .toEqual(null)

  describe 'getElementList', ->
    #             01234567890123
    bufferText = '{1,([],2,3),4}'

    it 'should return null when there is no enclosing list', ->
      expect(TextManipulation.getElementList bufferText, [0,0])
        .toEqual(null)

    it 'should return the elements of the enclosing list even when index is immediately after opening tag', ->
      expect((TextManipulation.getElementList bufferText, [1,1]).elts)
        .toEqual(_.map [ [1,2], [3,11], [12,13] ], (r) -> new TextManipulation.ListElement bufferText, r)

    it 'should return the elements of a nested list', ->
      expect((TextManipulation.getElementList bufferText, [4,4]).elts)
        .toEqual(_.map [ [4,6], [7,8], [9,10] ], (r) -> new TextManipulation.ListElement bufferText, r)

    it 'should return the elements (i.e. []) of an empty list', ->
      expect((TextManipulation.getElementList bufferText, [5,5]).elts)
        .toEqual( [] )

    it 'should allow empty ranges', ->
      expect((TextManipulation.getElementList '[ ,, ]', [1,1]).elts)
        .toEqual(_.map [ [1,2], [3,3], [4,5] ], (r) -> new TextManipulation.ListElement '[ ,, ]', r)

    it 'should allow empty ranges at start and end', ->
      expect((TextManipulation.getElementList '[, ,]', [1,1]).elts)
        .toEqual(_.map [ [1,1], [2,3], [4,4] ], (r) -> new TextManipulation.ListElement '[, ,]', r)

  describe 'getSelectionForRange', ->
    #                                             1234567890123456789012345
    listElts = (TextManipulation.getElementList '[   Inky , Dinky , Pinky  ]', [1,1]).elts

    it 'should select a single element when selection is inside the element', ->
      expect(TextManipulation.getSelectionForRange listElts, [5,5]).toEqual([0,1])

    it 'should select multiple elements when selection starts and ends inside these elements', ->
      expect(TextManipulation.getSelectionForRange listElts, [3,12]).toEqual([0,2])

    it 'should select a single element when selection surrounds the element', ->
      expect(TextManipulation.getSelectionForRange listElts, [3,9]).toEqual([0,1])

    it 'should select a all elements when selection surrounds all elements', ->
      expect(TextManipulation.getSelectionForRange listElts, [1,26]).toEqual([0,3])

    it 'should select an empty range when selection is in leading whitespace', ->
      expect(TextManipulation.getSelectionForRange listElts, [2,3]).toEqual([0,0])

    it 'should select an empty range when selection is in trailing whitespace', ->
      expect(TextManipulation.getSelectionForRange listElts, [24,25]).toEqual([3,3])

    it 'should select an empty range when selection surrounds single separator', ->
      expect(TextManipulation.getSelectionForRange listElts, [9,10]).toEqual([1,1])

    it 'should select a single element when selection surrounds the element and adjoining separators', ->
      expect(TextManipulation.getSelectionForRange listElts, [9,18]).toEqual([1,2])


describe 'ListEdit', ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('list-edit')
