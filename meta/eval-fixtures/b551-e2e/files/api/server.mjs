// In-memory order API for the shop. `GET /health` for readiness, `POST /api/orders` creates an order.
import { createServer } from 'node:http';

const orders = new Map();
let nextId = 1;

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

const server = createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    return send(res, 200, { status: 'ok' });
  }
  if (req.method === 'POST' && req.url === '/api/orders') {
    let raw = '';
    req.on('data', (chunk) => (raw += chunk));
    req.on('end', () => {
      try {
        const order = JSON.parse(raw);
        const id = nextId++;
        orders.set(id, order);
        send(res, 201, { id });
      } catch {
        send(res, 400, { error: 'invalid JSON' });
      }
    });
    return;
  }
  send(res, 404, { error: 'not found' });
});

server.listen(4301, () => console.log('API listening on http://localhost:4301'));
