// End-to-end check of the Edge Functions over HTTP against the local stack:
//   npx supabase@2.122.0 start
//   node supabase/tests/edge/smoke.mjs
// Creates its own users with unique emails, so it can run any number of
// times. Exits with 1 if a check fails.

// The local stack's well-known anon key (the same for every `supabase start`).
const url = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
const anonKey = process.env.SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

const run = Date.now().toString(36);
let failed = 0;
let passed = 0;

function check(name, condition, details) {
  if (condition) {
    passed++;
    console.log(`ok   ${name}`);
  } else {
    failed++;
    console.log(`FAIL ${name}${details === undefined ? '' : `\n     ${JSON.stringify(details)}`}`);
  }
}

async function call(path, { method = 'POST', token, body, headers = {} } = {}) {
  const res = await fetch(`${url}${path}`, {
    method,
    headers: {
      apikey: anonKey,
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: res.status, data, headers: res.headers };
}

const rpc = (name, token, args = {}) => call(`/rest/v1/rpc/${name}`, { token, body: args });
const joinOnce = (body, headers) => call('/functions/v1/join', { body, headers });

// Locally every request comes from one IP, so a run right after another one
// can hit the limit of 10 joins a minute: wait it out once.
async function join(body, headers) {
  const res = await joinOnce(body, headers);
  if (res.status !== 429) return res;
  console.log('     (join limit reached by an earlier run, waiting a minute)');
  await new Promise((resolve) => setTimeout(resolve, 61_000));
  return joinOnce(body, headers);
}
const removeMember = (token, memberId) => call('/functions/v1/remove-member', { token, body: { memberId } });

async function signUpOwner(email) {
  const res = await call('/auth/v1/signup', {
    body: { email, password: '123456', data: { name: 'Директор', company_name: `Смоук ${run}` } },
  });
  return res.data?.access_token;
}

async function invite(ownerToken, role) {
  const res = await rpc('create_invite', ownerToken, { p_role: role });
  return res.data.code;
}

// ── Join ─────────────────────────────────────────────────────

const ownerToken = await signUpOwner(`owner-${run}@smoke.kg`);
check('owner signs up', !!ownerToken);

const code = await invite(ownerToken, 'worker');
const joinBody = (email, inviteCode) => ({ email, password: '123456', name: 'Новый Строитель', inviteCode });

const joined = await join(joinBody(`worker-${run}@smoke.kg`, `${code.slice(0, 3).toLowerCase()}-${code.slice(3)}`));
check('join with a code typed in lower case with a dash: 201', joined.status === 201, joined);
check('join returns a session, the user as a worker and the company',
  !!joined.data?.session?.access_token && joined.data?.user?.role === 'worker' &&
    joined.data?.company?.name === `Смоук ${run}`, joined.data);

const reused = await join(joinBody(`worker2-${run}@smoke.kg`, code));
check('a used code: 404 invalid_invite_code', reused.status === 404 && reused.data?.hint === 'invalid_invite_code', reused);

const unknown = await join(joinBody(`worker3-${run}@smoke.kg`, 'ZZZZZZ'));
check('an unknown code: 404', unknown.status === 404 && unknown.data?.hint === 'invalid_invite_code', unknown);

const code2 = await invite(ownerToken, 'foreman');
const taken = await join(joinBody(`worker-${run}@smoke.kg`, code2));
check('a taken email: 409 email_taken', taken.status === 409 && taken.data?.hint === 'email_taken', taken);
const afterTaken = await join(joinBody(`foreman-${run}@smoke.kg`, code2));
check('the code survives a taken email and works with another one',
  afterTaken.status === 201 && afterTaken.data?.user?.role === 'foreman', afterTaken);

const incomplete = await join({ email: `x-${run}@smoke.kg`, inviteCode: code2 });
check('missing fields: 400', incomplete.status === 400, incomplete);

// Locally the IP and the device limits both allow 10 a minute; the joins
// above already count. Per-device and per-IP counting is covered by pgTAP.
const device = { 'X-Device-Id': `smoke-device-${run}` };
const statuses = [];
let limited;
for (let i = 0; i < 12; i++) {
  const res = await joinOnce(joinBody(`flood-${i}-${run}@smoke.kg`, 'ZZZZZZ'), device);
  statuses.push(res.status);
  if (res.status === 429) {
    limited = res;
    break;
  }
}
check('too many attempts: 429 with Retry-After: 60, the rest were 404',
  limited?.headers.get('retry-after') === '60' && statuses.slice(0, -1).every((s) => s === 404), statuses);

const spoofed = await joinOnce(joinBody(`spoof-${run}@smoke.kg`, 'ZZZZZZ'), {
  'X-Forwarded-For': `10.${Math.floor(Math.random() * 250)}.0.1`,
  'X-Device-Id': `another-device-${run}`,
});
check('a made-up X-Forwarded-For and device id do not reset the limit', spoofed.status === 429, spoofed);

// ── Storage and reports ──────────────────────────────────────

const worker = joined.data.user;
const workerSession = joined.data.session;
const foremanToken = afterTaken.data.session.access_token;
const foremanId = afterTaken.data.user.id;

async function storage(path, { method = 'POST', token, body, contentType } = {}) {
  const res = await fetch(`${url}/storage/v1/${path}`, {
    method,
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${token}`,
      ...(contentType ? { 'Content-Type': contentType } : {}),
    },
    body,
  });
  const text = await res.text();
  let data = text;
  try {
    data = JSON.parse(text);
  } catch {
    // binary or empty
  }
  return { status: res.status, data, text };
}

const project = (await rpc('create_project', ownerToken, { p_name: `Объект ${run}` })).data;
await rpc('update_project', ownerToken, { p_id: project.id, p_foreman_ids: [foremanId] });

const jpeg = Buffer.from(`ffd8ffe000104a46494600010100000100010000ffd9${'00'.repeat(64)}`, 'hex');
const upload = (await rpc('create_upload', foremanToken, {
  p_content_type: 'image/jpeg', p_bytes: jpeg.length, p_width: 1600, p_height: 1200,
})).data;
check('create_upload returns where to upload', upload?.bucket === 'photos' && !!upload?.path, upload);

const objectPath = `${upload.bucket}/${upload.path}`;
const byOther = await storage(`object/${objectPath}`, { token: ownerToken, body: jpeg, contentType: 'image/jpeg' });
check('nobody else can upload to that path', byOther.status >= 400, byOther);

const uploaded = await storage(`object/${objectPath}`, { token: foremanToken, body: jpeg, contentType: 'image/jpeg' });
check('the foreman uploads the photo straight to Storage', uploaded.status === 200, uploaded);

const overwrite = await storage(`object/${objectPath}`, {
  method: 'PUT', token: foremanToken, body: jpeg, contentType: 'image/jpeg',
});
check('an uploaded file cannot be replaced', overwrite.status >= 400, overwrite);

const gif = (await rpc('create_upload', foremanToken, {
  p_content_type: 'image/jpeg', p_bytes: 10, p_width: 1, p_height: 1,
})).data;
const wrongType = await storage(`object/${gif.bucket}/${gif.path}`, {
  token: foremanToken, body: Buffer.from('GIF89a'), contentType: 'image/gif',
});
check('the bucket refuses a type it does not allow', wrongType.status >= 400, wrongType);

const report = await rpc('submit_report', foremanToken, {
  p_project_id: project.id,
  p_text: 'Смоук',
  p_photos: [{ attachmentId: upload.attachmentId, takenAt: '2026-11-02T08:12:40Z' }],
});
check('the foreman submits a report with the uploaded photo',
  report.status === 200 && report.data?.photos?.[0]?.path === upload.path, report);

const signed = await storage(`object/sign/${objectPath}`, {
  token: ownerToken, body: JSON.stringify({ expiresIn: 3600 }), contentType: 'application/json',
});
const download = signed.data?.signedURL ? await fetch(`${url}/storage/v1${signed.data.signedURL}`) : null;
const downloaded = download ? Buffer.from(await download.arrayBuffer()) : null;
check('the owner gets a signed link to the photo and downloads it',
  download?.status === 200 && downloaded?.equals(jpeg), signed);

const notVisible = await storage(`object/sign/${objectPath}`, {
  token: workerSession.access_token, body: JSON.stringify({ expiresIn: 3600 }), contentType: 'application/json',
});
check('a worker not on the project gets no link', notVisible.status >= 400, notVisible);

// ── Realtime ─────────────────────────────────────────────────

// Joins the private channel `user:<userId>` over the Realtime websocket
// (Phoenix protocol). Resolves with the join status and collects broadcasts.
function listen(token, userId) {
  const ws = new WebSocket(`${url.replace(/^http/, 'ws')}/realtime/v1/websocket?apikey=${anonKey}&vsn=1.0.0`);
  const events = [];
  const joined = new Promise((resolve) => {
    ws.addEventListener('open', () => {
      ws.send(JSON.stringify({
        topic: `realtime:user:${userId}`,
        event: 'phx_join',
        payload: { config: { broadcast: { self: false }, presence: { key: '' }, private: true }, access_token: token },
        ref: '1',
        join_ref: '1',
      }));
    });
    ws.addEventListener('message', (e) => {
      const frame = JSON.parse(e.data);
      if (frame.event === 'phx_reply' && frame.ref === '1') resolve(frame.payload.status);
      if (frame.event === 'system' && frame.payload?.status === 'error') resolve('error');
      if (frame.event === 'broadcast') events.push(frame.payload);
    });
    ws.addEventListener('error', () => resolve('error'));
    setTimeout(() => resolve('timeout'), 5000);
  });
  return { joined, events, close: () => ws.close() };
}

async function waitFor(predicate, ms = 5000) {
  for (let waited = 0; waited < ms; waited += 100) {
    if (predicate()) return true;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return predicate();
}

const ownerId = (await rpc('get_me', ownerToken)).data.user.id;
const ownerListener = listen(ownerToken, ownerId);
check('the owner joins the own private channel', (await ownerListener.joined) === 'ok');

const spy = listen(workerSession.access_token, ownerId);
check('a worker cannot join the owner\'s channel', (await spy.joined) !== 'ok');
spy.close();

const projectChat = (await rpc('get_chats', foremanToken)).data.find((c) => c.projectId === project.id);
const sent = await rpc('send_message', foremanToken, {
  p_chat_id: projectChat.id, p_client_id: crypto.randomUUID(), p_kind: 'text', p_text: 'Бетон привезли',
});
const delivered = await waitFor(() => ownerListener.events.some(
  (e) => e.event === 'message.created' && e.payload?.message?.id === sent.data?.id,
));
check('a message reaches the owner over Realtime as message.created', delivered, ownerListener.events.map((e) => e.event));
ownerListener.close();

// ── Remove member ────────────────────────────────────────────

const byForeman = await removeMember(foremanToken, worker.id);
check('a foreman cannot remove members: 403', byForeman.status === 403, byForeman);

const removed = await removeMember(ownerToken, worker.id);
check('the owner removes the worker: 204', removed.status === 204, removed);

const again = await removeMember(ownerToken, worker.id);
check('removing again: 404', again.status === 404, again);

const self = await removeMember(ownerToken, ownerId);
check('removing yourself: 400', self.status === 400, self);

const oldToken = await rpc('get_me', workerSession.access_token);
check('the still valid access token gets 403 account_removed',
  oldToken.status === 403 && oldToken.data?.hint === 'account_removed', oldToken);

const refresh = await call('/auth/v1/token?grant_type=refresh_token', {
  body: { refresh_token: workerSession.refresh_token },
});
check('the session cannot be refreshed: signed out on every device', refresh.status >= 400, refresh);

const login = await call('/auth/v1/token?grant_type=password', {
  body: { email: `worker-${run}@smoke.kg`, password: '123456' },
});
check('the removed member cannot sign in', login.status >= 400 && !login.data?.access_token, login);

const noToken = await call('/functions/v1/remove-member', { body: { memberId: worker.id } });
check('remove-member without a token: 401', noToken.status === 401, noToken);

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
