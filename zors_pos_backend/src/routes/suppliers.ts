import express, { Router, Request, Response } from 'express';
import Supplier from '../models/Supplier';
import { verifyToken } from '../middleware/auth';

const router: Router = express.Router();

// Get all suppliers
router.get('/', async (req: Request, res: Response) => {
  try {
    const suppliers = await Supplier.find().sort({ name: 1 });
    return res.status(200).json(suppliers);
  } catch (error: unknown) {
    console.error('Error fetching suppliers:', error);
    return res.status(500).json({ error: 'Failed to fetch suppliers' });
  }
});

// Get single supplier
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const supplier = await Supplier.findById(req.params.id);
    if (!supplier) {
      return res.status(404).json({ error: 'Supplier not found' });
    }
    return res.status(200).json(supplier);
  } catch (error: unknown) {
    console.error('Error fetching supplier:', error);
    return res.status(500).json({ error: 'Failed to fetch supplier' });
  }
});

// Create supplier
router.post('/', verifyToken, async (req: Request, res: Response) => {
  try {
    const { name, phone } = req.body;

    if (!name || !phone) {
      return res.status(400).json({ message: 'Name and phone are required' });
    }

    const supplier = new Supplier(req.body);
    await supplier.save();

    return res.status(201).json({ message: 'Supplier created', supplier });
  } catch (error: unknown) {
    console.error('Error creating supplier:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to create supplier';
    return res.status(500).json({ message: errorMessage });
  }
});

// Update supplier
router.put('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const supplier = await Supplier.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!supplier) {
      return res.status(404).json({ error: 'Supplier not found' });
    }
    return res.status(200).json({ message: 'Supplier updated', supplier });
  } catch (error: unknown) {
    console.error('Error updating supplier:', error);
    return res.status(500).json({ error: 'Failed to update supplier' });
  }
});

// Delete supplier
router.delete('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const supplier = await Supplier.findByIdAndDelete(req.params.id);
    if (!supplier) {
      return res.status(404).json({ error: 'Supplier not found' });
    }
    return res.status(200).json({ message: 'Supplier deleted' });
  } catch (error: unknown) {
    console.error('Error deleting supplier:', error);
    return res.status(500).json({ error: 'Failed to delete supplier' });
  }
});

export default router;
