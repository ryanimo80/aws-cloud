const express = require('express');
const app = express();
const port = 8000;
const hostname = '0.0.0.0';

app.get('/', (req, res) => {
  res.send('Hello from Node.js on EC2 using CodeDeploy! 🚀');
});

app.listen(port, hostname, () => {
  console.log(`App is running on http://${hostname}:${port}`);
});