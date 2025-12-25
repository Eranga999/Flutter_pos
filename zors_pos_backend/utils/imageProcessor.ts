import path from 'path';
import fs from 'fs';

export class ElectronImageHandler {
  private static getAppDataPath(): string {
    // Server-side path for storing product images
    // Use env var PRODUCT_IMAGES_DIR if provided, else default to ./uploads/products
    const base = process.env.PRODUCT_IMAGES_DIR || path.join(process.cwd(), 'uploads', 'products');
    if (!fs.existsSync(base)) {
      fs.mkdirSync(base, { recursive: true });
    }
    return base;
  }

  static async processAndSaveImage(
    imageBuffer: Buffer,
    productId: string,
    filename: string
  ): Promise<string> {
    const productDir = path.join(this.getAppDataPath(), productId);
    
    // Ensure directory exists
    if (!fs.existsSync(productDir)) {
      fs.mkdirSync(productDir, { recursive: true });
    }

    const baseFilename = path.parse(filename).name;
    const ext = path.parse(filename).ext.toLowerCase() || '.png';
    const thumbnailFilename = `${baseFilename}-thumb${ext}`;
    const thumbnailPath = path.join(productDir, thumbnailFilename);
    
    try {
      // Save image buffer directly; avoid Electron/nativeImage dependency
      // Optionally, integrate a resizer (e.g., sharp) in future.
      fs.writeFileSync(thumbnailPath, imageBuffer);
      
      // Return RELATIVE path instead of absolute
      return `${productId}/${thumbnailFilename}`;
    } catch (error) {
      console.error('Error processing image:', error);
      throw error;
    }
  }

  static deleteProductImages(productId: string): void {
    const productDir = path.join(this.getAppDataPath(), productId);
    if (fs.existsSync(productDir)) {
      fs.rmSync(productDir, { recursive: true, force: true });
    }
  }

  static getAbsoluteImagePath(relativePath: string): string {
    return path.join(this.getAppDataPath(), relativePath);
  }

  static imageExists(relativePath: string): boolean {
    const absolutePath = this.getAbsoluteImagePath(relativePath);
    return fs.existsSync(absolutePath);
  }
}