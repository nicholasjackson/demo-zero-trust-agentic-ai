import { useState, useRef, useEffect } from 'react'
import MessageList from './MessageList'
import MessageInput from './MessageInput'
import { sendMessageToAgent } from '../services/agentApi'

export default function ChatContainer({ selectedAgent, showToolCalls, accessToken }) {
  const [messages, setMessages] = useState([])
  const [isLoading, setIsLoading] = useState(false)
  const messagesEndRef = useRef(null)

  // Scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  // Clear messages when switching agents
  useEffect(() => {
    setMessages([])
  }, [selectedAgent])

  const handleSendMessage = async (content) => {
    // Add user message to chat
    const userMessage = { role: 'user', content, timestamp: new Date() }
    setMessages(prev => [...prev, userMessage])

    setIsLoading(true)

    try {
      // Call agent API through service, passing access token if available
      const allMessages = await sendMessageToAgent(selectedAgent, content, accessToken)

      // Add all messages with proper types and timestamps
      const processedMessages = allMessages
        .filter(msg => msg.type !== 'human') // Skip the echoed user message
        .map(msg => ({
          ...msg,
          timestamp: new Date(),
          // Normalize role for consistent rendering
          role: msg.type === 'ai' ? 'assistant' : msg.type
        }))

      setMessages(prev => [...prev, ...processedMessages])

    } catch (error) {
      console.error('Error sending message:', error)
      // Add error message to chat
      setMessages(prev => [...prev, {
        role: 'error',
        content: `Error: ${error.message}`,
        timestamp: new Date()
      }])
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="h-full flex flex-col">
      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-6">
        <div className="max-w-3xl mx-auto">
          <MessageList
            messages={messages}
            showToolCalls={showToolCalls}
          />
          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Input */}
      <div className="flex-shrink-0 border-t border-slate-800/50 p-4 bg-slate-950/50 backdrop-blur-sm">
        <div className="max-w-3xl mx-auto">
          <MessageInput
            onSendMessage={handleSendMessage}
            isLoading={isLoading}
          />
        </div>
      </div>
    </div>
  )
}
