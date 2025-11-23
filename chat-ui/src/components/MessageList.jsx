export default function MessageList({ messages, showToolCalls }) {
  if (messages.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-center px-4">
        <div className="text-slate-600 space-y-3">
          <div className="text-4xl">💬</div>
          <p className="text-lg font-medium text-slate-400">How can I help you today?</p>
          <p className="text-sm text-slate-500">Select an agent above and start a conversation</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {messages.map((message, index) => {
        // Skip tool and AI messages with tool_calls if showToolCalls is false
        if (!showToolCalls) {
          if (message.role === 'tool') return null
          if (message.role === 'assistant' && message.tool_calls?.length > 0) return null
        }

        return <MessageBubble key={index} message={message} showToolCalls={showToolCalls} />
      })}
    </div>
  )
}

function MessageBubble({ message, showToolCalls }) {
  const isUser = message.role === 'user'
  const isError = message.role === 'error'
  const isTool = message.role === 'tool'
  const isAIWithToolCalls = message.role === 'assistant' && message.tool_calls?.length > 0

  // Tool call message (AI invoking a tool)
  if (isAIWithToolCalls && showToolCalls) {
    return (
      <div className="flex justify-start">
        <div className="max-w-[80%] rounded-lg px-4 py-3 bg-purple-500/20 border border-purple-500/50">
          <div className="flex items-center gap-2 mb-2">
            <svg className="w-4 h-4 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <span className="text-sm font-semibold text-purple-300">Tool Call</span>
          </div>
          {message.tool_calls.map((toolCall, idx) => (
            <div key={idx} className="mb-2 last:mb-0">
              <p className="text-purple-200 font-mono text-sm">
                {toolCall.name}(
                {Object.entries(toolCall.args).map(([key, value], i, arr) => (
                  <span key={key}>
                    {key}="{value}"{i < arr.length - 1 ? ', ' : ''}
                  </span>
                ))}
                )
              </p>
            </div>
          ))}
          <p className="text-xs mt-2 opacity-70 text-purple-300">
            {message.timestamp.toLocaleTimeString()}
          </p>
        </div>
      </div>
    )
  }

  // Tool result message
  if (isTool && showToolCalls) {
    let parsedContent
    try {
      parsedContent = JSON.parse(message.content)
    } catch {
      parsedContent = message.content
    }

    return (
      <div className="flex justify-start">
        <div className="max-w-[80%] rounded-lg px-4 py-3 bg-green-500/20 border border-green-500/50">
          <div className="flex items-center gap-2 mb-2">
            <svg className="w-4 h-4 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span className="text-sm font-semibold text-green-300">Tool Result: {message.name}</span>
          </div>
          <pre className="text-xs text-green-200 bg-green-900/30 p-2 rounded overflow-x-auto">
            {JSON.stringify(parsedContent, null, 2)}
          </pre>
          <p className="text-xs mt-2 opacity-70 text-green-300">
            {message.timestamp.toLocaleTimeString()}
          </p>
        </div>
      </div>
    )
  }

  // Regular message (user, assistant, error)
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} group`}>
      <div
        className={`max-w-[85%] rounded-2xl px-4 py-3 ${
          isError
            ? 'bg-red-500/10 text-red-300 border border-red-500/30'
            : isUser
            ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/10'
            : 'bg-slate-800/70 text-slate-100 border border-slate-700/50'
        }`}
      >
        <p className="text-[15px] leading-relaxed whitespace-pre-wrap break-words">{message.content}</p>
        <p className="text-[11px] mt-1.5 opacity-50">
          {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </p>
      </div>
    </div>
  )
}
