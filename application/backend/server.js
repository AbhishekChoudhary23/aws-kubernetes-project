const express = require('express');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 5000;

// Enable Prometheus default metrics collection
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ register: client.register });

// Track HTTP requests by method, route, and status code
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests handled',
  labelNames: ['method', 'route', 'status']
});

const ALLOWED_STATUS_CODES = new Set([200, 201, 204, 400, 401, 403, 404, 429, 500, 502, 503, 504]);

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || '*');
  next();
});

// Kubernetes Liveness and Readiness Probes
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/readyz', (req, res) => {
  res.status(200).json({ status: 'ready', timestamp: new Date().toISOString() });
});

// Dynamic status code engine driven by UI input
app.get('/api/status/:code', (req, res) => {
  const statusCode = parseInt(req.params.code, 10);

  if (Number.isNaN(statusCode) || !ALLOWED_STATUS_CODES.has(statusCode)) {
    httpRequestCounter.inc({ method: 'GET', route: '/api/status', status: '400' });
    return res.status(400).json({
      error: 'Bad Request',
      message: 'Unsupported or invalid HTTP status code requested.'
    });
  }

  // Track bounded status code metric
  httpRequestCounter.inc({ method: 'GET', route: '/api/status', status: statusCode.toString() });

  if (statusCode >= 500) {
    console.error(`[ERROR] ${new Date().toISOString()} - Simulated internal exception thrown for status ${statusCode}`);
    return res.status(statusCode).json({
      error: 'Internal Server Error',
      message: `Simulated backend breakdown (${statusCode})`
    });
  }

  if (statusCode >= 400) {
    console.warn(`[WARN] ${new Date().toISOString()} - Client validation warning triggered for status ${statusCode}`);
    return res.status(statusCode).json({
      error: 'Client Error',
      message: `Simulated client side violation (${statusCode})`
    });
  }

  return res.status(statusCode).json({
    status: 'success',
    message: `Execution completed with status ${statusCode}.`
  });
});

// Prometheus Metrics Scraping Endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.setHeader('Content-Type', client.register.contentType);
    res.send(await client.register.metrics());
  } catch (err) {
    res.status(500).json({ error: 'Failed to collect metrics' });
  }
});

const server = app.listen(port, () => {
  console.log(`Backend listening at http://0.0.0.0:${port}`);
});

// Graceful shutdown for Kubernetes SIGTERM
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});
