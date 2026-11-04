import Anthropic from '@anthropic-ai/sdk';
import { EXTRACTION_SCHEMA } from '../extraction.js';

/** A file the model should read alongside the text (receipt photo or PDF). */
export interface ExtractionFile {
  mimeType: 'image/jpeg' | 'image/png' | 'image/webp' | 'application/pdf';
  base64: string;
}

export interface ProviderCall {
  apiKey: string;
  model: string;
  system: string;
  text: string;
  file?: ExtractionFile;
}

export interface ProviderResult {
  json: unknown;
  inputTokens: number;
  outputTokens: number;
}

/** A provider error, classified so the caller can log it and fail over. */
export class ProviderError extends Error {
  constructor(
    message: string,
    readonly kind: 'auth' | 'rate_limit' | 'unavailable' | 'bad_request' | 'refusal' | 'incomplete' | 'invalid_output',
  ) {
    super(message);
  }
}

/** Requests are short extractions; fail fast so failover to the next provider is quick. */
const REQUEST_TIMEOUT_MS = 60_000;

/**
 * Claude via the official Anthropic SDK. Uses structured outputs (JSON
 * schema) so the response always parses, low effort (simple extraction),
 * and the server-side refusal fallback so a safety-classifier decline is
 * retried on Anthropic's recommended model inside the same call.
 */
export async function extractWithAnthropic(call: ProviderCall): Promise<ProviderResult> {
  const client = new Anthropic({ apiKey: call.apiKey, timeout: REQUEST_TIMEOUT_MS, maxRetries: 1 });

  const content: Anthropic.Beta.BetaContentBlockParam[] = [];
  if (call.file?.mimeType === 'application/pdf') {
    content.push({ type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: call.file.base64 } });
  } else if (call.file) {
    content.push({ type: 'image', source: { type: 'base64', media_type: call.file.mimeType, data: call.file.base64 } });
  }
  content.push({ type: 'text', text: call.text });

  let response: Anthropic.Beta.BetaMessage;
  try {
    response = await client.beta.messages.create({
      model: call.model,
      max_tokens: 4096,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      system: call.system,
      output_config: { effort: 'low', format: { type: 'json_schema', schema: EXTRACTION_SCHEMA as unknown as Record<string, unknown> } },
      messages: [{ role: 'user', content }],
    });
  } catch (error) {
    // Most specific first (shared/error-codes.md): auth -> rate limit -> other status -> connection.
    if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
      throw new ProviderError('The API key was rejected', 'auth');
    }
    if (error instanceof Anthropic.RateLimitError) throw new ProviderError('Rate limited by the provider', 'rate_limit');
    if (error instanceof Anthropic.BadRequestError || error instanceof Anthropic.NotFoundError) {
      throw new ProviderError(`Request rejected: ${error.message.slice(0, 200)}`, 'bad_request');
    }
    if (error instanceof Anthropic.APIError && error.status !== undefined) {
      throw new ProviderError(`Provider error ${error.status}`, 'unavailable');
    }
    if (error instanceof Anthropic.APIConnectionError) throw new ProviderError('Could not reach the provider', 'unavailable');
    throw error;
  }

  if (response.stop_reason === 'refusal') {
    throw new ProviderError(`The model declined this request${response.stop_details?.category ? ` (${response.stop_details.category})` : ''}`, 'refusal');
  }
  if (response.stop_reason === 'max_tokens') throw new ProviderError('The response was cut off', 'incomplete');

  const text = response.content
    .filter((block): block is Anthropic.Beta.BetaTextBlock => block.type === 'text')
    .map((block) => block.text)
    .join('');
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new ProviderError('The model returned text that is not valid JSON', 'invalid_output');
  }
  return { json, inputTokens: response.usage.input_tokens, outputTokens: response.usage.output_tokens };
}
