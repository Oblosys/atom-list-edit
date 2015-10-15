ListEdit = require '../lib/list-edit'

expectNoErrorsOrWarnings = ->
  expect(atom.notifications.addWarning).not.toHaveBeenCalled();
  expect(atom.notifications.addError).not.toHaveBeenCalled();
  expect(atom.notifications.addFatalError).not.toHaveBeenCalled();

describe 'ListEdit', ->
  [editor, editorView] = []

  listCopyFrom = (txt, startRow, startCol, endRow=startRow, endCol=startCol) ->
    editor.setText txt
    editor.setSelectedBufferRange [[startRow, startCol], [endRow, endCol]]
    atom.commands.dispatch editorView, 'list-edit:copy'

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open().then ->
        editor = atom.workspace.getActiveTextEditor()
        editorView = atom.views.getView(editor)
        activationPromise = atom.packages.activatePackage('list-edit')
        # NOTE: Because we use 'atom-text-editor' for the activation commands in package.json,
        #       we need to dispatch to atom.views.getView(editor) instead of atom.views.getView(atom.workspace)
        atom.commands.dispatch editorView, 'list-edit:copy'
        # Activate package with a neutral list-edit:copy, so the test edit commands don't have to deal with activation.
        spyOn atom.notifications, 'addWarning'
        spyOn atom.notifications, 'addError'
        spyOn atom.notifications, 'addFatalError'
        activationPromise
        # TODO: Would be nice if we could do this just once, instead of for each spec, but waitsForPromise does
        #       not seem to work in describe (unlike what the documentation suggests.)


  describe 'list-copy', ->
    afterEach ->
      expectNoErrorsOrWarnings()

    it 'copies the selected range to the clipboard', ->
      #               01234567890123456789012345678901234567890
      editor.setText '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]'
      editor.setSelectedBufferRange [[0, 15], [0,24]] # Pinky & Clyde
      atom.commands.dispatch editorView, 'list-edit:copy'
      clip = atom.clipboard.readWithMetadata()
      expect(clip?.text).toBe('Pinky ,  Inky')
      expect(clip?.metadata).toEqual(
        { id : 'list-edit-clip-meta', openBracket : '['
        , initialWhitespace : '   ', finalWhitespace : '   '
        , separator : { leadingWhitespace: ' ', sepChar : ',', trailingWhitespace : '  ' }
        , eltRanges : [ [0, 5], [9, 13] ]
        })

  describe 'list-cut', ->
    afterEach ->
      expectNoErrorsOrWarnings()

    it 'Cursor inside element in singleton list cuts element and whitespace', ->
      editor.setText '[ Single ]'
      editor.setCursorBufferPosition [0, 3]
      atom.commands.dispatch editorView, 'list-edit:cut'
      expect(editor.getText()).toBe '[]'

    it 'Cursor inside element of multi-element list cuts element including whitespace and separator', ->
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 2]
      atom.commands.dispatch editorView, 'list-edit:cut'
      expect(editor.getText()).toBe '[Pinky, Inky, Clyde]'

    it 'Selection around element of multi-element list cuts element including whitespace and separator', ->
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setSelectedBufferRange [[0, 9], [0,14]]
      atom.commands.dispatch editorView, 'list-edit:cut'
      expect(editor.getText()).toBe '[Blinky, Inky, Clyde]'

  describe 'list-paste', ->
    afterEach ->
      expectNoErrorsOrWarnings()

    it 'pastes clipboard element with correct whitespace and separator when cursor is before first element of multi-element list', ->
      listCopyFrom '[NewGhost]', 0, 2
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 1]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[NewGhost, Blinky, Pinky, Inky, Clyde]'

    it 'pastes clipboard element with correct whitespace and separator when cursor is before between elements of multi-element list', ->
      listCopyFrom '[NewGhost]', 0, 2
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 7]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[Blinky, NewGhost, Pinky, Inky, Clyde]'

    it 'pastes clipboard element with correct whitespace and separator when cursor is after last element of multi-element list', ->
      listCopyFrom '[NewGhost]', 0, 2
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 27]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[Blinky, Pinky, Inky, Clyde, NewGhost]'

    it 'replaces element with clipboard element when cursor is inside element of multi-element list', ->
      listCopyFrom '[NewGhost]', 0, 2
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 10]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[Blinky, NewGhost, Inky, Clyde]'

  describe 'list-copy/paste between lists', ->
    afterEach ->
      expectNoErrorsOrWarnings()

  # 0123456789012345678
    verticalListTxt = '''
    vertical = [ Larry
               , Moe
               , Curly
               ]
    '''

    it 'uses separator whitespace from the target, if available (single-element clip)', ->
      listCopyFrom verticalListTxt, 1, 14 # copy Moe
      #               01234567890123456789012345678901234567890
      editor.setText '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]'
      editor.setCursorBufferPosition [0, 11]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[   Blinky ,  Moe ,  Pinky ,  Inky ,  Clyde   ]'

    it 'uses separator whitespace from the source, if not available from target (single-element clip)', ->
      listCopyFrom   '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]', 0, 32 # copy Clyde
      #               01234567890123456789012345678901234567890
      editor.setText '[  Blinky  ]'
      editor.setCursorBufferPosition [0, 11]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[  Blinky ,  Clyde  ]'

    it 'uses separator and whitespace from the target, if available (multi-element clip)', ->
      listCopyFrom verticalListTxt, 1, 14, 2, 14 # copy Moe & Curly
      #               01234567890123456789012345678901234567890
      editor.setText '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]'
      editor.setCursorBufferPosition [0, 11]
      atom.commands.dispatch editorView, 'list-edit:paste' # paste between Blinky & Pinky
      expect(editor.getText()).toBe '[   Blinky ,  Moe ,  Curly ,  Pinky ,  Inky ,  Clyde   ]'

    it 'uses separator whitespace from the source, if not available from target (multi-element clip)', ->
      listCopyFrom   '{   Blinky ,  Pinky ,  Inky ,  Clyde   }', 0, 24, 0, 32 # copy Inky & Clyde
      #               01234567890123456789012345678901234567890
      editor.setText '{  Blinky  }'
      editor.setCursorBufferPosition [0, 11]
      atom.commands.dispatch editorView, 'list-edit:paste' # paste after Blinky
      expect(editor.getText()).toBe '{  Blinky ,  Inky ,  Clyde  }'

    # Not ideal, as we throw away any existing bracket whitespace, but it seems more logical than
    # splitting the existing whitespace into initial and final, and moreover, on cutting all elements,
    # we remove initial and final whitespace as well.
    it 'uses bracket whitespace from the source, if not available from target', ->
      listCopyFrom   '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]', 0, 32 # copy Clyde
      #               01234567890123456789012345678901234567890
      editor.setText '[  ]'
      editor.setCursorBufferPosition [0, 2]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[   Clyde   ]'

  describe 'separator defaulting', ->
    it 'warns when a default separator is used', ->
      listCopyFrom '[NoSep]', 0, 3
      editor.setText '{NoSepEither}'
      editor.setCursorBufferPosition [0, 1]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '{NoSep; NoSepEither}'
      expect(atom.notifications.addWarning).toHaveBeenCalledWith('Separator unknown, using default: \';\'');
      expect(atom.notifications.addError).not.toHaveBeenCalled();
      expect(atom.notifications.addFatalError).not.toHaveBeenCalled();

    it 'does not warn when a default separator isn\'t used because target range wasn\'t empty', ->
      listCopyFrom '[NoSep]', 0, 3
      editor.setText '{one, two, three}'
      editor.setCursorBufferPosition [0, 7] # paste on two
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '{one, NoSep, three}'
      expectNoErrorsOrWarnings()

    it 'does not warn when a default separator isn\'t used because target list was empty', ->
      listCopyFrom '[NoSep]', 0, 3
      editor.setText '{}'
      editor.setCursorBufferPosition [0, 1] # paste in empty list
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '{NoSep}'
      expectNoErrorsOrWarnings()

describe 'ListEdit on a file with a JavaScript grammar', ->
  [editor, editorView] = []
  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      # atom.workspace.open().then ->
      (atom.workspace.open 'test.js').then ->
        editor = atom.workspace.getActiveTextEditor()
        editorView = atom.views.getView(editor)
        activationPromise = atom.packages.activatePackage('list-edit')
        # NOTE: Because we use 'atom-text-editor' for the activation commands in package.json,
        #       we need to dispatch to atom.views.getView(editor) instead of atom.views.getView(atom.workspace)
        atom.commands.dispatch editorView, 'list-edit:copy'
        # Activate package with a neutral list-edit:copy, so the test edit commands don't have to deal with activation.
        spyOn atom.notifications, 'addWarning'
        spyOn atom.notifications, 'addError'
        spyOn atom.notifications, 'addFatalError'
        activationPromise

  afterEach ->
    expectNoErrorsOrWarnings()

  it 'correctly scans strings and comments', ->
    #               01234567890123456789 01234567 890123456789012 34567890123456789012345
    editor.setText 'some /*text*/ with \'several\' "strings" and\n// a couple of comments'
    expect(ListEdit.scanIgnoreRanges editor, editor.getBuffer(), editor.getBuffer().getText())
       .toEqual( [[5,13], [19,28], [29,38], [43,66]] )
    editor.setText ''
    expect(ListEdit.scanIgnoreRanges editor, editor.getBuffer(), editor.getBuffer().getText())
       .toEqual( [] )
    editor.setText '// just a comment'
    expect(ListEdit.scanIgnoreRanges editor, editor.getBuffer(), editor.getBuffer().getText())
       .toEqual( [[0,17]] )

  # Because cut, paste, and range ignore have been tested, we only have a single test here to show it all works together.
  it 'cuts and pastes in a list that contains strings and a comment', ->
    #               0123456789012345678901234567890 1234567 8
    editor.setText '[Blinky, "P[ inky", /*Inky,*/ \'Cly]de\']'
    editor.setSelectedBufferRange [[0, 14], [0,33]]
    atom.commands.dispatch editorView, 'list-edit:cut'
    expect(editor.getText()).toBe '[Blinky]'

    clip = atom.clipboard.readWithMetadata()
    expect(clip?.text).toBe('"P[ inky", /*Inky,*/ \'Cly]de\'')
    expect(clip?.metadata).toEqual(
      { id : 'list-edit-clip-meta', openBracket : '['
      , initialWhitespace : '', finalWhitespace : ''
      , separator : { leadingWhitespace : '', sepChar : ',', trailingWhitespace : ' ' }
      , eltRanges : [ [0, 9], [11, 29] ]
      })

    editor.setCursorBufferPosition [0, 1]
    atom.commands.dispatch editorView, 'list-edit:paste'
    expect(editor.getText()).toBe '["P[ inky", /*Inky,*/ \'Cly]de\', Blinky]'
