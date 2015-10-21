# list-edit package  [![Build Status](https://travis-ci.org/Oblosys/atom-list-edit.svg?branch=master)](https://travis-ci.org/Oblosys/atom-list-edit)

List-edit provides list-aware cut, copy, and paste operations that automatically handle separators and whitespace, while taking into account strings and comments. For example, to cut the first element from `[Three, One, Two]` and paste it at the end:

![Single-line list edit](https://raw.githubusercontent.com/oblosys/atom-list-edit/master/img/single-line-list-edit.png)

On `list-cut` the list element that contains the cursor is removed, together with its trailing separator and whitespace. After moving the cursor past the last element, `list-paste` inserts the cut element and puts a separator and whitespace in front of it. List-edit also works in a vertical layout and on multiple elements:

![Multi-line list edit](https://raw.githubusercontent.com/oblosys/atom-list-edit/master/img/multi-line-list-edit.png)

And even between different lists (with yet another layout):

![List-edit between lists edit](https://raw.githubusercontent.com/oblosys/atom-list-edit/master/img/list-edit-between-lists.png)


List-edit uses the grammar of the edited file to ignore strings and comments, but list detection takes place purely on a lexical level. Currently, `{}`, `[]`, and `()` are brackets, and `,` and `;` are separators.

For more information, including a small emulator, in which you can try out the package, visit [list-edit.oblomov.com](http://list-edit.oblomov.com).

### Key bindings (Mac)

Keys        | Command       | &nbsp;
----------- | ------------- | -------
<span style="white-space: nowrap">`alt-cmd-s`</span> | <span style="white-space: nowrap">`list-select`</span> | Select element at cursor, or range of elements in selection
`alt-cmd-x` | `list-cut`    | Cut elements (and separator+whitespace) at cursor/selection
`alt-cmd-c` | `list-copy`   | Copy elements at cursor/selection to the clipboard
`alt-cmd-v` | `list-paste`  | Paste elements (and separator+whitespace) at cursor/selection

Windows and Linux key bindings use `ctrl-alt` instead of `alt-cmd`.
