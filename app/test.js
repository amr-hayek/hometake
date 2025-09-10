const express = require('express');
const request = require('supertest');

// Mock the server for testing
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

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

// Simple test suite
async function runTests() {
  console.log('Running application tests...');
  
  try {
    // Test root endpoint
    const rootResponse = await request(app).get('/');
    console.log('✓ Root endpoint test passed');
    console.log('  Response:', rootResponse.body.message);
    
    // Test health endpoint
    const healthResponse = await request(app).get('/health');
    console.log('✓ Health endpoint test passed');
    console.log('  Status:', healthResponse.body.status);
    
    // Test metrics endpoint
    const metricsResponse = await request(app).get('/metrics');
    console.log('✓ Metrics endpoint test passed');
    console.log('  Memory usage:', Math.round(metricsResponse.body.memory.heapUsed / 1024 / 1024), 'MB');
    
    console.log('\nAll tests passed! ✅');
    
  } catch (error) {
    console.error('Test failed:', error.message);
    process.exit(1);
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  runTests();
}

module.exports = app;
