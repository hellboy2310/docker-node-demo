const express = require('express');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(morgan('tiny'));

app.get('/', (req, res) => {
  res.json({ message: 'App is perfectly running' });
});


app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
