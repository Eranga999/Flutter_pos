import mongoose, { Document, Schema } from 'mongoose';

export interface IProduct extends Document<string> {
  _id: string;
  name: string;
  description?: string;
  category: string;
  costPrice: number;
  sellingPrice: number;
  stock: number;
  minStock: number;
  barcode?: string;
  image?: string;
  supplier?: string;
  discount?: number;
  size?: string;
  dryfood?: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const ProductSchema = new Schema<IProduct>(
  {
    // Do not require _id; generate in pre('save') when missing
    _id: { type: String },
    name: { type: String, required: true },
    description: { type: String },
    category: { type: String, required: true },
    costPrice: { type: Number, required: true },
    sellingPrice: { type: Number, required: true },
    stock: { type: Number, required: true, default: 0 },
    minStock: { type: Number, required: true, default: 5 },
    barcode: { type: String, unique: true, sparse: true },
    image: { type: String },
    supplier: { type: String },
    discount: { type: Number, default: 0 },
    size: { type: String },
    dryfood: { type: Boolean, default: false },
  },
  {
    timestamps: true,
    _id: false,
  }
);

ProductSchema.pre('save', async function (next) {
  if (!this._id) {
    let uniqueId: string;
    let isUnique = false;

    while (!isUnique) {
      uniqueId = Math.floor(100000 + Math.random() * 900000).toString();
      const existing = await mongoose.models.Product.findById(uniqueId);
      if (!existing) {
        isUnique = true;
        this._id = uniqueId;
      }
    }
  }
  next();
});

export default mongoose.models.Product || mongoose.model<IProduct>('Product', ProductSchema);
