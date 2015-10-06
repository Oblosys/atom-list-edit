ListEdit = require '../lib/list-edit'

describe 'ListEdit', ->
  [editor, editorView] = []

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
        activationPromise
        # TODO: Would be nice if we could do this just once, instead of for each spec, but waitsForPromise does
        #       not seem to work in describe (unlike what the documentation suggests.)

  describe 'list-cut', ->
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
    it 'Cursor before first element of multi-element list pastes clipboard element with correct whitespace and separator', ->
      atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 1]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[NewGhost, Blinky, Pinky, Inky, Clyde]'

    it 'Cursor before between elements of multi-element list pastes clipboard element with correct whitespace and separator', ->
      atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 7]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[Blinky, NewGhost, Pinky, Inky, Clyde]'

    it 'Cursor after last element of multi-element list pastes clipboard element with correct whitespace and separator', ->
      atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 27]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[Blinky, Pinky, Inky, Clyde, NewGhost]'

    it 'Cursor inside element of multi-element list replaces element with clipboard element', ->
      atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 10]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[Blinky, NewGhost, Inky, Clyde]'

  describe 'list-copy/paste between lists', ->
    listCopyFrom = (txt, row, col) ->
      editor.setText txt
      editor.setCursorBufferPosition [row, col]
      atom.commands.dispatch editorView, 'list-edit:copy'

  # 0123456789012345678
    verticalListTxt = '''
    vertical = [ Larry
               , Moe
               , Curly
               ]
    '''

    it 'uses separator whitespace from the target, if available', ->
      listCopyFrom verticalListTxt, 1, 14 # copy Moe
      #               01234567890123456789012345678901234567890
      editor.setText '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]'
      editor.setCursorBufferPosition [0, 11]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[   Blinky ,  Moe ,  Pinky ,  Inky ,  Clyde   ]'

    it 'uses separator whitespace from the source, if not available from target', ->
      listCopyFrom   '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]', 0, 32 # copy Clyde
      #               01234567890123456789012345678901234567890
      editor.setText '[  Blinky  ]'
      editor.setCursorBufferPosition [0, 11]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[  Blinky ,  Clyde  ]'

    # Not ideal, as we throw away the bracket whitespace already present, but it seems more logical
    # than splitting the existing whitespace into initial and final, and also, on cutting all elements,
    # we remove initial and final whitespace as well.
    it 'uses bracket whitespace from the source, if not available from target', ->
      listCopyFrom   '[   Blinky ,  Pinky ,  Inky ,  Clyde   ]', 0, 32 # copy Clyde
      #               01234567890123456789012345678901234567890
      editor.setText '[  ]'
      editor.setCursorBufferPosition [0, 2]
      atom.commands.dispatch editorView, 'list-edit:paste'
      expect(editor.getText()).toBe '[   Clyde   ]'

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
        activationPromise

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
    editor.setCursorBufferPosition [0, 1]
    atom.commands.dispatch editorView, 'list-edit:paste'
    expect(editor.getText()).toBe '["P[ inky", /*Inky,*/ \'Cly]de\', Blinky]'
