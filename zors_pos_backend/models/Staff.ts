import mongoose, { Schema, Document } from "mongoose";

export interface IStaff extends Document {
  name: string;
  category: string;
  contactNumber: string;
  address: string;
  email: string;
}

const StaffSchema: Schema = new Schema({
  name: { type: String, required: true },
  category: { type: String, required: true },
  contactNumber: { type: String, required: true },
  address: { type: String, required: true },
  email: { type: String, required: true },
});

export default mongoose.models.Staff ||
  mongoose.model<IStaff>("Staff", StaffSchema);