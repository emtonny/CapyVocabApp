/// <reference types="edge-runtime" />

import { createChatTranslationHandler } from "./handler.ts";
import { createGeminiTranslationProvider } from "./gemini_provider.ts";
import { createSupabaseTranslationQueue } from "./supabase_translation_queue.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
const triggerSecret = Deno.env.get("CHAT_TRANSLATION_TRIGGER_SECRET")?.trim() ??
  "";
const geminiApiKey = Deno.env.get("CHAT_GEMINI_API_KEY")?.trim() ?? "";

const queue = supabaseUrl && serviceRoleKey
  ? createSupabaseTranslationQueue({ supabaseUrl, serviceRoleKey })
  : undefined;
const provider = geminiApiKey
  ? createGeminiTranslationProvider({ apiKey: geminiApiKey })
  : undefined;

const logger = {
  info(
    event: string,
    fields: Readonly<Record<string, string | number | boolean | null>>,
  ) {
    console.info(event, fields);
  },
  warn(
    event: string,
    fields: Readonly<Record<string, string | number | boolean | null>>,
  ) {
    console.warn(event, fields);
  },
};

Deno.serve(
  createChatTranslationHandler({
    triggerSecret,
    queue,
    provider,
    logger,
  }),
);
