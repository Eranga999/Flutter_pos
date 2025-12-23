import CustomerModel from "../models/Customer";
import { Request, Response } from "express";

export const getAllCustomers = async (_: Request, res: Response) => {
    try {
        const customers = await CustomerModel.find();
        res.status(200).json(customers);
    } catch (error) {
        res.status(500).json({ message: "Failed to fetch customers", error });
    }
}

export const createCustomer = async (req: Request, res: Response) => {
    try {
        const { name, email, phone, birthDate } = await req.body;
        const customer = new CustomerModel({ name, email, phone, birthDate });
        const savedCustomer = await customer.save();
        res.status(201).json(savedCustomer);
    } catch (error) {
        res.status(500).json({ message: "Failed to create customer", error });
    }
}

export const getCustomerById = async (req: Request, res: Response) => {
    try {
        const id = req.params.id;
        const customer = await CustomerModel.findById(id);
        if (!customer) {
            return res.status(404).json({ message: "Customer not found" });
        }
        return res.status(200).json(customer);
    } catch (error) {
        return res.status(500).json({ message: "Failed to fetch customer", error });
    }
}

export const updateCustomer = async (req: Request, res: Response) => {
    try {
        const id = req.params.id;
        if (!id) {
            return res.status(400).json({ message: "Customer ID is required" });
        }

        const { name, email, phone, birthDate } = req.body;

        const customer = await CustomerModel.findByIdAndUpdate(
            id,
            { name, email, phone, birthDate },
            { new: true }
        );

        if (!customer) {
            return res.status(404).json({ message: "Customer not found" });
        }
        return res.status(200).json(customer);
    } catch (error) {
        return res.status(500).json({ message: "Failed to update customer", error });
    }
}

export const deleteCustomer = async (req: Request, res: Response) => {
    try {
        const id = req.params.id;
        if (!id) {
            return res.status(400).json({ message: "Customer ID is required" });
        }

        const customer = await CustomerModel.findByIdAndDelete(id);
        if (!customer) {
            return res.status(404).json({ message: "Customer not found" });
        }
        return res.status(200).json({ message: "Customer deleted successfully" });
    } catch (error) {
        return res.status(500).json({ message: "Failed to delete customer", error });
    }
}