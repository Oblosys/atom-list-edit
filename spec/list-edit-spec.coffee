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
      textBuffer = '[1,[1,2,[]]]'
      expect(TextManipulation.findMatchingOpeningBracket textBuffer, 11, false)
       .toEqual([1, [ [1,3] ]])
      expect(TextManipulation.findMatchingOpeningBracket textBuffer, 10, false)
       .toEqual([4, [ [4,8] ]])
      expect(TextManipulation.findMatchingOpeningBracket textBuffer, 9, false)
       .toEqual([9, [  ]])
      expect(TextManipulation.findMatchingOpeningBracket textBuffer, 8, false)
       .toEqual([4, [ [4,8] ]])
      expect(TextManipulation.findMatchingOpeningBracket textBuffer, 1, false)
       .toEqual([1, [  ]])

  describe 'findMatchingClosingBracket', ->
    # TODO: split into separate 'it' clauses
    it 'works', ->
      #             01234567890123
      textBuffer = '[1,[[],2,3],4]'
      expect(TextManipulation.findMatchingClosingBracket textBuffer, 1, false)
       .toEqual([13, [ [1,3], [11,13] ]])
      expect(TextManipulation.findMatchingClosingBracket textBuffer, 3, false)
       .toEqual([13, [ [11,13] ]])
      expect(TextManipulation.findMatchingClosingBracket textBuffer, 4, false)
       .toEqual([10, [ [6,10] ]])
      expect(TextManipulation.findMatchingClosingBracket textBuffer, 11, false)
       .toEqual([13, [ [11,13] ]])
      expect(TextManipulation.findMatchingClosingBracket textBuffer, 0, false)
       .toEqual(null)

  describe 'getListIxRanges', ->
    #             01234567890123
    textBuffer = '{1,([],2,3),4}'

    it 'should return null when there is no enclosing list', ->
      expect(TextManipulation.getListIxRanges textBuffer, 0)
        .toEqual(null)

    it 'should return the elements of the enclosing list even when index is immediately after opening tag', ->
      expect(TextManipulation.getListIxRanges textBuffer, 1)
        .toEqual([ [1,2], [3,11], [12,13] ])

    it 'should return the elements of a nested list', ->
      expect(TextManipulation.getListIxRanges textBuffer, 4)
        .toEqual( [ [4,6], [7,8], [9,10] ])

    it 'should return the elements (i.e. []) of an empty list', ->
      expect(TextManipulation.getListIxRanges textBuffer, 5)
        .toEqual( [] )


describe 'ListEdit', ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('list-edit')
