_ = require 'underscore-plus'


module.exports =
  stripLeadingWhitespace: (source) ->
    source.replace(/^\s+/, '')

  stripTrailingWhitespace: (source) ->
    source.replace(/\s+$/, '')
