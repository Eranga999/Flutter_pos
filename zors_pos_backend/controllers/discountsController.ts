import Discount from "../models/Discount";
import { Request, Response } from "express";
import jwt from 'jsonwebtoken';

// Define the JWT payload interface
interface JWTPayload {
  id: string;
  username: string;
  role: string;
  iat?: number;
  exp?: number;
}

// JWT verification helper
const verifyToken = (token: string): JWTPayload => {
  const secret = 'zorspos_jwt_secret';
  if (!secret) {
    throw new Error('JWT_SECRET is not defined');
  }
  return jwt.verify(token, secret) as JWTPayload;
};

export async function getAllDiscounts(req: Request, res: Response) {
  try {

    // Get authorization header
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const decoded: JWTPayload = verifyToken(token);
    const userRole = decoded.role;

    // Only admins can fetch all discounts
    if (userRole !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const discounts = await Discount.find();
    return res.status(200).json(discounts);
  } catch (error: unknown) {
    console.error('Error fetching discounts:', error);

    // Handle specific JWT errors
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired' });
    }

    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}

export async function createDiscount(req: Request, res: Response) {
  try {

    // Get authorization header
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const decoded: JWTPayload = verifyToken(token);
    const userRole = decoded.role;

    // Only admins can create discounts
    if (userRole !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    const { name, percentage, isGlobal } = req.body;

    // Validate required fields
    if (!name || percentage === undefined) {
      return res.status(400).json(
        { error: 'Name and percentage are required' }
      );
    }

    // Validate percentage
    const discountPercentage = Number(percentage);
    if (isNaN(discountPercentage) || discountPercentage < 0 || discountPercentage > 100) {
      return res.status(400).json(
        { error: 'Percentage must be between 0 and 100' }
      );
    }

    // If setting a global discount, unset any existing global discount
    if (isGlobal) {
      await Discount.updateMany({ isGlobal: true }, { isGlobal: false });
    }

    const newDiscount = new Discount({
      name,
      percentage: discountPercentage,
      isGlobal: isGlobal || false,
    });

    await newDiscount.save();

    return res.status(201).json(newDiscount);
  } catch (error: unknown) {
    console.error('Error creating discount:', error);

    // Handle specific JWT errors
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired' });
    }

    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}

export async function updateDiscount(req: Request, res: Response) {
  try {

    // Get authorization header
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const decoded: JWTPayload = verifyToken(token);
    const userRole = decoded.role;

    // Only admins can update discounts
    if (userRole !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { id, name, percentage, isGlobal } = await req.body;

    // Validate required fields
    if (!id) {
      return res.status(400).json(
        { error: 'Discount ID is required' }
      );
    }

    // Validate percentage if provided
    let discountPercentage: number | undefined;
    if (percentage !== undefined) {
      discountPercentage = Number(percentage);
      if (isNaN(discountPercentage) || discountPercentage < 0 || discountPercentage > 100) {
        return res.status(400).json(
          { error: 'Percentage must be between 0 and 100' }
        );
      }
    }

    // If setting a global discount, unset any existing global discount (except the current one)
    if (isGlobal) {
      await Discount.updateMany({ isGlobal: true, _id: { $ne: id } }, { isGlobal: false });
    }

    const updateData: Partial<{
      name: string;
      percentage: number;
      isGlobal: boolean;
      updatedAt: Date;
    }> = {};

    if (name !== undefined) updateData.name = name;
    if (percentage !== undefined) updateData.percentage = discountPercentage;
    if (isGlobal !== undefined) updateData.isGlobal = isGlobal;

    const updatedDiscount = await Discount.findByIdAndUpdate(
      id,
      { ...updateData, updatedAt: new Date() },
      { new: true }
    );

    if (!updatedDiscount) {
      return res.status(404).json({ error: 'Discount not found' });
    }

    return res.json(updatedDiscount);
  } catch (error: unknown) {
    console.error('Error updating discount:', error);

    // Handle specific JWT errors
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired' });
    }

    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}

export async function deleteDiscount(req: Request, res: Response) {
    try {

    // Get authorization header
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const decoded: JWTPayload = verifyToken(token);
    const userRole = decoded.role;

    // Only admins can delete discounts
    if (userRole !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) {
      return res.status(400).json({ error: 'Discount ID is required' });
    }

    const deletedDiscount = await Discount.findByIdAndDelete(id);

    if (!deletedDiscount) {
      return res.status(404).json({ error: 'Discount not found' });
    }

    return res.json({ message: 'Discount deleted successfully' });
  } catch (error: unknown) {
    console.error('Error deleting discount:', error);

    // Handle specific JWT errors
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired' });
    }

    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    return res.status(500).json({ error: errorMessage });
  }
}