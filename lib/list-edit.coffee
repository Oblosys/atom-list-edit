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
      'list-edit:select': => @selectCmd()
      'list-edit:cut':    => @cutCmd()
      'list-edit:copy':   => @copyCmd()
      'list-edit:paste':  => @pasteCmd()
      'list-edit:delete': => @deleteCmd()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    listEditViewState: @listEditView.serialize()

  selectCmd: ->
    console.log 'Executing command list-edit-select'
    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, {elts: listElements}, [selStart,selEnd]) ->
      if listElements.length == 0
        atom.notifications.addWarning 'List select in empty list.'
      else
        console.log 'List elements'
        console.log e.show() for e in listElements
        console.log "Selection: [#{selStart},#{selEnd}>"
        if selStart == selEnd
          atom.notifications.addWarning 'Empty list selection.'
          # TODO: on empty, expand selection?
        else
          console.log (TextManipulation.getRangeForIxRange textBuffer, [listElements[selStart].eltStart, listElements[selEnd-1].eltEnd])

          editor.setSelectedBufferRange(TextManipulation.getRangeForIxRange textBuffer,
                                          [listElements[selStart].eltStart, listElements[selEnd-1].eltEnd])

  cutCmd: ->
    console.log 'Executing command list-edit-cut'
    # select
    # copy
    # delete
    # TODO: clean up all these comments and put clear comments at actual code
    #  1 elt:  remove, including whitespace
    # >1 elts: if not last, remove, put pre whitespace on pre whitespace of next element
    #         if last, put post whitespace on previous element
    # [pre1ELT1post1,pre2ELT2post2,pre3ELT3post3]
    # [pre1ELT1post1,pre2ELT3post3]

    # spec:
    # if newElts.length > 0
    #   if cut == 0  # then newElts[0] will exist, so not the last one and no need to fix post
    #     newElts[0].pre = cutElts[0].pre
    #   else
    #    if cut == newElts.length # newElts.length > 1, so newElts[n-1] exists, not first and no need to fix pre
    #      newElts[n-1].post = cutElts[m].post

    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, {openBracket: openBracket, separator: separator, elts: listElements}, [cutStart, cutEnd]) ->
      if listElements.length == 0
        atom.notifications.addWarning 'List cut in empty list.'
      else
        # TODO: refactor copy so we can call it here
        if cutStart == cutEnd
          atom.notifications.addWarning 'Empty list selection.'
          # TODO: on empty, expand selection?
        else
          # console.log 'List elements'
          # console.log e.show() for e in listElements
          # console.log "Selection: [#{cutStart},#{cutEnd}>"

          # copy selected elements to clipboard
          selectionText = bufferText.slice listElements[cutStart].eltStart, listElements[cutEnd-1].eltEnd
          atom.clipboard.write selectionText, @mkListEditMeta(openBracket, separator)

          if cutStart == 0
            if cutEnd == listElements.length
              # No remaining elements: also cut surrounding whitespace
              # console.log "Cut [> elt .. elt <]"
              cutIxRange = [listElements[cutStart].start, listElements[cutEnd-1].end]
            else
              # Remaining elements only after cut: remove trailing separator
              # console.log "Cut [ >elt .. elt, <elt .. ]"
              cutIxRange = [listElements[cutStart].eltStart, listElements[cutEnd].eltStart]
          else
            if cutEnd < listElements.length
              # Remaining elements before and after cut: remove trailing separator
              # console.log "Cut [ .. elt, >elt .. elt, <elt .. ]"
              cutIxRange = [listElements[cutStart].eltStart, listElements[cutEnd].eltStart]
              # Alternative range that favors removing preceding separator
              # cutIxRange = [listElements[cutStart-1].eltEnd, listElements[cutEnd-1].eltEnd]
            else
              # Remaining elements only before cut: remove precedinging separator
              # console.log "Cut [ .. elt>, elt .. elt< ]"
              cutIxRange = [listElements[cutStart-1].eltEnd, listElements[cutEnd-1].eltEnd]

          # console.log 'cut index range:' + cutIxRange
          cutRange = TextManipulation.getRangeForIxRange textBuffer, cutIxRange
          # editor.setSelectedBufferRange cutRange # for debugging: select the range that will be cut
          textBuffer.delete cutRange

  copyCmd: ->
    console.log 'Executing command list-edit-copy'
    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, {openBracket: openBracket, separator: separator, elts: listElements}, [selStart,selEnd]) ->
      if listElements.length == 0
        atom.notifications.addWarning 'List copy in empty list.'
      else
        if selStart == selEnd
          atom.notifications.addWarning 'Empty list selection.'
          # TODO: on empty, expand selection?
        else
          selectionText = bufferText.slice listElements[selStart].eltStart, listElements[selEnd-1].eltEnd
          # Clip includes separators, which seems logical when we use it for a non-list paste
          #console.log "Copied: '#{selectionText}'"
          console.log 'Separator: ' + JSON.stringify separator
          atom.clipboard.write selectionText, @mkListEditMeta(openBracket, separator)
          editor.setSelectedBufferRange (TextManipulation.getRangeForIxRange textBuffer,
                                           [listElements[selStart].eltStart, listElements[selEnd-1].eltEnd])

  pasteCmd: ->
    console.log 'Executing command list-edit-paste'
    clip = atom.clipboard.readWithMetadata()
    clipMeta = @getListEditMeta clip
    if not clipMeta
      atom.notifications.addError 'Clipboard does not contain list-edit clip.'
      # TODO: For now this is an error, but we can probably still do something with it in the future (maybe simply strip whitespace and paste)
    else
      # TODO: For now assume clipboard comes from the same list as paste target
      @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, elementList, [selStart,selEnd]) ->
        {startIx: listStartIx, endIx: listEndIx, openBracket: openBracket, separator: separator, elts: listElements} = elementList
        console.log "About to list-paste \"#{clip.text}\" at selection [#{selStart},#{selEnd}>"
        console.log "Opening bracket: #{openBracket}, separator: #{JSON.stringify separator}, clip separator: #{JSON.stringify clip?.separator}"
        #TODO: name separator is confusing
        separator ?= if clipMeta.openBracket == openBracket and clipMeta.separator
                       # console.log 'Using separator from clipboard'
                       clipMeta.separator # Use separator from clipboard only if it comes from a list with equal brackets
                     else
                       # console.log 'Using default separator for \'' + openBracket + '\''
                       { leadingWhitespace: '>>'
                       , sepChar: (TextManipulation.getDefaultSeparatorFor openBracket)
                       , trailingWhitespace: '<<'
                       }
        # console.log "Separator: #{JSON.stringify separator}"

        {leadingWhitespace: sepLeadingWhitespace, sepChar: sepChar, trailingWhitespace: sepTrailingWhitespace} =
          separator
        if selStart != selEnd
          # if an element or a range is selected, all surrounding whitespace can be left untouched
          # (assuming the clip comes from the same list)
          pasteIxRange = [listElements[selStart].eltStart, listElements[selEnd-1].eltEnd]
          pasteText = clip.text
          # TODO: What to do with multi-element clips? These will contain separators of their own.
          #       Modify to match target list? Mismatch between the two will probably be rather rare.
        else
          # empty target range
          if listElements.length == 0
            console.log 'Paste in empty list'
            pasteIxRange = [listStartIx, listEndIx]
            pasteText = ' ' + clip.text + ' ' # TODO: try to take pre and post from clipboard list?
          else
            console.log 'Paste on non-empty list'
            if selStart == 0
              console.log '  before list start'
              pasteIxRange = [listElements[selStart].eltStart,listElements[selStart].eltStart] # immediately in front of following element
              pasteText = clip.text + sepLeadingWhitespace + sepChar + sepTrailingWhitespace

            else if selStart == listElements.length
              console.log '  after list end'
              pasteIxRange = [listElements[selStart-1].eltEnd,listElements[selStart-1].eltEnd] # immediately in after of preceding element
              pasteText = sepLeadingWhitespace + sepChar + sepTrailingWhitespace + clip.text
            else
              console.log '  between start and end (list len > 1)'
              pasteIxRange = [listElements[selStart].eltStart,listElements[selStart].eltStart] # immediately in front of following element
              pasteText = clip.text + sepLeadingWhitespace + sepChar + sepTrailingWhitespace

        pasteRange = TextManipulation.getRangeForIxRange textBuffer, pasteIxRange
        textBuffer.setTextInRange pasteRange, pasteText
        editor.setCursorBufferPosition (textBuffer.positionForCharacterIndex pasteIxRange[0] + pasteText.length)

    # not on elements
    #   0 elts, make up bracket space (later we can take it from the clip, possibly modifying it for different indentations (when copying from other lists))
    #   1 elt,  make up sep space, just use sep+' ' for now (later we can take it from the clip, possibly modifying it for different indentations (when copying from other lists))
    # > 1 elts, before first element: newElt.whitespace = element[0].whitespace, element[0].whitespace.pre =element[1].whitespace.pre
    #           after last element:   newElt.whitespace = element[n-1].whitespace, element[n-1].whitespace.post =element[n-2].whitespace.post
    #           between i and i+1:    newElt.whitespace.pre = element[i+1].whitepace.pre, newElt.whitespace.post = element[i].whitepace.post
    # maybe always using third rule and having special cases for i=0 and i = n-1 is elegant? (patching the existing elt's whitespace in those cases may make it less elegant)


    # for testing, use digits as whitespace
    # Write algorithm with trailing opening bracket whitespace, etc. Will make it easier to handle pasting from different lists.
    # [bracket-space-1ELTbracket-space2]
    # [bracket-space-1ELTsep-space-1,sep-space-2ELTbracketspace2]
  deleteCmd: ->
    console.log 'Executing command list-edit-delete'

  # Wrapper for easy access of common variables
  withSelectedList: (callback) ->
    editor = atom.workspace.getActiveTextEditor()
    if editor?
      textBuffer = editor.getBuffer()
      bufferText = textBuffer.getText()
      selectionIxRange = TextManipulation.getIxRangeForRange textBuffer, (editor.getSelectedBufferRange())
      elementList = TextManipulation.getElementList bufferText, selectionIxRange
      if not elementList?
        atom.notifications.addWarning 'List-edit: Selection is not in well-formed list.'
      else
        listSelection = TextManipulation.getSelectionForRange elementList.elts, selectionIxRange
        if listSelection.end > elementList.elts.length
          atom.notifications.addError 'List-edit: INTERNAL ERROR: list selection end outside list.'
          # Note: Will not occur, just for easily signaling bugs during development.
        else
          (callback.bind this) editor, textBuffer, bufferText, selectionIxRange, elementList, listSelection

  # TODO: store separator, so we can handle switching elements in list of two
  # Maybe also store first pre (trailing opening bracket), last post (leading closing bracket), one middle post pre (leading, trailing separator),
  # and column nr of opening bracket for handling empty/one elt insertions (column nr is only for multi line lists)


  mkListEditMeta: (openBracket, separator) ->
    {id: 'list-edit-clip-meta', openBracket: openBracket, separator: separator}

  getListEditMeta: (clip) ->
    clip.metadata if clip?.metadata?.id == 'list-edit-clip-meta'


# for testing in console:
# Activation from console does not seem to work anymore: > atom.packages.activatePackage('list-edit')
# Access active package (need to activate package manually first)
# > atom.packages.activePackages['list-edit'].mainModule.<function>

# Modules can be required for easily testing functions in console: (can be put in init.coffee)
# edit = require ('/Users/martijn/git/atom-list-edit/lib/list-edit.coffee')
# text = require ('/Users/martijn/git/atom-list-edit/lib/text-manipulation.coffee')

# Some test lists:
# [1,[1,2,[ ,, ]]]
# [dsd,[kdd], "ddd"]
# [ Blinky, Inky, [some, inner, nesting], Pinky,[ j] ,kjl, (1,2,3), jkj]
