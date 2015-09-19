{CompositeDisposable, Range, TextBuffer} = require 'atom'
_ = require 'underscore-plus'
TextManipulation = require './text-manipulation'


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
    editor = atom.workspace.getActiveTextEditor()
    if editor?
      cursorPos = editor.getCursorBufferPosition()
      textBuffer = editor.getBuffer()
      bufferText = textBuffer.getText()
      cursorIx = textBuffer.characterIndexForPosition cursorPos

      listElements = TextManipulation.getListElements bufferText, textBuffer.characterIndexForPosition cursorPos

      if listElements?
        elementIndex = TextManipulation.getElementIndexInList listElements, cursorIx
        elt = listElements[elementIndex]
        console.log 'elementIndex: ' + elementIndex
        if elementIndex?
          console.log listElements[elementIndex]
          console.log (TextManipulation.getRangeForIxRange textBuffer, [elt.strippedElementStartIx, elt.strippedElementEndIx])
          editor.setSelectedBufferRange(TextManipulation.getRangeForIxRange textBuffer, [elt.strippedElementStartIx, elt.strippedElementEndIx])

  cut: ->
    console.log 'Executing command list-edit-cut'
    # select
    # copy
    # delete

    #  1 elt:  remove, including whitespace
    # >1 elts: if not last, remove, put pre whitespace on pre whitespace of next element
    #         if last, put post whitespace on previous element

    # Not cut, but some test code to easily visualize ranges
    editor = atom.workspace.getActiveTextEditor()
    # TODO: add null check? (should always exist because we use 'atom-text-editor' command)

    cursorPos = editor.getCursorBufferPosition()
    console.log 'cursor row ' + cursorPos.row + ' col ' + cursorPos.column
    textBuffer = editor.getBuffer()
    bufferText = textBuffer.getText()

    listElements = TextManipulation.getListElements bufferText, textBuffer.characterIndexForPosition cursorPos

    # Atom bug?
    # fn = textBuffer.positionForCharacterIndex
    # console.log (textBuffer.positionForCharacterIndex)
    # console.log (fn)
    # console.log (textBuffer.positionForCharacterIndex 2)
    # console.log (fn 2 ) #fails

    bufferRanges = _.map listElements, (elt) ->
      TextManipulation.getRangeForIxRange textBuffer, [elt.strippedElementStartIx, elt.strippedElementEndIx]

    console.log 'bufferRanges:'
    console.log bufferRanges

    if bufferRanges? && bufferRanges.length > 0
      editor.setSelectedBufferRanges(bufferRanges)

  copy: ->
    console.log 'Executing command list-edit-copy'
    # select
    # copy

    # Select, strip whitespace and copy to clipboard

  paste: ->
    console.log 'Executing command list-edit-paste'

    # On element, replace element with stripped clipboard, while preserving whitespace
    #   1 elt,  make up bracket space, just use sep+' ' for now
    # > 1 elts, before first element: newElt.whitespace = element[0].whitespace, element[0].whitespace.pre =element[1].whitespace.pre
    #           after last element:   newElt.whitespace = element[n-1].whitespace, element[n-1].whitespace.post =element[n-2].whitespace.post
    #           between i and i+1:    newElt.whitespace.pre = element[i+1].whitepace.pre, newElt.whitespace.post = element[i].whitepace.post
    # maybe always using third rule and having special cases for i=0 and i = n-1 is elegant? (patching the existing elt's whitespace in those cases may make it less elegant)

    # maybe declare bracketRightWhitespace bracketLeftWhitespace, separatorLeftWhitespace and separatorRightWhitespace
    # and use those to format the necessary elements? Or maybe not, as explicit distinction may not be necessary

    # for testing, use digits as whitespace

    # need some function to determing if we're on the element, before, or after
    # setPreWhitespace
    # getPreWhitespace
    #           patch next or previous element's whitespace

    # [bracket-space-1ELTbracket-space2]
    # [bracket-space-1ELTsep-space-1,sep-space-2ELTbracketspace2]
  delete: ->
    console.log 'Executing command list-edit-delete'

# for testing in console:
# > atom.packages.activatePackage('list-edit')
# > atom.packages.activePackages['list-edit'].mainModule.<function>

# Some test lists:
# [1,[1,2,[ ,, ]]]
# [dsd,[kdd], "ddd"]
# [ Blinky, Inky, [some, inner, nesting], Pinky,[ j] ,kjl, (1,2,3), jkj]
