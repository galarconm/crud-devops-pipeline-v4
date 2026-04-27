const express = require('express');
const { Pool } = require('pg');
const client = require('prom-client');

const app = express();
app.use(express.json());

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// ── Métricas ────────────────────────────────────────────────────────────────

// Registry propio para evitar conflictos
const register = new client.Registry();

// Métricas default: CPU, memoria, event loop
client.collectDefaultMetrics({ register });

// Métrica de TRÁFICO y ERRORES: cuenta cada request
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total de requests HTTP recibidos',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});

// Métrica de LATENCIA: mide cuánto tarda cada request
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duracion de requests HTTP en segundos',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5],
  registers: [register]
});

// Middleware: se ejecuta en cada request automáticamente
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    httpRequestsTotal.inc({
      method: req.method,
      route: req.path,
      status: res.statusCode
    });
    end({
      method: req.method,
      route: req.path,
      status: res.statusCode
    });
  });
  next();
});

// ── Endpoints ───────────────────────────────────────────────────────────────

// Health check
app.get('/healthz', (req, res) => res.json({ status: 'ok' }));

// Endpoint de métricas para Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Get all users
app.get('/users', async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM users');
  res.json(rows);
});

// Create a new user
app.post('/users', async (req, res) => {
  const { name } = req.body;
  const { rows } = await pool.query(
    'INSERT INTO users(name) VALUES($1) RETURNING *', [name]
  );
  res.json(rows[0]);
});

app.listen(3000, () => console.log('Backend running on port 3000'));

module.exports = app;
