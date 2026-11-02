// POST /functions/v1/join — POST /auth/join of docs/api-contract.md.
//
// Body: { email, password, name, inviteCode }; header X-Device-Id.
// 201 { session, user, company } · 400 · 404 code unknown, used or expired ·
// 409 email taken · 429 too many attempts (Retry-After: 60).
//
// The code is spent by the registration trigger in the transaction that
// creates the user: GoTrue checks the email first, so a taken email leaves the
// code unspent, and a code that doesn't fit rejects the user (supabase-plan.md).
import { adminClient, anonClient, error, json, readJson } from '../_shared/supabase.ts';

function normalizeInviteCode(code: string): string {
  return code.toUpperCase().replace(/[\s-]/g, '');
}

// The client can send any X-Forwarded-For; proxies append to it, so the
// last entry is the one our gateway saw (Kong locally). Cloudflare in front
// of the hosted project sets cf-connecting-ip. Check which header carries the
// real address on the hosted project before the pilot (supabase-plan.md).
function clientIp(req: Request): string | null {
  const cloudflare = req.headers.get('cf-connecting-ip')?.trim();
  if (cloudflare) return cloudflare;
  const forwarded = req.headers.get('x-forwarded-for')?.split(',').map((s) => s.trim()).filter(Boolean);
  return forwarded?.at(-1) ?? null;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return error(405, 'Method not allowed');

  const body = await readJson(req);
  const email = text(body?.email).toLowerCase();
  const password = typeof body?.password === 'string' ? body.password : '';
  const name = text(body?.name);
  const inviteCode = normalizeInviteCode(text(body?.inviteCode));
  if (!email || !password || !name || !inviteCode) {
    return error(400, 'email, password, name and inviteCode are required', 'validation');
  }

  const admin = adminClient();

  // Every request counts, before anything else is checked.
  const ip = clientIp(req);
  const deviceId = req.headers.get('x-device-id')?.trim().slice(0, 200) || null;
  const { data: allowed, error: limitError } = await admin.rpc('join_rate_limit', {
    p_ip: ip,
    p_device_id: deviceId,
  });
  if (limitError) return error(500, limitError.message);
  if (!allowed) return json(429, { error: 'Too many attempts', hint: 'too_many_requests' }, { 'Retry-After': '60' });

  const { error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { name },
    // App metadata: users can't set it themselves, so only this function
    // can spend a code.
    app_metadata: { invite_code: inviteCode },
  });
  if (createError) {
    if (createError.code === 'email_exists' || createError.code === 'user_already_exists') {
      return error(409, 'Email already registered', 'email_taken');
    }
    if (createError.code === 'weak_password' || createError.code === 'validation_failed') {
      return error(400, createError.message, 'validation');
    }
    // The trigger rejected the code, or something else failed.
    const { data: redeemable } = await admin.rpc('invite_is_redeemable', { p_code: inviteCode });
    if (redeemable === false) {
      return error(404, 'Invite code unknown, used or expired', 'invalid_invite_code');
    }
    return error(500, createError.message);
  }

  const client = anonClient();
  const { data: signIn, error: signInError } = await client.auth.signInWithPassword({ email, password });
  if (signInError || !signIn.session) return error(500, signInError?.message ?? 'No session');

  const { data: me, error: meError } = await client.rpc('get_me');
  if (meError) return error(500, meError.message);

  const { access_token, refresh_token, expires_at, expires_in, token_type } = signIn.session;
  return json(201, {
    session: { access_token, refresh_token, expires_at, expires_in, token_type },
    user: me.user,
    company: me.company,
  });
});
