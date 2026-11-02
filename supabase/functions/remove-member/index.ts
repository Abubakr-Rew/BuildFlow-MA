// POST /functions/v1/remove-member — DELETE /team/members/:id of
// docs/api-contract.md. Called with the owner's token.
//
// Body: { memberId }. 204 · 400 removing yourself · 403 not an owner ·
// 404 not in the company or already removed.
//
// The database part (projects, chats, system messages, removed_at) is one
// transaction in RPC remove_member; then the user is banned in Auth. A
// banned user can neither sign in nor refresh a session, so every device is
// signed out once its access token (15 minutes) expires. Auth has no admin
// call to end the sessions of a user by id: admin.signOut() takes the user's
// own token.
import { adminClient, error, readJson } from '../_shared/supabase.ts';

// ~100 years: Auth takes a duration, not "forever".
const banDuration = '876000h';

Deno.serve(async (req) => {
  if (req.method !== 'POST') return error(405, 'Method not allowed');

  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
  const admin = adminClient();
  const { data: caller, error: callerError } = await admin.auth.getUser(token);
  if (callerError || !caller.user) return error(401, 'Session expired', 'not_authenticated');

  const body = await readJson(req);
  const memberId = typeof body?.memberId === 'string' ? body.memberId : '';
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(memberId)) {
    return error(400, 'memberId must be a uuid', 'validation');
  }

  const { data: outcome, error: removeError, status } = await admin.rpc('remove_member', {
    p_actor_id: caller.user.id,
    p_member_id: memberId,
  });
  if (removeError) return error(status || 500, removeError.message, removeError.hint ?? undefined);

  // Also after 'already_removed': a retry after a failed ban bans again.
  const { error: banError } = await admin.auth.admin.updateUserById(memberId, {
    ban_duration: banDuration,
  });
  if (banError) return error(500, `Removed, but the ban failed: ${banError.message}`);

  if (outcome === 'already_removed') return error(404, 'Member already removed', 'not_found');
  return new Response(null, { status: 204 });
});
