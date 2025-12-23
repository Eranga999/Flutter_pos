import { Router } from 'express';
import { getAllStockTransitions, createStockTransition } from '../controllers/stocktransitionsController';

const router = Router();

// Public routes
router.get('/stock-transitions', getAllStockTransitions);
router.post('/stock-transitions', createStockTransition);

export default router;