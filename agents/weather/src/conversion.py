from langchain_core.messages import HumanMessage, AIMessage, SystemMessage


def convert_openai_to_langchain_messages(messages: list) -> list:
    """Convert OpenAI format messages to LangChain message objects.

    Handles messages with 'role' field (OpenAI format) and converts to
    LangChain message objects (HumanMessage, AIMessage, SystemMessage).

    Args:
        messages: List of messages in OpenAI format or already-converted LangChain objects

    Returns:
        List of LangChain message objects
    """
    converted = []
    for msg in messages:
        # If already a LangChain message object, keep it
        if hasattr(msg, "type"):
            converted.append(msg)
            continue

        # Convert dict with 'role' to LangChain message
        if isinstance(msg, dict):
            role = msg.get("role") or msg.get("type", "user")
            content = msg.get("content", "")

            if role in ["user", "human"]:
                converted.append(HumanMessage(content=content))
            elif role in ["assistant", "ai"]:
                converted.append(AIMessage(content=content))
            elif role == "system":
                converted.append(SystemMessage(content=content))
            else:
                # Default to HumanMessage for unknown roles
                converted.append(HumanMessage(content=content))

    return converted


def convert_langchain_to_openai_message(msg):
    """Convert LangChain message object to OpenAI format dict.

    Handles LangChain message objects and converts to OpenAI format
    with 'role' field (user/assistant/system) instead of 'type'.

    Args:
        msg: LangChain message object or dict

    Returns:
        Dict in OpenAI format with 'role' and 'content' fields
    """
    if hasattr(msg, "dict"):
        return msg.dict()
    elif hasattr(msg, "content"):
        # Convert LangChain type to OpenAI role
        langchain_type = getattr(msg, "type", "unknown")
        role_mapping = {"human": "user", "ai": "assistant", "system": "system"}
        role = role_mapping.get(langchain_type, langchain_type)
        return {"role": role, "content": msg.content}
    return str(msg)
