import { Router } from 'express'
import { createDiscount, getAllDiscounts, updateDiscount, deleteDiscount } from '../controllers/discountsController'

const router = Router()

// Public routes
router.get('/discounts', getAllDiscounts)
router.post('/discounts', createDiscount)
router.put('/discounts/:id', updateDiscount)
router.delete('/discounts/:id', deleteDiscount)

export default router