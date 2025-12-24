import { Router } from 'express';
import { getReports } from '../controllers/reportsController';

const router = Router();

// Public route
router.get('/reports', getReports);

export default router;