import mongoose, { Schema, Document } from "mongoose";

export interface Customer extends Document {
  name: string;
  email: string;
  phone: string;
  birthDate: Date;
}

const customerSchema = new Schema<Customer>({
  name: { type: String },
  email: { type: String },
  phone: { type: String },
  birthDate: { type: Date },
});

const CustomerModel = mongoose.models.Customer || mongoose.model<Customer>("Customer", customerSchema);

export default CustomerModel;