import { Request, Response } from "express";
import Staff from "../models/Staff";

export async function getStaff(_: Request, res: Response) {
    try {
        const staff = await Staff.find();
        return res.status(200).json({ data: staff });
    } catch (error) {
        console.error('Error fetching staff:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
}

export async function createStaff(req: Request, res: Response) {
    try {
        const body = req.body;
        const newStaff = await Staff.create(body);
        return res.status(201).json({ data: newStaff });
    } catch (error) {
        console.error('Error creating staff:', error);
        return res.status(500).json({ error: 'Internal server error' });        
    }
}

export async function updateStaff(req: Request, res: Response) {
    try {

    const id = req.params.id;
    const body = req.body;

    const updated = await Staff.findByIdAndUpdate(id, body, { new: true });
    if (!updated) {
      return res.status(404).json({ error: "Staff member not found" });
    }

    return res.status(200).json({ data: updated });

  } catch (error) {
    console.error("Error connecting to database:", error);
    return res.status(500).json({ error: "Database connection error" });
  }
}

export async function deleteStaff(req: Request, res: Response) {
    try {
    const id = req.params.id;
    const deleted = await Staff.findByIdAndDelete(id);
    if (!deleted) {
      return res.status(404).json({ error: "Staff member not found" });
    }
    return res.status(200).json({ message: "Staff member deleted successfully" });
  } catch (error) {
    console.error("Error connecting to database:", error);
    return res.status(500).json({ error: "Database connection error" });
  }
}