$(function () {
  atom.init($('#atom-simulator'));
});

// Very hacky require, tailored to the exact paths that are required by list-edit and dependencies
function require(name) {
  switch (name) {
    case 'atom':
      return window.atom;
    case 'underscore-plus':
      return window._;
    case './text-manipulation':
      return window.TextManipulation;
    default:
      console.error('Unkown module: '+name)
      return {};
  }
}


rangeFromObj = function(obj) {
  if (obj instanceof atom.Range) {
    return obj;
  } else if (Array.isArray(obj)) {
    return new atom.Range( obj[0], obj[1] );
  } else {
   console.error('rangeFromObj parameter is Range nor Array: ');
   console.dir(obj);
  }
}


pointFromObj = function(obj) {
  if (obj instanceof atom.Point) {
    return obj;
  } else if (Array.isArray(obj)) {
    return new atom.Point( obj[0], obj[1] );
  } else {
   console.error('pointFromObj parameter is Point nor Array: ');
   console.dir(obj);
  }
}

window.atom = {
  Range: function(start, end) {
    this.start = start;
    this.end = end;
  },

  Point: function(row, column) {
    this.row = row;
    this.column = column;
  },

  notifications: {
    hideTimer: null,
    addNotification: function(msg, bgColor, duration) {
      $notification = $("#atom-simulator .notification");
      $notification.text(msg);
      $notification.css('background-color', bgColor);
      $notification.hide();
      $notification.fadeIn(50);
      if (this.hideTimer)
        clearTimeout(this.hideTimer);
      this.hideTimer = setTimeout(function() {
        $notification.fadeOut(100);
      }, duration);
    },
    addWarning: function(msg) {
      this.addNotification(msg, 'e8d0a1', 3000);
    },
    addError: function(msg) {
      this.addNotification(msg, 'ecb1b1', 4000);
    }
  },
  clipboard: {
    clipboard: {text: null, meta: null},

    readWithMetadata: function() {
      return this.clipboard;
    },
    write: function(text, metadata) {
      this.clipboard = {text: text, metadata: metadata ? metadata : null};
    }
  },

  workspace: {
    getActiveTextEditor: function()  {
      return this.editor;
    },

    editor: {
      getGrammar: function() {
        return this.grammar;
      },
      grammar: {
        tokenizeLine: function() {
          return {tags: [], ruleStack: []}
        },

        registry: {
          idsByScope: {}
        }
      },

      getBuffer: function() {
        return this.buffer;
      },
      setCursorBufferPosition: function(pos) {
        this.setSelectedBufferRange([pos,pos])
      },
      getSelectedBufferRange: function() {
        return this.buffer.getSelectionRange();
      },
      setSelectedBufferRange: function(range) {
        this.buffer.setSelectionRange(range);
      },

      buffer: {
        $textArea: null,

        getText: function() {
          return this.$textArea.val();
        },
        setText: function(txt) {
          return this.$textArea.val(txt);
        },
        getSelectionRange: function() {
          return new atom.Range( this.positionForCharacterIndex( this.$textArea.get(0).selectionStart )
                               , this.positionForCharacterIndex( this.$textArea.get(0).selectionEnd )
                               )
        },
        setSelectionRange: function(range) {
          range = rangeFromObj(range);
          this.$textArea.get(0).selectionStart = this.characterIndexForPosition( range.start );
          this.$textArea.get(0).selectionEnd = this.characterIndexForPosition( range.end );
        },
        delete: function(range) {
          range = rangeFromObj(range);
          const rangeStartIx = this.characterIndexForPosition( range.start );
          const rangeEndIx = this.characterIndexForPosition( range.end );
          const rangeLength = rangeEndIx - rangeStartIx;
          var selStartIx = this.$textArea.get(0).selectionStart;
          var selEndIx = this.$textArea.get(0).selectionEnd;
          selStartIx = selStartIx <= rangeStartIx ? selStartIx
                                                  : selStartIx < rangeEndIx ? rangeStartIx : selStartIx - rangeLength
          selEndIx = selEndIx <= rangeStartIx ? selEndIx
                                              : selEndIx < rangeEndIx ? rangeStartIx : selEndIx - rangeLength

          this.setTextInRange(range, '');
          this.$textArea.get(0).selectionStart = selStartIx
          this.$textArea.get(0).selectionEnd = selEndIx
        },
        setTextInRange: function(range, text) {
          range = rangeFromObj(range);
          const rangeStartIx = this.characterIndexForPosition( range.start );
          const rangeEndIx = this.characterIndexForPosition( range.end );
          const bufferText = this.$textArea.val();
          this.setText(bufferText.slice(0,rangeStartIx)+text+bufferText.slice(rangeEndIx,bufferText.length));
        },
        positionForCharacterIndex: function(ix) {
          const bufferText = this.$textArea.val();
          var row = 0;
          var col = 0;
          for (i=0; i<ix; i++) {
            if (bufferText[i]=='\n') {
              row++;
              col = 0;
            } else {
              col++;
            }
          }
          return new atom.Point(row,col);
        },
        // Note: does note handle column position past line end (returned ix is on following lines)
        characterIndexForPosition: function(pos) {
          pos = pointFromObj(pos)
          const bufferText = this.$textArea.val();
          var ix = 0;
          const row = pos.row;
          const col = pos.column;
          for (r=0; r<row; r++) {
            nextNewline = bufferText.indexOf('\n', ix);
            if (nextNewline < 0) {
              return bufferText.length;
            } else {
              ix = nextNewline+1;
            }
          }
          return Math.min(ix+col, bufferText.length);
        }
      }
    }
  },

  init: function($atomSimulator) {
    $textArea = $atomSimulator.find('textarea');
    this.workspace.editor.buffer.$textArea = $textArea;
    $textArea.attr('spellcheck', false);
    $textArea.keydown((this.keyHandler).bind(this));
    //ListEdit.test();
  },

  keyHandler: function(event) {
    // console.log(event.charCode);
    // console.log(event.keyCode);
    // console.log(event.altKey);
    // console.log(event.metaKey);
    // console.log(event.ctrlKey);
    if (event.ctrlKey && event.charCode == 115) { // CTRL-S, just for testing
      this.listSelect();
      return false
    }
    if (event.altKey && !event.shiftKey &&
        (event.metaKey && !event.ctrlKey) || (event.ctrlKey && !event.metaKey) ) {
      switch (event.keyCode) {
        case 83:
          this.listSelect();
          break;
        case 88:
          this.listCut();
          break;
        case 67:
          this.listCopy();
          break;
        case 86:
          this.listPaste();
        default:
          return true;
      }
      return false;
    }
  },

  listSelect: function() {
    console.log('list-select');
    ListEdit.selectCmd();
  },

  listCut: function() {
    console.log('list-cut');
    ListEdit.cutCmd();
  },

  listCopy: function() {
    console.log('list-copy');
    ListEdit.copyCmd();
  },

  listPaste: function() {
    console.log('list-paste');
    ListEdit.pasteCmd();
  }
}
