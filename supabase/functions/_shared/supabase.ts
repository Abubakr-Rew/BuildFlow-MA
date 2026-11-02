// Clients and responses shared by the Edge Functions.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const noSession = { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false };

/** Service role: bypasses RLS, calls the service-only RPCs and the Auth admin API. */
export function adminClient(): SupabaseClient {
  return createClient(url, serviceKey, { auth: noSession });
}

/** As an app user: anonymous until it signs in. */
export function anonClient(): SupabaseClient {
  return createClient(url, anonKey, { auth: noSession });
}

/**
 * Error bodies follow docs/api-contract.md: `error` is for logs, the client
 * decides by the status and `hint`.
 */
export function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

export function error(status: number, message: string, hint?: string): Response {
  return json(status, hint ? { error: message, hint } : { error: message });
}

export async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  try {
    const body = await req.json();
    return body && typeof body === 'object' && !Array.isArray(body) ? body : null;
  } catch {
    return null;
  }
}
