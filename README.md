# list-edit package  [![Build Status](https://travis-ci.org/Oblosys/atom-list-edit.svg?branch=master)](https://travis-ci.org/Oblosys/atom-list-edit)

List-edit provides list-aware cut, copy, and paste operations that automatically handle separators and whitespace, while taking into account strings and comments. For example, to cut the first element from `[Three, One, Two]` and paste it at the end, you can do:

![Single-line list edit](https://raw.githubusercontent.com/oblosys/atom-list-edit/master/img/single-line-list-edit.png)

On `list-cut` the trailing separator and whitespace are removed, whereas on `list-paste` a leading separator and whitespace are inserted. To select a list element, it is sufficient to have the cursor inside the element instead of selecting a range.

List-edit also works in a vertical layout:

![Multi-line list edit](https://raw.githubusercontent.com/oblosys/atom-list-edit/master/img/multi-line-list-edit.png)

List-edit commands recognize the edited list and whitespace associated with the brackets and separators. Strings and comments are ignored based on the grammar of the edited file, but list recognition takes place purely on a lexical level. Hence there exist pathological examples in which list-paste will yield unexpected results, but these are quite rare (see the section on separators and whitespace on [list-edit.oblomov.com](http://list-edit.oblomov.com#separator-handling) for more information).

Currently, `{}`, `[]`, and `()` are considered brackets, and `,` and `;`
separators. Besides list-cut, -copy, and -paste, there is also `list-select`, which only selects the list element(s), without affecting clipboard or text buffer.

For more information, including a live demo of the package, visit [list-edit.oblomov.com](http://list-edit.oblomov.com).
