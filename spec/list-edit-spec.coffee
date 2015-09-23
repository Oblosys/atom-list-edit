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

  describe 'getListElements', ->
    #mkListElement = (
    #             01234567890123
    bufferText = '{1,([],2,3),4}'

    it 'should return null when there is no enclosing list', ->
      expect(TextManipulation.getListElements bufferText, [0,0])
        .toEqual(null)

    it 'should return the elements of the enclosing list even when index is immediately after opening tag', ->
      expect(TextManipulation.getListElements bufferText, [1,1])
        .toEqual(_.map [ [1,2], [3,11], [12,13] ], (r) -> new TextManipulation.ListElement bufferText, r)

    it 'should return the elements of a nested list', ->
      expect(TextManipulation.getListElements bufferText, [4,4])
        .toEqual(_.map [ [4,6], [7,8], [9,10] ], (r) -> new TextManipulation.ListElement bufferText, r)

    it 'should return the elements (i.e. []) of an empty list', ->
      expect(TextManipulation.getListElements bufferText, [5,5])
        .toEqual( [] )

    it 'should allow empty ranges', ->
      expect(TextManipulation.getListElements '[ ,, ]', [1,1])
        .toEqual(_.map [ [1,2], [3,3], [4,5] ], (r) -> new TextManipulation.ListElement '[ ,, ]', r)

    it 'should allow empty ranges at start and end', ->
      expect(TextManipulation.getListElements '[, ,]', [1,1])
        .toEqual(_.map [ [1,1], [2,3], [4,4] ], (r) -> new TextManipulation.ListElement '[, ,]', r)

describe 'ListEdit', ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('list-edit')
