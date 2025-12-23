import Category from "../models/Category";
import { Request, Response } from "express";

export const getAllCategories = async (_: Request, res: Response): Promise<void> => {
    try {
        const categories = await Category.find();
        res.status(200).json({ success: true, data: categories });
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch categories", error });
    }
}

export const createCategory = async (req: Request, res: Response): Promise<void> => {
    try {
        const body = await req.body;
        if (!body.name) {
            res.status(400).json({ message: "Category name is required" });
            return;
        }
        const category = await Category.create({ name: body.name });
        res.status(201).json({ success: true, data: category });
    } catch (error) {
        res.status(500).json({ message: "Failed to create category", error });
    }
}

export const updateCategory = async (req: Request, res: Response): Promise<void> => {
    try {
        const id = req.params.id;
        const body = await req.body;
        const updated = await Category.findByIdAndUpdate(id, { name: body.name }, { new: true });
        res.status(200).json({ success: true, data: updated });
    } catch (error) {
        res.status(500).json({ message: "Failed to update category", error });
    }
}

export const deleteCategory = async (req: Request, res: Response): Promise<void> => {
    try {
        const id = req.params.id;
        await Category.findByIdAndDelete(id);
        res.status(200).json({ success: true, message: "Category deleted successfully" });
    } catch (error) {
        res.status(500).json({ message: "Failed to delete category", error });
    }
}