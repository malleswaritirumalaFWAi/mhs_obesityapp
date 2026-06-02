import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';

import authRoutes from './routes/auth.js';
import apiRoutes from './routes/api.js';
import mealRoutes from './routes/meals.js';
import paymentRoutes from './routes/payments.js';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '12mb' })); // base64 meal photos

app.get('/health', (_req, res) => res.json({ ok: true, service: 'fitquest', ts: Date.now() }));

app.use('/auth', authRoutes);
app.use('/meals', mealRoutes);
app.use('/payments', paymentRoutes);
app.use('/', apiRoutes);

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ message: err.message || 'Server error' });
});

const port = process.env.PORT || 4000;
app.listen(port, () => console.log(`🚀 FitQuest API on http://localhost:${port}`));
