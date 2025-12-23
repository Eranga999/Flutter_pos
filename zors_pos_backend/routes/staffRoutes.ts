import { Router } from 'express';
import { getStaff, createStaff, updateStaff, deleteStaff } from '../controllers/staffController';

const router = Router();

// Public routes
router.get('/staff', getStaff);
router.post('/staff', createStaff);
router.put('/staff/:id', updateStaff);
router.delete('/staff/:id', deleteStaff);

export default router;