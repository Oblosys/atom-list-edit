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

  describe 'list-cut', ->
    it 'Cursor inside element in singleton list cuts element and whitespace', ->
      editor.setText '[ Single ]'
      editor.setCursorBufferPosition [0, 3]
      atom.commands.dispatch editorView, 'list-edit:cut'
      expect(editor.getText()).toEqual '[]'

    it 'Cursor inside element of multi-element list cuts element including whitespace and separator', ->
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setCursorBufferPosition [0, 2]
      atom.commands.dispatch editorView, 'list-edit:cut'
      expect(editor.getText()).toEqual '[Pinky, Inky, Clyde]'

    it 'Selection around element of multi-element list cuts element including whitespace and separator', ->
      editor.setText '[Blinky, Pinky, Inky, Clyde]'
      editor.setSelectedBufferRange [[0, 9], [0,14]]
      atom.commands.dispatch editorView, 'list-edit:cut'
      expect(editor.getText()).toEqual '[Blinky, Inky, Clyde]'

    describe 'list-paste', ->
      it 'Cursor before first element of multi-element list pastes clipboard element with correct whitespace and separator', ->
        atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
        editor.setText '[Blinky, Pinky, Inky, Clyde]'
        editor.setCursorBufferPosition [0, 1]
        atom.commands.dispatch editorView, 'list-edit:paste'
        expect(editor.getText()).toEqual '[NewGhost, Blinky, Pinky, Inky, Clyde]'

      it 'Cursor before between elements of multi-element list pastes clipboard element with correct whitespace and separator', ->
        atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
        editor.setText '[Blinky, Pinky, Inky, Clyde]'
        editor.setCursorBufferPosition [0, 7]
        atom.commands.dispatch editorView, 'list-edit:paste'
        expect(editor.getText()).toEqual '[Blinky, NewGhost, Pinky, Inky, Clyde]'

      it 'Cursor after last element of multi-element list pastes clipboard element with correct whitespace and separator', ->
        atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
        editor.setText '[Blinky, Pinky, Inky, Clyde]'
        editor.setCursorBufferPosition [0, 27]
        atom.commands.dispatch editorView, 'list-edit:paste'
        expect(editor.getText()).toEqual '[Blinky, Pinky, Inky, Clyde, NewGhost]'

      it 'Cursor inside element of multi-element list replaces element with clipboard element', ->
        atom.clipboard.write 'NewGhost', ListEdit.mkListEditMeta('[', ',')
        editor.setText '[Blinky, Pinky, Inky, Clyde]'
        editor.setCursorBufferPosition [0, 10]
        atom.commands.dispatch editorView, 'list-edit:paste'
        expect(editor.getText()).toEqual '[Blinky, NewGhost, Inky, Clyde]'
