# to be called from repository root dir
coffee --compile --bare --output docs lib/*.coffee && jsdoc --destination docs docs/*
