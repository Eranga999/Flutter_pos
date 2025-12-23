import { Request, Response } from 'express';
import Product from '../models/Product';
import Return from '../models/Return';
import StockTransition from '../models/StockTransition';

// Define interfaces for type safety
interface ReturnItem {
  _id: string;
  productId: {
    _id: string;
  };
  productName: string;
  returnType: 'customer' | 'supplier';
  quantity: number;
  reason: string;
  notes?: string;
  unitPrice: number;
  totalValue: number;
  cashier: {
    _id: string;
  };
  cashierName: string;
  createdAt: Date;
}

interface TransformedReturn {
  _id: string;
  product: {
    _id: string;
    name: string;
    sellingPrice: number;
  };
  returnType: 'customer' | 'supplier';
  quantity: number;
  reason: string;
  notes?: string;
  cashier: {
    _id: string;
    username: string;
  };
  createdAt: string;
  totalValue: number;
}

interface UserInfo {
  _id: string;
  username: string;
  role?: string;
}

interface ReturnRequestBody {
  productId: string;
  returnType: 'customer' | 'supplier';
  quantity: number;
  reason: string;
  notes?: string;
}

export async function getReturns(_: Request, res: Response) {
  try {
    // Fetch returns from database with product details
    const returns = await Return.find();

    // Transform the data to match the expected format
    const transformedReturns: TransformedReturn[] = returns.map((returnItem: ReturnItem) => ({
      _id: returnItem._id.toString(),
      product: {
        _id: returnItem.productId._id.toString(),
        name: returnItem.productName,
        sellingPrice: returnItem.unitPrice
      },
      returnType: returnItem.returnType,
      quantity: returnItem.quantity,
      reason: returnItem.reason,
      notes: returnItem.notes,
      cashier: {
        _id: returnItem.cashier._id.toString(),
        username: returnItem.cashierName
      },
      createdAt: returnItem.createdAt.toISOString(),
      totalValue: returnItem.totalValue
    }));

    return res.status(200).json(transformedReturns);
  } catch (error: unknown) {
    console.error('Error fetching returns:', error);
    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}

export async function postReturn(req: Request, res: Response) {
  try {

    const body: ReturnRequestBody = req.body;
    const { productId, returnType, quantity, reason, notes } = body;

    // Validate required fields
    if (!productId || !returnType || !quantity || !reason) {
      return res.status(400).json(
        { error: 'Missing required fields' }
      );
    }

    // Find the product
    const product = await Product.findById(productId);
    if (!product) {
      return res.status(404).json(
        { error: 'Product not found' }
      );
    }

    // Validate quantity
    const returnQuantity = parseInt(quantity.toString());
    if (isNaN(returnQuantity) || returnQuantity <= 0) {
      return res.status(400).json(
        { error: 'Invalid quantity' }
      );
    }

    // For supplier returns, check if enough stock is available
    if (returnType === 'supplier' && returnQuantity > product.stock) {
      return res.status(400).json(
        { error: 'Insufficient stock for return' }
      );
    }

    // Get user info from request headers
    const userInfoHeader = req.headers['x-user-info'] as string | undefined;
    let user: UserInfo;

    if (userInfoHeader) {
      try {
        user = JSON.parse(userInfoHeader) as UserInfo;
      } catch (err) {
        return res.status(400).json(
          { error: 'Invalid user info format', err }
        );
      }
    } else {
      return res.status(400).json(
        { error: 'User information required' }
      );
    }

    // Get the previous stock before any changes
    const previousStock = product.stock;

    // Calculate new stock based on return type
    let newStock: number;
    if (returnType === 'customer') {
      // Customer return increases stock
      newStock = product.stock + returnQuantity;
    } else {
      // Supplier return decreases stock
      newStock = product.stock - returnQuantity;
    }

    // Create return record first
    const returnRecord = new Return({
      productId: product._id,
      productName: product.name,
      returnType,
      quantity: returnQuantity,
      reason,
      notes: notes || '',
      unitPrice: product.sellingPrice,
      totalValue: returnQuantity * product.sellingPrice,
      previousStock,
      newStock,
      cashier: user._id,
      cashierName: user.username,
      status: 'completed'
    });

    const savedReturn = await returnRecord.save();

    // Update product stock in database
    await Product.findByIdAndUpdate(productId, { stock: newStock });

    // Create stock transition record
    try {
      const stockTransition = new StockTransition({
        productId: product._id,
        productName: product.name,
        transactionType: returnType === 'customer' ? 'customer_return' : 'supplier_return',
        quantity: returnQuantity,
        previousStock,
        newStock,
        unitPrice: product.sellingPrice,
        totalValue: returnQuantity * product.sellingPrice,
        reference: savedReturn._id.toString(),
        party: {
          name: returnType === 'customer' ? 'Customer Return' : 'Supplier Return',
          type: returnType === 'customer' ? 'customer' : 'supplier',
          id: returnType === 'customer' ? 'customer_return' : 'supplier_return'
        },
        user: user._id,
        userName: user.username,
        notes: `${returnType === 'customer' ? 'Customer' : 'Supplier'} return - ${reason}${notes ? ` | ${notes}` : ''}`
      });

      await stockTransition.save();
      console.log('Stock transition created for return:', stockTransition._id);
    } catch (transitionError) {
      console.error('Error creating stock transition for return:', transitionError);
      // Log the error but don't fail the return process
      // In production, you might want to implement a retry mechanism
    }

    // Return the created record with proper formatting
    const responseData: TransformedReturn = {
      _id: savedReturn._id.toString(),
      product: {
        _id: product._id.toString(),
        name: product.name,
        sellingPrice: product.sellingPrice
      },
      returnType: savedReturn.returnType,
      quantity: savedReturn.quantity,
      reason: savedReturn.reason,
      notes: savedReturn.notes,
      cashier: {
        _id: user._id,
        username: user.username
      },
      createdAt: savedReturn.createdAt.toISOString(),
      totalValue: savedReturn.totalValue
    };

    return res.status(201).json(
      {
        message: 'Return processed successfully',
        return: responseData,
        newStock
      }
    );
  } catch (error: unknown) {
    console.error('Error processing return:', error);
    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}