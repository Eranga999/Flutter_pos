import { app, nativeImage } from 'electron';
import path from 'path';
import fs from 'fs';

export class ElectronImageHandler {
  private static getAppDataPath(): string {
    // Use proper Electron user data directory
    return path.join(app.getPath('userData'), 'products');
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
      // Create native image from buffer
      const image = nativeImage.createFromBuffer(imageBuffer);
      
      // Resize to 300x300
      const resized = image.resize({ width: 300, height: 300 });
      
      // Save based on original format
      let imageData: Buffer;
      if (ext === '.jpg' || ext === '.jpeg') {
        imageData = resized.toJPEG(80);
      } else {
        imageData = resized.toPNG();
      }
      
      // Write to file
      fs.writeFileSync(thumbnailPath, imageData);
      
      // Return RELATIVE path instead of absolute
      return `${productId}/${thumbnailFilename}`;
    } catch (error) {
      console.error('Error processing image with nativeImage:', error);
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