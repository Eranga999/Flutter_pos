import Product from "../models/Product";
import StockTransition from "../models/StockTransition";
import { Request, Response } from "express";
import { ElectronImageHandler } from '../utils/imageProcessor';
import fs from 'fs';
import path from 'path';


const generateBarcode = (): string => {
  const timestamp = Date.now().toString();
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
  const barcode = (timestamp.slice(-7) + random + '000').slice(0, 13);
  return barcode;
};

interface ProductQuery {
  $or?: Array<{
    name?: { $regex: string; $options: string };
    description?: { $regex: string; $options: string };
    category?: { $regex: string; $options: string };
    barcode?: { $regex: string; $options: string };
    shortId?: { $regex: string; $options: string };
  }>;
  category?: string;
}

export async function getAllProducts(req: Request, res: Response) {
  try {

    const search = req.query.search as string | undefined;
    const category = req.query.category as string | undefined;

    const query: ProductQuery = {};

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { category: { $regex: search, $options: 'i' } },
        { barcode: { $regex: search, $options: 'i' } },
        { shortId: { $regex: search, $options: 'i' } },
      ];
    }

    if (category && category !== 'all') {
      query.category = category;
    }

    const products = await Product.find(query).sort({ createdAt: -1 });
    return res.status(200).json(products);
  } catch (error) {
    console.error('Error fetching products:', error);
    return res.status(500).json({ error: 'Failed to fetch products' });
  }
}

// NEW: Image serving endpoint
export async function serveProductImage(req: Request, res: Response) {
  try {
    const { productId, filename } = req.params;
    const relativePath = `${productId}/${filename}`;
    
    if (!ElectronImageHandler.imageExists(relativePath)) {
      return res.status(404).json({ error: 'Image not found' });
    }

    const absolutePath = ElectronImageHandler.getAbsoluteImagePath(relativePath);
    const ext = path.extname(filename).toLowerCase();
    
    // Set appropriate content type
    const contentType = ext === '.png' ? 'image/png' : 
                       ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : 
                       ext === '.webp' ? 'image/webp' : 'image/png';
    
    res.setHeader('Content-Type', contentType);
    res.setHeader('Cache-Control', 'public, max-age=31536000'); // Cache for 1 year
    
    const imageStream = fs.createReadStream(absolutePath);
    return imageStream.pipe(res);
  } catch (error) {
    console.error('Error serving image:', error);
    return res.status(500).json({ error: 'Failed to serve image' });
  }
}

export async function createProduct(req: Request, res: Response) {
  try {
    // Access file from multer
    const file = req.file as Express.Multer.File | undefined;
    
    // Access form fields from req.body
    const {
      name,
      costPrice,
      sellingPrice,
      discount,
      category,
      size,
      dryfood,
      stock,
      description,
      supplier,
      barcode,
      userId,
      userName
    } = req.body;

    // Validate file if provided
    if (file) {
      if (!file.mimetype.startsWith('image/')) {
        return res.status(400).json({ error: 'File must be an image' });
      }

      if (file.size > 5 * 1024 * 1024) {
        return res.status(400).json({ error: 'File size must be less than 5MB' });
      }
    }

    // Prepare product data
    const productData: {
      name: string;
      costPrice: number;
      sellingPrice: number;
      discount: number;
      category: string;
      size?: string;
      dryfood: boolean;
      stock: number;
      description?: string;
      supplier?: string;
      barcode?: string;
      image?: string;
    } = {
      name,
      costPrice: Number(costPrice),
      sellingPrice: Number(sellingPrice),
      discount: discount ? Number(discount) : 0,
      category,
      dryfood: dryfood === 'true' || dryfood === true,
      stock: Number(stock),
      description: description || undefined,
      supplier: supplier || undefined,
      barcode: barcode || undefined,
    };

    if (size && size.trim() !== '') {
      productData.size = size.trim();
    }

    // Validate required fields
    if (!productData.name || !productData.costPrice || !productData.sellingPrice || !productData.category || productData.stock === undefined) {
      return res.status(400).json({
        error: 'Missing required fields: name, costPrice, sellingPrice, category, and stock are required'
      });
    }

    // Handle barcode
    if (productData.barcode && productData.barcode.trim() !== '') {
      const existingProduct = await Product.findOne({ barcode: productData.barcode });
      if (existingProduct) {
        return res.status(400).json({ error: 'Barcode already exists' });
      }
    } else {
      let generatedBarcode;
      let isUnique = false;

      do {
        generatedBarcode = generateBarcode();
        const existingProduct = await Product.findOne({ barcode: generatedBarcode });
        isUnique = !existingProduct;
      } while (!isUnique);

      productData.barcode = generatedBarcode;
    }

    // Create product first to get the ID
    const newProduct = new Product({
      name: productData.name,
      description: productData.description,
      category: productData.category,
      costPrice: productData.costPrice,
      sellingPrice: productData.sellingPrice,
      stock: productData.stock,
      barcode: productData.barcode,
      supplier: productData.supplier,
      discount: productData.discount,
      size: productData.size,
      dryfood: productData.dryfood,
    });
    
    const savedProduct = await newProduct.save();

    // Process and save image if file provided
    if (file && file.buffer) {
      try {
        // Returns relative path like "productId/filename-thumb.png"
        const relativeImagePath = await ElectronImageHandler.processAndSaveImage(
          file.buffer,
          savedProduct._id.toString(),
          file.originalname
        );
        
        savedProduct.image = relativeImagePath; // Store relative path
        await savedProduct.save();
      } catch (imageError) {
        console.error('Error processing image:', imageError);
        // Continue without image rather than failing the entire product creation
      }
    }

    // Create stock transition for initial stock
    if (savedProduct.stock > 0) {
      try {
        const stockTransition = new StockTransition({
          productId: savedProduct._id,
          productName: savedProduct.name,
          transactionType: 'purchase',
          quantity: savedProduct.stock,
          previousStock: 0,
          newStock: savedProduct.stock,
          unitPrice: savedProduct.costPrice || 0,
          totalValue: savedProduct.stock * (savedProduct.costPrice || 0),
          reference: `PRODUCT_CREATED_${savedProduct._id}`,
          party: {
            name: 'System',
            type: 'system',
            id: 'system'
          },
          user: userId || 'system',
          userName: userName || 'System',
          notes: `Initial stock added for new product: ${savedProduct.name}`
        });
        await stockTransition.save();
      } catch (transitionError) {
        console.error('Error creating stock transition:', transitionError);
      }
    }

    return res.status(201).json(savedProduct);

  } catch (error: unknown) {
    console.error("Error creating product:", error);
    return res.status(500).json(
      { message: "Internal Server Error" }
    );
  }
}

export async function getProductById(req: Request, res: Response) {
  try {
    const id = req.params.id;
    const product = await Product.findById(id);

    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }

    return res.status(200).json(product);
  } catch (error: unknown) {
    console.error('Error fetching product:', error);
    return res.status(500).json({ error: 'Failed to fetch product' });
  }
}

export async function updateProduct(req: Request, res: Response) {
  try {
    const id = req.params.id;
    const file = req.file as Express.Multer.File | undefined;

    const currentProduct = await Product.findById(id);
    if (!currentProduct) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const previousStock = currentProduct.stock;

    // Extract update data from req.body
    const {
      name,
      costPrice,
      sellingPrice,
      discount,
      category,
      size,
      stock,
      description,
      dryfood,
      barcode,
      supplier,
      minStock,
      userId,
      userName
    } = req.body;

    const updateData: {
      name?: string;
      costPrice?: number;
      sellingPrice?: number;
      discount?: number;
      category?: string;
      size?: string;
      stock?: number;
      description?: string;
      dryfood?: boolean;
      barcode?: string;
      supplier?: string;
      minStock?: number;
      image?: string;
    } = {};

    // Update fields if provided
    if (name !== undefined) updateData.name = name;
    if (costPrice !== undefined) updateData.costPrice = Number(costPrice);
    if (sellingPrice !== undefined) updateData.sellingPrice = Number(sellingPrice);
    if (discount !== undefined) updateData.discount = Number(discount);
    if (category !== undefined) updateData.category = category;
    if (size !== undefined) updateData.size = size;
    if (stock !== undefined) updateData.stock = Number(stock);
    if (minStock !== undefined) updateData.minStock = Number(minStock);
    if (description !== undefined) updateData.description = description;
    if (dryfood !== undefined) updateData.dryfood = dryfood === 'true' || dryfood === true;
    if (barcode !== undefined) updateData.barcode = barcode;
    if (supplier !== undefined) updateData.supplier = supplier;

    // Handle image upload
    if (file && file.buffer) {
      if (!file.mimetype.startsWith('image/')) {
        return res.status(400).json({ error: 'File must be an image' });
      }

      if (file.size > 5 * 1024 * 1024) {
        return res.status(400).json({ error: 'File size must be less than 5MB' });
      }

      try {
        // Delete old images
        if (currentProduct.image) {
          ElectronImageHandler.deleteProductImages(id);
        }

        // Process and save new image - returns relative path
        const relativeImagePath = await ElectronImageHandler.processAndSaveImage(
          file.buffer,
          id,
          file.originalname
        );
        updateData.image = relativeImagePath; // Store relative path
      } catch (imageError) {
        console.error('Error processing image:', imageError);
        return res.status(500).json({ error: 'Failed to process image' });
      }
    }

    // Handle barcode uniqueness
    if (updateData.barcode && updateData.barcode.trim() !== '') {
      const existingProduct = await Product.findOne({ 
        barcode: updateData.barcode,
        _id: { $ne: id }
      });
      if (existingProduct) {
        return res.status(400).json({ error: 'Barcode already exists' });
      }
    } else if (updateData.barcode === '') {
      updateData.barcode = generateBarcode();
    }

    const updatedProduct = await Product.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    );

    // Create stock transition if stock changed
    const newStock = updatedProduct!.stock;
    if (previousStock !== newStock) {
      try {
        const stockDifference = newStock - previousStock;
        const transactionType = stockDifference > 0 ? 'purchase' : 'adjustment';

        const stockTransitionData: {
          productId: string;
          productName: string;
          transactionType: string;
          quantity: number;
          previousStock: number;
          newStock: number;
          unitPrice: number;
          totalValue: number;
          reference: string;
          party: { name: string; type: string; id: string };
          user?: string;
          userName: string;
          notes: string;
        } = {
          productId: updatedProduct!._id,
          productName: updatedProduct!.name,
          transactionType,
          quantity: Math.abs(stockDifference),
          previousStock,
          newStock,
          unitPrice: updatedProduct!.costPrice || 0,
          totalValue: Math.abs(stockDifference) * (updatedProduct!.costPrice || 0),
          reference: `PRODUCT_UPDATED_${updatedProduct!._id}`,
          party: {
            name: 'System',
            type: 'system',
            id: 'system'
          },
          userName: userName || 'System',
          notes: `Stock ${stockDifference > 0 ? 'increased' : 'decreased'} from ${previousStock} to ${newStock} via product update`
        };

        if (userId && userId !== 'system' && /^[a-fA-F0-9]{24}$/.test(userId)) {
          stockTransitionData.user = userId;
        }

        const stockTransition = new StockTransition(stockTransitionData);
        await stockTransition.save();
      } catch (transitionError) {
        console.error('Error creating stock transition:', transitionError);
      }
    }

    return res.status(200).json(updatedProduct);
  } catch (error) {
    console.error('Error updating product:', error);
    return res.status(500).json({ error: 'Failed to update product' });
  }
}

export async function deleteProduct(req: Request, res: Response) {
  try {
    const id = req.params.id;

    const product = await Product.findById(id);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Delete product images
    try {
      await ElectronImageHandler.deleteProductImages(id);
    } catch (imageError) {
      console.error('Error deleting product images:', imageError);
    }

    // Create stock transition for remaining stock
    if (product.stock > 0) {
      try {
        const stockTransitionData = {
          productId: product._id,
          productName: product.name,
          transactionType: 'delete',
          quantity: product.stock,
          previousStock: product.stock,
          newStock: 0,
          unitPrice: product.costPrice || 0,
          totalValue: product.stock * (product.costPrice || 0),
          reference: `PRODUCT_DELETED_${product._id}`,
          party: {
            name: 'System',
            type: 'system',
            id: 'system'
          },
          userName: 'System',
          notes: `Product deleted with remaining stock: ${product.stock}`
        };

        const stockTransition = new StockTransition(stockTransitionData);
        await stockTransition.save();
      } catch (transitionError) {
        console.error('Error creating stock transition for product deletion:', transitionError);
      }
    }

    await Product.findByIdAndDelete(id);

    return res.status(200).json({ message: 'Product deleted successfully' });
  } catch (error) {
    console.error('Error deleting product:', error);
    return res.status(500).json({ error: 'Failed to delete product' });
  }
}