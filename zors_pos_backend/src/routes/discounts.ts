import express, { Router, Request, Response } from 'express';
import Discount from '../models/Discount';
import { verifyToken } from '../middleware/auth';

const router: Router = express.Router();

// Get all discounts
router.get('/', async (req: Request, res: Response) => {
  try {
    const discounts = await Discount.find().sort({ createdAt: -1 });
    return res.status(200).json(discounts);
  } catch (error: unknown) {
    console.error('Error fetching discounts:', error);
    return res.status(500).json({ error: 'Failed to fetch discounts' });
  }
});

// Create discount
router.post('/', verifyToken, async (req: Request, res: Response) => {
  try {
    const { code, discountType, discountValue } = req.body;

    if (!code || !discountType || !discountValue) {
      return res.status(400).json({ message: 'Required fields missing' });
    }

    const discount = new Discount(req.body);
    await discount.save();

    return res.status(201).json({ message: 'Discount created', discount });
  } catch (error: unknown) {
    console.error('Error creating discount:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to create discount';
    return res.status(500).json({ message: errorMessage });
  }
});

// Update discount
router.put('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const discount = await Discount.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!discount) {
      return res.status(404).json({ error: 'Discount not found' });
    }
    return res.status(200).json({ message: 'Discount updated', discount });
  } catch (error: unknown) {
    console.error('Error updating discount:', error);
    return res.status(500).json({ error: 'Failed to update discount' });
  }
});

// Delete discount
router.delete('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const discount = await Discount.findByIdAndDelete(req.params.id);
    if (!discount) {
      return res.status(404).json({ error: 'Discount not found' });
    }
    return res.status(200).json({ message: 'Discount deleted' });
  } catch (error: unknown) {
    console.error('Error deleting discount:', error);
    return res.status(500).json({ error: 'Failed to delete discount' });
  }
});

export default router;
