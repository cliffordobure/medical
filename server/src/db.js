import mongoose from 'mongoose';

export async function connectDb(uri) {
  await mongoose.connect(uri);
  return mongoose.connection;
}
