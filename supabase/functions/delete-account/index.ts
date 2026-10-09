// Admin credentials exist only in the Edge runtime. The caller cannot select a user ID.
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), {
  status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return reply(405, { error: 'Method not allowed' });
  const url = Deno.env.get('SUPABASE_URL');
  const adminKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const publicKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!url || !adminKey || !publicKey) return reply(503, { error: 'Service unavailable' });
  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return reply(401, { error: 'Authentication required' });
  try {
    if (Number(req.headers.get('content-length') ?? 0) > 8192) return reply(400, { error: 'Invalid request' });
    const text = await req.text();
    if (text.length > 8192) return reply(400, { error: 'Invalid request' });
    let body;
    try { body = JSON.parse(text); } catch { return reply(400, { error: 'Invalid request' }); }
    if (body?.confirmation !== 'DELETE' || typeof body.password !== 'string' ||
        body.password.length === 0 || body.password.length > 4096 || 'user_id' in body) {
      return reply(400, { error: 'Password and confirmation required' });
    }
    const identity = await fetch(`${url}/auth/v1/user`, {
      headers: { apikey: publicKey, Authorization: authorization },
    });
    if (!identity.ok) return reply(401, { error: 'Invalid session' });
    const user = await identity.json();
    if (!user.id || !user.email) return reply(401, { error: 'Invalid session' });

    // Require the current password, and compare server identities before privileged work.
    const verification = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: 'POST', headers: { apikey: publicKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: user.email, password: body.password }),
    });
    if (!verification.ok) return reply(403, { error: 'Incorrect password' });
    const verified = await verification.json();
    if (verified.user?.id !== user.id || !verified.access_token) return reply(403, { error: 'Identity mismatch' });
    const adminHeaders = { apikey: adminKey, Authorization: `Bearer ${adminKey}`, 'Content-Type': 'application/json' };

    // Auth refuses to delete users that still own Storage objects. Remove only this user's flat media folder.
    for (;;) {
      const list = await fetch(`${url}/storage/v1/object/list/chat-media`, {
        method: 'POST', headers: adminHeaders,
        body: JSON.stringify({ prefix: `${user.id}/`, limit: 100, offset: 0 }),
      });
      if (!list.ok) return reply(503, { error: 'Could not inspect owned files' });
      const files = await list.json();
      if (!Array.isArray(files)) return reply(503, { error: 'Invalid storage response' });
      if (files.length === 0) break;
      if (files.some((file) => !file.id || typeof file.name !== 'string' || file.name.includes('/'))) {
        return reply(409, { error: 'Storage cleanup requires support' });
      }
      const removal = await fetch(`${url}/storage/v1/object/chat-media`, {
        method: 'DELETE', headers: adminHeaders,
        body: JSON.stringify({ prefixes: files.map((file) => `${user.id}/${file.name}`) }),
      });
      if (!removal.ok) return reply(503, { error: 'Could not remove owned files' });
    }
    const logout = await fetch(`${url}/auth/v1/logout?scope=global`, {
      method: 'POST', headers: { apikey: publicKey, Authorization: `Bearer ${verified.access_token}` },
    });
    if (!logout.ok) return reply(503, { error: 'Could not revoke sessions' });
    const deletion = await fetch(`${url}/auth/v1/admin/users/${encodeURIComponent(user.id)}`, {
      method: 'DELETE', headers: adminHeaders,
    });
    if (!deletion.ok) return reply(503, { error: 'Could not delete account' });
    return reply(200, { deleted: true });
  } catch {
    return reply(503, { error: 'Service unavailable' });
  }
});
