const express = require('express');
const client = require('prom-client');

const app = express();
const port = 5000;

// Enable Prometheus default metrics collection
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ register: client.register });

// Track HTTP requests by method, route, and status code
const httpRequestsCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests handled',
  labelNames: ['method', 'route', 'status']
});

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  next();
});

// Dynamic status code engine driven by UI input
app.get('/api/status/:code', (req, res) => {
  const statusCode = parseInt(req.params.code, 10);
  
  // Track metrics first
  httpRequestsCounter.inc({ method: 'GET', route: '/api/status', status: statusCode.toString() });

  // Generate systemic server-side logs based on the error classification
  if (statusCode >= 500) {
    console.error(`[ERROR] ${new Date().toISOString()} - Simulated internal exception thrown for status ${statusCode}`);
    return res.status(statusCode).json({ error: "Internal Server Error", message: `Simulated backend breakdown (${statusCode}).` });
  } 
  
  if (statusCode >= 400) {
    console.warn(`[WARN] ${new Date().toISOString()} - Client validation warning triggered for status ${statusCode}`);
    return res.status(statusCode).json({ error: "Bad Request", message: `Simulated client side violation (${statusCode}).` });
  }

  // Fallback default Success (200)
  res.json({ status: "success", message: `Execution completed with status ${statusCode}.` });
});

// Prometheus Metrics Scraping Endpoint
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', client.register.contentType);
  res.send(await client.register.metrics());
});

app.listen(port, () => {
  console.log(`Backend listening at http://localhost:${port}`);
});