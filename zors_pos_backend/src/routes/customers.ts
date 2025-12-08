import express, { Router, Request, Response } from 'express';
import Customer from '../models/Customer';
import { verifyToken } from '../middleware/auth';

const router: Router = express.Router();

// Get all customers
router.get('/', async (req: Request, res: Response) => {
  try {
    const customers = await Customer.find().sort({ createdAt: -1 });
    return res.status(200).json(customers);
  } catch (error: unknown) {
    console.error('Error fetching customers:', error);
    return res.status(500).json({ error: 'Failed to fetch customers' });
  }
});

// Get single customer
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const customer = await Customer.findById(req.params.id);
    if (!customer) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    return res.status(200).json(customer);
  } catch (error: unknown) {
    console.error('Error fetching customer:', error);
    return res.status(500).json({ error: 'Failed to fetch customer' });
  }
});

// Create customer
router.post('/', verifyToken, async (req: Request, res: Response) => {
  try {
    const { name, phone } = req.body;

    if (!name || !phone) {
      return res.status(400).json({ message: 'Name and phone are required' });
    }

    const customer = new Customer(req.body);
    await customer.save();

    return res.status(201).json({ message: 'Customer created', customer });
  } catch (error: unknown) {
    console.error('Error creating customer:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to create customer';
    return res.status(500).json({ message: errorMessage });
  }
});

// Update customer
router.put('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const customer = await Customer.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!customer) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    return res.status(200).json({ message: 'Customer updated', customer });
  } catch (error: unknown) {
    console.error('Error updating customer:', error);
    return res.status(500).json({ error: 'Failed to update customer' });
  }
});

// Delete customer
router.delete('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const customer = await Customer.findByIdAndDelete(req.params.id);
    if (!customer) {
      return res.status(404).json({ error: 'Customer not found' });
    }
    return res.status(200).json({ message: 'Customer deleted' });
  } catch (error: unknown) {
    console.error('Error deleting customer:', error);
    return res.status(500).json({ error: 'Failed to delete customer' });
  }
});

export default router;
