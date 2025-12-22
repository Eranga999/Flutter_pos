import './setupEnv';
import express, { Express } from 'express';
import cors from 'cors';
import { connectDB } from './config/mongodb';
import { errorHandler } from './middleware/errorHandler';

// Routes
import authRoutes from './routes/auth';
import productRoutes from './routes/products';
import categoryRoutes from './routes/categories';
import customerRoutes from './routes/customers';
import orderRoutes from './routes/orders';
import discountRoutes from './routes/discounts';
import supplierRoutes from './routes/suppliers';
import staffRoutes from './routes/staff';

const app: Express = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Initialize Database
const startServer = async () => {
  try {
    // Connect to MongoDB
    await connectDB();

    // Routes
    app.use('/api/auth', authRoutes);
    app.use('/api/products', productRoutes);
    app.use('/api/categories', categoryRoutes);
    app.use('/api/customers', customerRoutes);
    app.use('/api/orders', orderRoutes);
    app.use('/api/discounts', discountRoutes);
    app.use('/api/suppliers', supplierRoutes);
    app.use('/api/staff', staffRoutes);

    // Health check endpoint
    app.get('/api/health', (req, res) => {
      res.status(200).json({ 
        status: 'API is running',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
      });
    });

    // 404 handler
    app.use((req, res) => {
      res.status(404).json({ message: 'Route not found' });
    });

    // Error handler
    app.use(errorHandler);

    // Start server
    app.listen(PORT, () => {
      console.log([
        '--------------------------------------------------',
        'ZORS POS API Server Started Successfully',
        `Server: http://localhost:${PORT}`,
        `API Base URL: http://localhost:${PORT}/api`,
        `Environment: ${process.env.NODE_ENV || 'development'}`,
        'Database: Connected (ok)',
        '--------------------------------------------------',
      ].join('\n'));
    });

    // Handle graceful shutdown
    process.on('SIGINT', () => {
      console.log('\n\n🛑 Shutting down gracefully...');
      process.exit(0);
    });

  } catch (error) {
    console.error('✗ Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
