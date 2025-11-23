import { useState } from 'react'

export default function MessageInput({ onSendMessage, isLoading }) {
  const [input, setInput] = useState('')

  const handleSubmit = (e) => {
    e.preventDefault()
    if (input.trim() && !isLoading) {
      onSendMessage(input.trim())
      setInput('')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="relative">
      <input
        type="text"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        disabled={isLoading}
        placeholder="Send a message..."
        className="w-full bg-slate-800/50 border border-slate-700/50 rounded-xl px-4 py-3.5 pr-12
                   text-slate-100 placeholder-slate-500
                   focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:border-emerald-500/50
                   disabled:opacity-50 disabled:cursor-not-allowed
                   transition-all duration-200"
      />
      <button
        type="submit"
        disabled={!input.trim() || isLoading}
        className="absolute right-2 top-1/2 -translate-y-1/2
                   w-8 h-8 rounded-lg
                   bg-emerald-600 hover:bg-emerald-500
                   text-white font-medium
                   transition-all duration-200
                   disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:bg-emerald-600
                   flex items-center justify-center
                   shadow-lg shadow-emerald-600/20"
        aria-label={isLoading ? 'Sending...' : 'Send message'}
      >
        {isLoading ? (
          <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
        ) : (
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        )}
      </button>
    </form>
  )
}
