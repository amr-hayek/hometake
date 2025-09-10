const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Routes
app.get('/', (req, res) => {
  const response = {
    message: 'Hello from Docker on EC2!',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'production',
    secret: process.env.APP_SECRET ? 'configured' : 'not configured',
    version: process.env.APP_VERSION || '1.0.0'
  };
  res.json(response);
});

app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/metrics', (req, res) => {
  const metrics = {
    memory: process.memoryUsage(),
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  };
  res.json(metrics);
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`App listening on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'production'}`);
  console.log(`Secret configured: ${process.env.APP_SECRET ? 'Yes' : 'No'}`);
});
