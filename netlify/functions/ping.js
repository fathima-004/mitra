// Health check. Open /.netlify/functions/ping after a deploy to confirm functions are live.
exports.handler = async () => ({
  statusCode: 200,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ ok: true, time: new Date().toISOString() }),
});
