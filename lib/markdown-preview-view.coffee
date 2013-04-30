$ = require 'jquery'
_ = require 'underscore'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'
roaster = require 'roaster'
Editor = require 'editor'

fenceNameToExtension =
  "ruby": "rb"

module.exports =
class MarkdownPreviewView extends ScrollView
  registerDeserializer(this)

  @deserialize: ({path}) ->
    new MarkdownPreviewView(project.bufferForPath(path))

  @content: ->
    @div class: 'markdown-preview', tabindex: -1

  initialize: (@buffer) ->
    super

    @renderMarkdown()
    @on 'core:move-up', => @scrollUp()
    @on 'core:move-down', => @scrollDown()

  afterAttach: (onDom) ->
    @subscribe @buffer, 'saved', =>
      @fetchRenderedMarkdown()
      pane = @getPane()
      pane.showItem(this) if pane? and pane isnt rootView.getActivePane()

  getPane: ->
    @parent('.item-views').parent('.pane').view()

  serialize: ->
    deserializer: 'MarkdownPreviewView'
    path: @buffer.getPath()

  getTitle: ->
    "Markdown Preview – #{@buffer.getBaseName()}"

  getUri: ->
    "markdown-preview:#{@buffer.getPath()}"

  getPath: ->
    @buffer.getPath()

  setErrorHtml: (result)->
    try failureMessage = JSON.parse(result).message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      if failureMessage?
        @h3 failureMessage
      else
        @h3 'Possible Reasons'
        @ul =>
          @li =>
            @span 'You aren\'t online or are unable to reach '
            @a 'github.com', href: 'https://github.com'
            @span '.'

  setLoading: ->
    @html($$$ -> @div class: 'markdown-spinner', 'Loading Markdown...')

  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))

    for codeBlock in preList.toArray()
      codeBlock = $(codeBlock.firstChild)

      # go to next block unless this one has a class
      continue unless className = codeBlock.attr('class')

      fenceName = className.replace(/^lang-/, '')
      # go to next block unless the class name is matches `lang`
      continue unless extension = fenceNameToExtension[fenceName]
      text = codeBlock.text()
      syntax.selectGrammar("foo.#{extension}", text)

      # go to next block if this grammar is not mapped
      continue unless grammar = syntax.selectGrammar("foo.#{extension}", text)
      continue if grammar is syntax.nullGrammar

      tokens = grammar.tokenizeLines(text)
      grouping = ""
      for token in tokens
        grouping += Editor.buildHtmlLine(token, text)
      codeBlock.replaceWith(grouping)

    html

  renderMarkdown: ->
    @setLoading()
    roaster(@buffer.getText(), {}, (err, html) =>
      if err
        @setErrorHtml(err)
      else
        @html(@tokenizeCodeBlocks(html))
    )
