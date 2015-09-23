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
    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, listElements, [selStart,selEnd]) ->
      if listElements.length == 0
        atom.notifications.addWarning 'List select in empty list.'
      else
        console.log 'List elements'
        console.log e.show() for e in listElements
        console.log 'Selection: ' + selStart + ' <-> ' + selEnd
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

    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, listElements, [cutStart, cutEnd]) ->
      if listElements.length == 0
        atom.notifications.addWarning 'List cut in empty list.'
      else
        # TODO: refactor copy so we can call it here
        if cutStart == cutEnd
          atom.notifications.addWarning 'Empty list selection.'
          # TODO: on empty, expand selection?
        else
          console.log 'List elements'
          console.log e.show() for e in listElements
          console.log 'Selection: ' + cutStart + ' <-> ' + cutEnd

          # copy selected elements to clipboard
          selectionText = bufferText.slice listElements[cutStart].eltStart, listElements[cutEnd-1].eltEnd
          atom.clipboard.write selectionText, @mkListEditMeta()

          # elts[0 .. cutStart .. cutEnd .. n-1]
          newLength = listElements.length - (cutEnd - cutStart) # +1 since cut range is inclusive
          console.log newLength

          # TODO: rewrite in terms of trailing opening bracket whitespace, leading closing whitespace, etc.
          if newLength == 0
            cutIxRange = [listElements[cutStart].start, listElements[cutEnd-1].end]
            newWhitespace = ''
          else
            if cutStart == 0  # newLength > 0, so not the last one and no need to fix post (and elts[cutEnd] exists)
              cutIxRange = [ listElements[0].start, listElements[cutEnd].eltStart ]
              newWhitespace = listElements[0].leadingWhitespace  # newElts[0].pre = cutElts[0].pre
            else # listElements[cutStart-1] exists
              if cutEnd < listElements.length
                cutIxRange = [ listElements[cutStart-1].end, listElements[cutEnd-1].end] # remove from preceding separator until post whitespace of last cut elt
                newWhitespace = ''
              else
                cutIxRange = [ listElements[cutStart-1].eltEnd, listElements[cutEnd-1].end]
                newWhitespace = listElements[cutEnd-1].trailingWhitespace   #newlistElements[n-1].post = cutElts[m].post
          console.log 'cut index range:' + cutIxRange
          console.log 'inserted: "' + newWhitespace + '"'
          cutRange = TextManipulation.getRangeForIxRange textBuffer, cutIxRange
          console.log cutRange.start
          # editor.setSelectedBufferRange cutRange # for debugging: select the range that will be cut
          textBuffer.setTextInRange cutRange, newWhitespace

  copyCmd: ->
    console.log 'Executing command list-edit-copy'
    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, listElements, [selStart,selEnd]) ->
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
          atom.clipboard.write selectionText, @mkListEditMeta()
          editor.setSelectedBufferRange (TextManipulation.getRangeForIxRange textBuffer,
                                           [listElements[selStart].eltStart, listElements[selEnd-1].eltEnd])

  pasteCmd: ->
    console.log 'Executing command list-edit-paste'
    clip = atom.clipboard.readWithMetadata()
    clipMeta = @getListEditMeta clip
    if not clipMeta
      atom.notifications.addError 'Clipboard does not contain list-edit clip.'
      # TODO: For now this is an error, but we can probably still do something with it in the future
    else
      console.log 'Clipboard contains list-edit clip'
    # On elements, replace element with stripped clipboard, while preserving whitespace (or use cut without setting clip (==delete)?)
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
      listElements = TextManipulation.getListElements bufferText, selectionIxRange
      if not listElements?
        atom.notifications.addWarning 'List-edit: Selection is not in well-formed list.'
      else
        listSelection = TextManipulation.getSelectionForRange listElements, selectionIxRange
        if listSelection.end > listElements.length
          atom.notifications.addError 'List-edit: INTERNAL ERROR: list selection end outside list.'
          # Note: Will not occur, just for easily signaling bugs during development.
        else
          (callback.bind this) editor, textBuffer, bufferText, selectionIxRange, listElements, listSelection

  # TODO: store separator, so we can handle switching elements in list of two
  # Maybe also store first pre (trailing opening bracket), last post (leading closing bracket), one middle post pre (leading, trailing separator),
  # and column nr of opening bracket for handling empty/one elt insertions (column nr is only for multi line lists)


  mkListEditMeta: ->
    {id: 'list-edit-clip-meta'}

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
