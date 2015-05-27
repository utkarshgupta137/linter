{CompositeDisposable, Emitter} = require 'atom'

{LinterTrace, LinterError, LinterWarning} = require './messages'

class EditorLinter
  constructor: (@Linter, @Editor) ->
    @InProgress = false
    @InProgressFly = false
    @Messages = []
    @MessagesFly = []
    @MessagesRegular = []

    @Emitter = new Emitter
    @Subscriptions = new CompositeDisposable
    @Buffer = Editor.getBuffer()

    @Subscriptions.add(@Editor.onDidSave @lint.bind(@, false))
    @Subscriptions.add(@Editor.onDidStopChanging @lint.bind(@, true))
    @Subscriptions.add(@Editor.onDidChangeCursorPosition ({newBufferPosition}) =>
      @Linter.Messages = @Messages
      @Linter.View.updateBubble newBufferPosition
    )

  lint: (OnChange) ->
    return if @progress OnChange
    @progress OnChange, true
    @lint true unless OnChange

    Scopes = @Editor.scopeDescriptorForBufferPosition(@Editor.getCursorBufferPosition()).scopes
    Promises = @lintResults OnChange, Scopes
    Promise.all(Promises).then (Results) =>
      @progress OnChange, false
      Messages = []
      for Result in Results
        continue if (not Result) or (typeof Result) isnt 'object'
        if Result instanceof Array
          Messages = Messages.concat(Result)
      if OnChange
        @MessagesFly = Messages
      else
        @MessagesRegular = Messages
      @Messages = @MessagesFly.concat(@MessagesRegular)
      @Emitter.emit 'did-update', @Messages
      @Linter.Messages = @Messages
      @Linter.render() if @Editor is atom.workspace.getActiveTextEditor()
    .catch ->
      console.error arguments[0].stack
      @progress OnChange, false
  lintResults: (OnChange, Scopes) ->
    Promises = []
    for Linter in @Linter.Linters
      return if OnChange and not Linter.lintOnFly
      return if (not OnChange) and Linter.lintOnFly
      return unless (Scopes.filter (Entry) -> Linter.scopes.indexOf(Entry) isnt -1 ).length
      Promises.push(
        Linter.lint(@Editor, @Buffer, {
          Error: LinterError,
          Warning: LinterWarning,
          Trace: LinterTrace
        })
      )
    Promises

  progress: (onChange, newValue) ->
    if typeof newValue is 'undefined'
      if onChange
        return @InProgressFly
      else
        return @InProgress
    else
      if onChange
        @InProgressFly = newValue
      else
        @InProgress = newValue
  destroy: ->
    @Emitter.emit 'did-destroy'
    @Subscriptions.dispose()

  onDidUpdate: (Callback) ->
    @Emitter.on 'did-update', Callback

  onDidDestroy: (Callback) ->
    @Emitter.on 'did-destroy', Callback


module.exports = EditorLinter