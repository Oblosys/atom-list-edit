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

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->

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
    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, elementList, [cutStart, cutEnd]) ->
      { startIx: listStartIx, endIx: listEndIx
      , openBracket: openBracket, separator: separator
      , initialWhitespace: initialWhitespace, finalWhitespace: finalWhitespace
      , elts: listElements
      } = elementList
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
          atom.clipboard.write selectionText, @mkListEditMeta(openBracket, separator, initialWhitespace, finalWhitespace)

          if cutStart == 0
            if cutEnd == listElements.length
              # No remaining elements: also cut surrounding whitespace
              # console.log "Cut [> elt .. elt <]"
              cutIxRange = [listStartIx, listEndIx]
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
    @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, elementList, [selStart,selEnd]) ->
      { startIx: listStartIx, endIx: listEndIx
      , openBracket: openBracket, separator: separator
      , initialWhitespace: initialWhitespace, finalWhitespace: finalWhitespace
      , elts: listElements
      } = elementList
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
          atom.clipboard.write selectionText, @mkListEditMeta(openBracket, separator, initialWhitespace, finalWhitespace)
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
      @withSelectedList (editor, textBuffer, bufferText, selectionIxRange, elementList, [selStart,selEnd]) ->
        {startIx: listStartIx, endIx: listEndIx, openBracket: openBracket, separator: separator, elts: listElements} = elementList
        console.log "About to list-paste \"#{clip.text}\" at selection [#{selStart},#{selEnd}>"
        console.log "Opening bracket: #{openBracket}, separator: #{JSON.stringify separator}, clip separator: #{JSON.stringify clip?.separator}"

        separator ?= if clipMeta.openBracket == openBracket and clipMeta.separator
                       # console.log 'Using separator from clipboard'
                       clipMeta.separator # Use separator from clipboard only if it comes from a list with equal brackets
                       # TODO: Adapt separator indentation level
                     else
                       defaultSepChar = TextManipulation.getDefaultSeparatorFor openBracket
                       atom.notifications.addWarning "List-paste: Separator unknown, using default: '#{defaultSepChar}'"
                       # TODO: only need to warn when separator is actually used
                       # console.log 'Using default separator for \'' + openBracket + '\''
                       # TODO: Guess whitespace based on layout of brackets? (horizontal/vertical)
                       #       Put default whitespace in configuration?
                       {leadingWhitespace: '', sepChar: defaultSepChar, trailingWhitespace: ' '}
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
          #       But we might as well do it, since we need to adapt the whitespace to the new list anyway.
        else
          # empty target range
          if listElements.length == 0
            console.log 'Paste in empty list'
            pasteIxRange = [listStartIx, listEndIx]
            pasteText = clipMeta.initialWhitespace + clip.text + clipMeta.finalWhitespace
          else
            console.log 'Paste on non-empty list'
            if selStart < listElements.length
              console.log '  not after last element'
              pasteIxRange = [listElements[selStart].eltStart,listElements[selStart].eltStart] # immediately in front of following element
              pasteText = clip.text + sepLeadingWhitespace + sepChar + sepTrailingWhitespace
            else
              console.log '  after last element'
              pasteIxRange = [listElements[selStart-1].eltEnd,listElements[selStart-1].eltEnd] # immediately in after of preceding element
              pasteText = sepLeadingWhitespace + sepChar + sepTrailingWhitespace + clip.text

        pasteRange = TextManipulation.getRangeForIxRange textBuffer, pasteIxRange
        textBuffer.setTextInRange pasteRange, pasteText
        editor.setCursorBufferPosition (textBuffer.positionForCharacterIndex pasteIxRange[0] + pasteText.length)

  # Wrapper for easy access of common variables
  withSelectedList: (callback) ->
    editor = atom.workspace.getActiveTextEditor()
    if editor?
      textBuffer = editor.getBuffer()
      bufferText = textBuffer.getText()
      selectionIxRange = TextManipulation.getIxRangeForRange textBuffer, (editor.getSelectedBufferRange())
      ignoreRanges = @scanIgnoreRanges editor, textBuffer, bufferText
      elementList = TextManipulation.getElementList bufferText, ignoreRanges, selectionIxRange
      if not elementList?
        atom.notifications.addWarning 'List-edit: Selection is not in well-formed list.'
      else
        listSelection = TextManipulation.getSelectionForRange elementList.elts, selectionIxRange
        if listSelection.end > elementList.elts.length
          atom.notifications.addError 'List-edit: INTERNAL ERROR: list selection end outside list.'
          # Note: Will not occur, just for easily signaling bugs during development.
        else
          # Can also use => in the definition of the callbacks that require @, but this is safer
          (callback.bind this) editor, textBuffer, bufferText, selectionIxRange, elementList, listSelection

  # TODO: Probably easier to just pass the entire elementList
  mkListEditMeta: (openBracket, separator, initialWhitespace, finalWhitespace) ->
    { id: 'list-edit-clip-meta', openBracket: openBracket
    , initialWhitespace: initialWhitespace, finalWhitespace: finalWhitespace
    , separator: separator
    }

  getListEditMeta: (clip) ->
    clip.metadata if clip?.metadata?.id == 'list-edit-clip-meta'

  ignoreScopes: ['string', 'comment']

  # Return all ranges that have a scope from ignoreScopes. Connecting ranges are merged.
  scanIgnoreRanges: (editor, textBuffer, bufferText) ->
    grammar = editor.getGrammar()
    ignoredScopeIds = []
    for scope, scopeId of grammar.registry.idsByScope # TODO: is this how we should access the GrammarRegistry?
      # console.log scopeId + ': ' + scope
      if (_.some @ignoreScopes, (skipScope) -> return scope == skipScope || scope.startsWith skipScope)
        ignoredScopeIds.push scopeId

    lines = bufferText.split('\n')
    # console.log  JSON.stringify grammar.tokenizeLines bufferText
    ignoredRanges = []
    currentIgnoreRanges = []
    inIgnoreRange = false
    startOfIgnoreRange = null
    # Because we don't need the fully tokenized text, we replicate some code
    # from Grammar##tokenizeLines and GrammarRegistry##decodeTokens.

    ruleStack = null
    for line, lineNr in lines
      {tags, ruleStack} = grammar.tokenizeLine line, ruleStack, lineNr is 0
      # console.log 'tags line '+lineNr + JSON.stringify tags
      # tokenizeLines returns newline tags only sometimes (e.g. at the end of line comments), which has two consequences
      # - We cannot add content tags to get an accurate bufferIx, as newlines will be missing, so we use
      #   characterIndexForPosition, which is only log(bufferText.length) and also avoids CRLF issues.
      # - As skip ranges are closed on content tags, ranges for strings at the end of line will incorrectly include the newline,
      #   which is fine, since we can skip the newline anyway.
      bufferIx = textBuffer.characterIndexForPosition [lineNr, 0]
      for tag in tags
        if tag < 0
          # "odd negative numbers are begin scope tags"
          # "even negative numbers are end scope tags"
          isOpenTag = (tag % 2) is -1
          tagId = if isOpenTag then tag else tag + 1
          if _.contains ignoredScopeIds, tagId
            if isOpenTag
              # console.log 'Open ignored scope id: ' + tagId
              currentIgnoreRanges.push tagId
            else
              # console.log 'Close ignored scope id: ' + tagId
              currentIgnoreRanges.pop() # Scopes will be nested correctly, so we can simply pop the last one
        else
          # console.log 'content: ' + tag + '   ' + currentIgnoreRanges
          if currentIgnoreRanges.length > 0
            if not inIgnoreRange
              startOfIgnoreRange = bufferIx
              inIgnoreRange = true
          else
            # "positive numbers indicate string content with length equaling the number"
            # 0 indicates empty line
            if inIgnoreRange
              ignoredRanges.push [startOfIgnoreRange, bufferIx]
              inIgnoreRange = false
              # Because we use content tags to close skip ranges, strings at the end of line will
              # include the newline, as this does not show up as a tag, causing the string scope to end on the next line
              # This is not a problem though, as we skip the newline as well.
          bufferIx += tag

    if inIgnoreRange
      ignoredRanges.push [startOfIgnoreRange, Math.min bufferIx, bufferText.length ]
      # Grammar##tokenizeLine assumes all lines, including the last one, to end with a newline, even if
      # the last line has no newline. Hence, the newline tag mentioned above may appear also on the last line,
      # in which case it will span beyond the end of file.
    ignoredRanges


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
