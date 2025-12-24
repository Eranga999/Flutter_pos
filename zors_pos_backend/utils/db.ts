import mongoose from 'mongoose'

export default async function connectDB(): Promise<void> {
  const uri = 'mongodb://ZORSPOS:Zorscode2025@G9CFBD628B0EF7A-ZORSPOS.adb.ap-singapore-1.oraclecloudapps.com:27017/zorspos?authMechanism=PLAIN&authSource=$external&ssl=true&retryWrites=false&loadBalanced=true'

  try {
    await mongoose.connect(uri)
    console.log('✅ MongoDB Connected!')
  } catch (err) {
    console.error('❌ MongoDB connection error:', err)
  }
}
