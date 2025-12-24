import { Router } from 'express'
import { getAllCategories, createCategory, updateCategory, deleteCategory } from '../controllers/categoriesController'

const router = Router()

// Public routes
router.get('/categories', getAllCategories)
router.post('/categories', createCategory)
router.put('/categories/:id', updateCategory)
router.delete('/categories/:id', deleteCategory)

export default router