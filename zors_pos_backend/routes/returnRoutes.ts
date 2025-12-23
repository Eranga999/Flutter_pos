import { Router } from 'express';
import { getReturns, postReturn } from '../controllers/returnController';

const router = Router();

// Public routes
router.get('/returns', getReturns);
router.post('/returns', postReturn);

export default router;