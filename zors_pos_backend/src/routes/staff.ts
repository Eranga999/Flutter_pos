import express, { Router, Request, Response } from 'express';
import Staff from '../models/Staff';
import { verifyToken } from '../middleware/auth';

const router: Router = express.Router();

// Get all staff
router.get('/', async (req: Request, res: Response) => {
  try {
    const staff = await Staff.find().sort({ name: 1 });
    return res.status(200).json(staff);
  } catch (error: unknown) {
    console.error('Error fetching staff:', error);
    return res.status(500).json({ error: 'Failed to fetch staff' });
  }
});

// Get single staff member
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const staff = await Staff.findById(req.params.id);
    if (!staff) {
      return res.status(404).json({ error: 'Staff member not found' });
    }
    return res.status(200).json(staff);
  } catch (error: unknown) {
    console.error('Error fetching staff:', error);
    return res.status(500).json({ error: 'Failed to fetch staff' });
  }
});

// Create staff member
router.post('/', verifyToken, async (req: Request, res: Response) => {
  try {
    const { name, email, phone, position, joinDate } = req.body;

    if (!name || !email || !phone || !position || !joinDate) {
      return res.status(400).json({ message: 'All required fields must be provided' });
    }

    const staff = new Staff(req.body);
    await staff.save();

    return res.status(201).json({ message: 'Staff member created', staff });
  } catch (error: unknown) {
    console.error('Error creating staff:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to create staff';
    return res.status(500).json({ message: errorMessage });
  }
});

// Update staff member
router.put('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const staff = await Staff.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!staff) {
      return res.status(404).json({ error: 'Staff member not found' });
    }
    return res.status(200).json({ message: 'Staff updated', staff });
  } catch (error: unknown) {
    console.error('Error updating staff:', error);
    return res.status(500).json({ error: 'Failed to update staff' });
  }
});

// Delete staff member
router.delete('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const staff = await Staff.findByIdAndDelete(req.params.id);
    if (!staff) {
      return res.status(404).json({ error: 'Staff member not found' });
    }
    return res.status(200).json({ message: 'Staff member deleted' });
  } catch (error: unknown) {
    console.error('Error deleting staff:', error);
    return res.status(500).json({ error: 'Failed to delete staff' });
  }
});

export default router;
