import { Router } from 'express'
import { createCustomer, getAllCustomers, getCustomerById, updateCustomer, deleteCustomer } from '../controllers/customersController'

const router = Router()

// Public routes
router.get('/customers', getAllCustomers)
router.post('/customers', createCustomer)
router.get('/customers/:id', getCustomerById)
router.put('/customers/:id', updateCustomer)
router.delete('/customers/:id', deleteCustomer)

export default router