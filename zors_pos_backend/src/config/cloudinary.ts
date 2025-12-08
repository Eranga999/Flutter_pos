import { v2 as cloudinary } from 'cloudinary';

const cloudName = process.env.CLOUD_NAME;
const cloudApiKey = process.env.CLOUD_API_KEY;
const cloudApiSecret = process.env.CLOUD_API_SECRET;

// Allow running without Cloudinary in local/dev by treating it as optional
export const cloudinaryEnabled = Boolean(cloudName && cloudApiKey && cloudApiSecret);

if (cloudinaryEnabled) {
  cloudinary.config({
    cloud_name: cloudName,
    api_key: cloudApiKey,
    api_secret: cloudApiSecret,
  } as any);
} else {
  console.warn('⚠️  Cloudinary env vars missing; skipping Cloudinary setup');
}

export const cloudinaryConnection = async (): Promise<void> => {
  if (!cloudinaryEnabled) return; // no-op when not configured
  try {
    await (cloudinary.api as any).ping();
    console.log('✓ Cloudinary connection successful');
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    console.error('✗ Cloudinary connection failed:', errorMessage);
    throw error; // bubble up to stop server start
  }
};

export const uploadImageToCloudinary = async (
  file: any,
  folder: string = 'products'
): Promise<any> => {
  if (!cloudinaryEnabled) {
    throw new Error('Cloudinary is not configured');
  }
  try {
    const result = await (cloudinary.uploader as any).upload(file.path, {
      folder,
      resource_type: 'image',
      transformation: [
        { width: 500, height: 500, crop: 'fill' },
        { quality: 'auto:good' }
      ]
    });
    return result;
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    console.error('Failed to upload image to Cloudinary:', errorMessage);
    throw new Error('Image upload failed');
  }
};

export const deleteImageFromCloudinary = async (publicId: string): Promise<void> => {
  if (!cloudinaryEnabled) return; // nothing to delete if not configured
  try {
    await (cloudinary.uploader as any).destroy(publicId);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    console.error('Failed to delete image from Cloudinary:', errorMessage);
  }
};

export default cloudinary;
