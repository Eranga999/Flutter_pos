import { Router } from 'express'
import { createOrder, getAllOrders, getOrderById, updateStock } from '../controllers/orderController'

const router = Router()

// Public routes
router.get('/order', getAllOrders)
router.post('/order', createOrder)
router.get('/order/:id', getOrderById)
router.post('/order/update-stock', updateStock)

export default router