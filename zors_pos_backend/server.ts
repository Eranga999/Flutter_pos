import express from 'express'
import cors from 'cors'
import connectDB from './utils/db'
import authRoutes from './routes/authRoutes'
import categoryRoutes from './routes/categoryRoutes'
import customersRoutes from './routes/customersRoutes'
import discountRoutes from './routes/discountRoutes'
import orderRoutes from './routes/orderRoutes'
import productRoutes from './routes/productRoutes'
import reportRoutes from './routes/reportRoutes'
import returnRoutes from './routes/returnRoutes'
import staffRoutes from './routes/staffRoutes'
import stocktransitionRoutes from './routes/stocktransitionRoutes'
import suppliersRoutes from './routes/suppliersRoutes'

export const api = express()

// Connect to MongoDB
connectDB()

// Configure CORS to allow Vite dev server
api.use(
  cors({
    origin: '*',
    credentials: true
  })
)

api.use(express.json())

// Add logging middleware
api.use((req, _, next) => {
  console.log(`📥 ${req.method} ${req.url}`)
  next()
})

// Test route
api.get('/api/hello', (_, res) => {
  console.log('✅ Sending hello response')
  res.json({ message: 'Hello from the backend!' })
})

// API routes
api.use('/api/auth', authRoutes)
api.use('/api', categoryRoutes)
api.use('/api', customersRoutes)
api.use('/api', discountRoutes)
api.use('/api', orderRoutes)
api.use('/api', productRoutes)
api.use('/api', reportRoutes)
api.use('/api', returnRoutes)
api.use('/api', staffRoutes)
api.use('/api', stocktransitionRoutes)
api.use('/api', suppliersRoutes)

// Error handling middleware
api.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('❌ Error:', err)
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error'
  })
})

// Start the server
const PORT = process.env.PORT || 5000
api.listen(PORT, () => {
  console.log(`🚀 Server is running on http://localhost:${PORT}`)
})