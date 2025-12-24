import { Router } from 'express'
import { registerUser, loginUser, changePassword } from '../controllers/authController'
import { authMiddleware } from '../middleware/authMiddleware'

const router = Router()

// Public routes
router.post('/register', registerUser)
router.post('/login', loginUser)

// Protected routes
router.post('/change-password', authMiddleware, changePassword)

export default router