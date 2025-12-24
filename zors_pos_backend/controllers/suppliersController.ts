import { Request, Response } from 'express';
import Supplier from '../models/Supplier';

export async function getSuppliers(_: Request, res: Response) {
  try {
    const suppliers = await Supplier.find();
    return res.status(200).json(suppliers);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}

export async function createSupplier(req: Request, res: Response) {
  try {
    const body = req.body;
    const supplier = await Supplier.create(body);
    return res.status(201).json(supplier);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}

export async function updateSupplier(req: Request, res: Response) {
  try {
    const body = req.body;
    const id = req.params.id;
    const supplier = await Supplier.findByIdAndUpdate(id, body, { new: true });
    if (!supplier) return res.status(404).json({ error: 'Supplier not found' });
    return res.status(200).json(supplier);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}

export async function deleteSupplier(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const supplier = await Supplier.findByIdAndDelete(id);
    if (!supplier) return res.status(404).json({ error: 'Supplier not found' });
    return res.status(200).json({ success: true });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}