import express, { Router, Request, Response } from 'express';
import Product from '../models/Product';
import StockTransition from '../models/StockTransition';
import { verifyToken } from '../middleware/auth';

const router: Router = express.Router();

// Get all products with filters
router.get('/', async (req: Request, res: Response) => {
  try {
    const { search, category } = req.query;

    const query: any = {};

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { category: { $regex: search, $options: 'i' } },
        { barcode: { $regex: search, $options: 'i' } },
        { _id: { $regex: search, $options: 'i' } },
      ];
    }

    if (category && category !== 'all') {
      query.category = category;
    }

    const products = await Product.find(query).sort({ createdAt: -1 });
    return res.status(200).json(products);
  } catch (error: unknown) {
    console.error('Error fetching products:', error);
    return res.status(500).json({ error: 'Failed to fetch products' });
  }
});

// Get single product
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    return res.status(200).json(product);
  } catch (error: unknown) {
    console.error('Error fetching product:', error);
    return res.status(500).json({ error: 'Failed to fetch product' });
  }
});

// Create product
router.post('/', verifyToken, async (req: Request, res: Response) => {
  try {
    const { name, category, costPrice, sellingPrice, minStock, ...rest } = req.body;

    if (!name || !category || !costPrice || !sellingPrice) {
      return res.status(400).json({ message: 'Required fields missing' });
    }

    const productData = {
      name,
      category,
      costPrice: Number(costPrice),
      sellingPrice: Number(sellingPrice),
      minStock: Number(minStock) || 5,
      stock: 0,
      ...rest,
    };

    const product = new Product(productData);
    await product.save();

    return res.status(201).json({ message: 'Product created', product });
  } catch (error: unknown) {
    console.error('Error creating product:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to create product';
    return res.status(500).json({ message: errorMessage });
  }
});

// Update product
router.put('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const product = await Product.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    return res.status(200).json({ message: 'Product updated', product });
  } catch (error: unknown) {
    console.error('Error updating product:', error);
    return res.status(500).json({ error: 'Failed to update product' });
  }
});

// Delete product
router.delete('/:id', verifyToken, async (req: Request, res: Response) => {
  try {
    const product = await Product.findByIdAndDelete(req.params.id);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    return res.status(200).json({ message: 'Product deleted' });
  } catch (error: unknown) {
    console.error('Error deleting product:', error);
    return res.status(500).json({ error: 'Failed to delete product' });
  }
});

export default router;
