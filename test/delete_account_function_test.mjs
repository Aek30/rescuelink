import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { test } from 'node:test';

const source = stripTypeScriptTypes(readFileSync(new URL('../supabase/functions/delete-account/index.ts', import.meta.url), 'utf8'));
function fixture({ wrongPassword = false, mismatch = false, invalidJwt = false, revokeFailure = false, media = false } = {}) {
  let handler;
  let listed = 0;
  const calls = [];
  const json = (data, status = 200) => new Response(JSON.stringify(data), { status });
  vm.runInNewContext(source, {
    Request, Response, JSON, encodeURIComponent,
    Deno: { env: { get: (key) => ({ SUPABASE_URL: 'https://test.invalid', SUPABASE_ANON_KEY: 'public', SUPABASE_SERVICE_ROLE_KEY: 'admin' })[key] }, serve: (value) => { handler = value; } },
    fetch: async (url, options = {}) => {
      calls.push({ url, options });
      if (url.endsWith('/auth/v1/user')) return json({ id: 'owner-A', email: 'a@example.com' }, invalidJwt ? 401 : 200);
      if (url.includes('grant_type=password')) return json({ user: { id: mismatch ? 'owner-B' : 'owner-A' }, access_token: 'verified' }, wrongPassword ? 400 : 200);
      if (url.includes('/object/list/')) return json(media && listed++ === 0 ? [{ id: 'file-id', name: 'media-id' }] : []);
      if (url.includes('/object/chat-media')) return json([]);
      if (url.includes('/logout')) return new Response(null, { status: revokeFailure ? 500 : 204 });
      if (url.includes('/admin/users/')) return json({});
      throw Error('Unexpected request');
    },
  });
  const request = (body = { password: 'test-password', confirmation: 'DELETE' }, auth = true, method = 'POST') =>
    new Request('https://test.invalid/functions/v1/delete-account', {
      method, headers: auth ? { Authorization: 'Bearer test-user-token' } : {},
      ...(method === 'POST' ? { body: JSON.stringify(body) } : {}),
    });
  return { handler, calls, request };
}

test('CORS preflight does not access any data', async () => {
  const f = fixture();
  const result = await f.handler(f.request({}, false, 'OPTIONS'));
  assert.equal(result.status, 204);
  assert.equal(result.headers.get('Access-Control-Allow-Origin'), '*');
  assert.equal(f.calls.length, 0);
});
test('missing auth and missing confirmation fail before data access', async () => {
  const f = fixture();
  assert.equal((await f.handler(f.request({}, false))).status, 401);
  assert.equal((await f.handler(f.request({ password: 'test-password' }))).status, 400);
  assert.equal(f.calls.length, 0);
});
test('caller cannot provide a different target account', async () => {
  const f = fixture();
  assert.equal((await f.handler(f.request({ password: 'test-password', confirmation: 'DELETE', user_id: 'owner-B' }))).status, 400);
  assert.equal(f.calls.length, 0);
});
for (const [label, options, status] of [
  ['invalid JWT', { invalidJwt: true }, 401],
  ['wrong password', { wrongPassword: true }, 403],
  ['mismatched identity', { mismatch: true }, 403],
]) test(`${label} never performs privileged writes`, async () => {
  const f = fixture(options);
  assert.equal((await f.handler(f.request())).status, status);
  assert.ok(f.calls.every((call) => !call.url.includes('/storage/') && !call.url.includes('/admin/')));
});
test('failed session revocation prevents Auth deletion', async () => {
  const f = fixture({ revokeFailure: true });
  assert.equal((await f.handler(f.request())).status, 503);
  assert.ok(f.calls.every((call) => !call.url.includes('/admin/users/')));
});
test('successful deletion removes only owned media then revokes sessions and deletes verified owner', async () => {
  const f = fixture({ media: true });
  const result = await f.handler(f.request());
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { deleted: true });
  const removal = f.calls.find((call) => call.url.includes('/object/chat-media'));
  assert.deepEqual(JSON.parse(removal.options.body), { prefixes: ['owner-A/media-id'] });
  assert.ok(f.calls.at(-1).url.endsWith('/admin/users/owner-A'));
  assert.ok(f.calls.at(-2).url.includes('/logout?scope=global'));
});
