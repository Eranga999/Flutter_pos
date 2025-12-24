import mongoose, { Document, Schema } from "mongoose";
import { IUser } from "./User";

export interface Product {
  _id: string;
  shortId: string;
  name: string;
  costPrice: number;
  sellingPrice: number;
  discount?: number;
  category: string;
  size?: string;
  dryfood?: boolean;
  image?: string;
  imagePublicId?: string;
  stock: number;
  description?: string;
  barcode?: string;
  supplier?: string;
}

export interface CartItem {
  product: Product;
  quantity: number;
  subtotal: number;
  note?: string;
}

export interface Customer {
  _id?: string;
  name?: string;
  email?: string;
  phone?: string;
  birthDate?: string;
}

export interface Coupon {
  code: string;
  discount: number;
  type: 'percentage' | 'fixed';
  applicableItems?: string[];
  description: string;
}

export interface PaymentDetails {
  method: 'cash' | 'card';
  cashGiven?: number;
  change?: number;
  invoiceId?: string;
  bankServiceCharge?: number;
  bankName?: string;
}


export interface Order extends Document {
    name: string; // Live Bill, Table 1, ...
    cart: CartItem[];
    customer?: Customer;
    cashier: IUser;
    orderType: 'dine-in' | 'takeaway' | 'delivery';
    appliedCoupon?: Coupon;
    kitchenNote?: string;
    createdAt: Date;
    status: 'active' | 'completed';
    isDefault?: boolean;
    paymentDetails: PaymentDetails;
    tableCharge: number;
    deliveryCharge?: number;
    discountPercentage: number;
    totalAmount: number;
}

const orderSchema = new Schema<Order>({
    name: { type: String, required: true },
    cart: { type: [Object], required: true },
    customer: { type: Object, default: {} },
    cashier: { type: Object, required: true },
    orderType: { type: String, enum: ['dine-in', 'takeaway', 'delivery'], required: true },
    appliedCoupon: { type: Object },
    kitchenNote: { type: String },
    createdAt: { type: Date, default: Date.now },
    status: { type: String, enum: ['active', 'completed'], default: 'active' },
    isDefault: { type: Boolean, default: false },
    paymentDetails: { type: Object, required: true },
    tableCharge: { type: Number, default: 0 },
    deliveryCharge: { type: Number, default: 0 },
    discountPercentage: { type: Number, default: 0 },
    totalAmount: { type: Number, required: true }
}, { timestamps: true })

export default mongoose.models.Order || mongoose.model<Order>('Order', orderSchema);