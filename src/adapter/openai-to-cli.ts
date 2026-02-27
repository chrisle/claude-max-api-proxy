/**
 * Converts OpenAI chat request format to Claude CLI input
 */

import type { OpenAIChatRequest, OpenAIContentPart } from "../types/openai.js";

export type ClaudeModel = "opus" | "sonnet" | "haiku";

export interface CliInput {
  prompt: string;
  model: ClaudeModel;
  sessionId?: string;
  systemPrompt?: string;
}

const MODEL_MAP: Record<string, ClaudeModel> = {
  // Direct model names
  "claude-opus-4": "opus",
  "claude-opus-4-6": "opus",
  "claude-sonnet-4": "sonnet",
  "claude-sonnet-4-5": "sonnet",
  "claude-haiku-4": "haiku",
  "claude-haiku-4-5": "haiku",
  // Aliases
  "opus": "opus",
  "sonnet": "sonnet",
  "haiku": "haiku",
};

/**
 * Extract Claude model alias from request model string
 * Handles any provider prefix (claude-max/, claude-code-cli/, etc.)
 */
export function extractModel(model: string | undefined): ClaudeModel {
  if (!model) {
    return "opus"; // Default to opus
  }

  // Try direct lookup
  if (MODEL_MAP[model]) {
    return MODEL_MAP[model];
  }

  // Try stripping any provider prefix (e.g., "claude-max/", "claude-code-cli/")
  const stripped = model.replace(/^[^/]+\//, "");
  if (MODEL_MAP[stripped]) {
    return MODEL_MAP[stripped];
  }

  // Default to opus (Claude Max subscription)
  return "opus";
}

/**
 * Extract text content from OpenAI message content
 * Handles both string and array formats
 */
function extractContent(content: string | OpenAIContentPart[] | unknown): string {
  if (typeof content === "string") {
    return content;
  }

  if (Array.isArray(content)) {
    return content
      .map(part => {
        if (typeof part === "string") return part;
        if (part && part.type === "text" && typeof part.text === "string") {
          return part.text;
        }
        return "";
      })
      .filter(Boolean)
      .join("\n");
  }

  return String(content ?? "");
}

/**
 * Extract system prompts from messages
 * Returns concatenated system messages
 */
export function extractSystemPrompt(messages: OpenAIChatRequest["messages"]): string | undefined {
  const systemMessages = messages
    .filter(msg => msg.role === "system")
    .map(msg => extractContent(msg.content))
    .filter(Boolean);

  return systemMessages.length > 0 ? systemMessages.join("\n\n") : undefined;
}

/**
 * Convert OpenAI messages array to a single prompt string for Claude CLI
 *
 * Claude Code CLI in --print mode expects a single prompt, not a conversation.
 * We format the messages into a readable format that preserves context.
 * System messages are now handled separately via --append-system-prompt flag.
 */
export function messagesToPrompt(messages: OpenAIChatRequest["messages"]): string {
  const parts: string[] = [];

  for (const msg of messages) {
    switch (msg.role) {
      case "system":
        // System messages are now handled via --append-system-prompt flag
        // Skip them here to avoid duplication
        break;

      case "user":
        // User messages are the main prompt
        parts.push(extractContent(msg.content));
        break;

      case "assistant":
        // Previous assistant responses for context
        parts.push(`<previous_response>\n${extractContent(msg.content)}\n</previous_response>\n`);
        break;
    }
  }

  return parts.join("\n").trim();
}

/**
 * Convert OpenAI chat request to CLI input format
 */
export function openaiToCli(request: OpenAIChatRequest): CliInput {
  return {
    prompt: messagesToPrompt(request.messages),
    model: extractModel(request.model),
    sessionId: request.user, // Use OpenAI's user field for session mapping
    systemPrompt: extractSystemPrompt(request.messages),
  };
}
