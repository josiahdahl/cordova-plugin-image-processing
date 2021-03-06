#import <Cordova/CDV.h>
#import "CDVImageProcessing.h"

@implementation CDVImageProcessing

- (void) resize:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;

        NSString *sourceUri = [command argumentAtIndex: 0];
        NSString *destinationUri = [command argumentAtIndex: 1];
        NSNumber *width = [command argumentAtIndex: 2];
        NSNumber *height = [command argumentAtIndex: 3];
        BOOL keepScale = [[command argumentAtIndex:4 withDefault:[NSNumber numberWithBool:NO]] boolValue];

        [self resizeImage:sourceUri toDestinationUri:destinationUri withSize:CGSizeMake([width floatValue], [height floatValue]) andKeepScale:keepScale];

        pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:@"Image resized"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) rotate:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;

        NSString *sourceUri = [command argumentAtIndex: 0];
        NSString *destinationUri = [command argumentAtIndex: 1];
        NSNumber *angle = [command argumentAtIndex: 2];

        [self rotateImage:sourceUri toDestinationUri:destinationUri toAngle:angle];

        pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:@"Image rotated"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) crop:(CDVInvokedUrlCommand *)command {

    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;

        NSString *sourceUri = [command argumentAtIndex: 0];
        NSString *destinationUri = [command argumentAtIndex: 1];
        NSArray *matrixArray = [command argumentAtIndex: 2];

       CGRect rect =  CGRectMake([[matrixArray objectAtIndex:0] floatValue], [[matrixArray objectAtIndex:1] floatValue],[[matrixArray objectAtIndex:2] floatValue], [[matrixArray objectAtIndex:3] floatValue]);

        [self cropImage:sourceUri toDestinationUri:destinationUri withSize:rect];
        pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:@"Image cropped"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];

}


-(void) cropImage: (NSString *)sourceUri toDestinationUri:(NSString *)destinationUri withSize:(CGRect)rect{
     UIImage *imageToCrop = [self loadImage:sourceUri];
    CGImageRef imageRef = CGImageCreateWithImageInRect([imageToCrop CGImage], rect);
    UIImage *cropped = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);

    NSError* err = nil;
    [self saveImage:cropped toFilePath:destinationUri error:&err];

}

- (void)resizeImage:(NSString *)sourceUri toDestinationUri:(NSString *)destinationUri withSize:(CGSize)size andKeepScale:(BOOL)keepScale {
    UIImage *originalImage = [self loadImage:sourceUri];

    CGSize newImageSize = size;
    CGSize imageSize = originalImage.size;
    if (keepScale) {
        newImageSize = [self estimatedScaleSize:newImageSize forImageSize:imageSize];
    }

    UIGraphicsBeginImageContextWithOptions(newImageSize, NO, 0.0);
    [originalImage drawInRect:CGRectMake(0, 0, newImageSize.width, newImageSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSError* err = nil;
    [self saveImage:resizedImage toFilePath:destinationUri error:&err];
}

- (CGSize)estimatedScaleSize:(CGSize)newSize forImageSize:(CGSize)imageSize {
    if (imageSize.width > imageSize.height) {
        newSize = CGSizeMake((imageSize.width / imageSize.height) * newSize.height, newSize.height);
    } else {
        newSize = CGSizeMake(newSize.width, (imageSize.height / imageSize.width) * newSize.width);
    }

    return newSize;
}



- (void)rotateImage:(NSString *)sourceUri toDestinationUri:(NSString *)destinationUri toAngle:(NSNumber *)angle {
    UIImage *originalImage = [self loadImage:sourceUri];


    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,originalImage.size.width, originalImage.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation([angle intValue] * M_PI / 180);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;

    //Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();

    //Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);

    //Rotate the image context
    CGContextRotateCTM(bitmap, ([angle intValue] * M_PI / 180));

    //Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-originalImage.size.width / 2, -originalImage.size.height / 2, originalImage.size.width, originalImage.size.height), [originalImage CGImage]);

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();


//    CGFloat radians = M_PI * (180-[angle intValue]) / 180;
//
//    CGImageRef cgOriginalImage = [originalImage CGImage];
//
//    float newSide = MAX([originalImage size].width, [originalImage size].height);
//    CGSize size =  CGSizeMake(newSide, newSide);
//    UIGraphicsBeginImageContext(size);
//    CGContextRef ctx = UIGraphicsGetCurrentContext();
//    CGContextTranslateCTM(ctx, newSide/2, newSide/2);
//    CGContextRotateCTM(ctx, radians);
//    CGContextDrawImage(UIGraphicsGetCurrentContext(),CGRectMake(-[originalImage size].width/2,-[originalImage size].height/2,size.width, size.height),cgOriginalImage);
//    //CGContextTranslateCTM(ctx, [image size].width/2, [image size].height/2);
//
//    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    NSError* err = nil;
    [self saveImage:newImage toFilePath:destinationUri error:&err];


}









- (BOOL)saveImage:(UIImage *)image toFilePath:(NSString *)filePath error:(NSError **)error; {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths objectAtIndex:0];
    libraryDirectory = [libraryDirectory stringByAppendingString:@"/NoCloud/"];

    NSData *imgData;
    if ([filePath containsString:@".jpg"]) {
        imgData = UIImageJPEGRepresentation(image, 0.9);
    } else {
        imgData = UIImagePNGRepresentation(image);
    }



    return [imgData writeToFile:[libraryDirectory stringByAppendingString:filePath] atomically:YES];
}

- (UIImage *)loadImage:(NSString *)filePath {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths objectAtIndex:0];
    libraryDirectory = [libraryDirectory stringByAppendingString:@"/NoCloud/"];
    UIImage* image = [UIImage imageWithContentsOfFile:[libraryDirectory stringByAppendingString:filePath]];
    if (!image) {
        return nil;
    }

    return image;
}

- (NSString *)documentsPathForFileName:(NSString *)name {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];

    return [documentsPath stringByAppendingPathComponent:name];
}

@end




/*





- (CGSize)getImageSize:(NSString *)filePath {

    CGSize imageSize;

    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef) [NSURL URLWithString:filePath], NULL);

    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache, nil];

    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
    if (imageProperties) {
        NSNumber *width = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
        NSNumber *height = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);

        imageSize = CGSizeMake([width floatValue], [height floatValue]);

        CFRelease(imageProperties);
    }

    CFRelease(imageSource);

    return imageSize;
}


- (void)doResizeImage:(NSString *)sourceUri toDestinationUri:(NSString *)destinationUri withSize:(CGSize)size {

    UIImage *originalImage = [self loadImage:sourceUri];

    CGImageRef imageRef = [originalImage CGImage];
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);

    // There's a wierdness with kCGImageAlphaNone and CGBitmapContextCreate
    // see Supported Pixel Formats in the Quartz 2D Programming Guide
    // Creating a Bitmap Graphics Context section
    // only RGB 8 bit images with alpha of kCGImageAlphaNoneSkipFirst, kCGImageAlphaNoneSkipLast, kCGImageAlphaPremultipliedFirst,
    // and kCGImageAlphaPremultipliedLast, with a few other oddball image kinds are supported
    // The images on input here are likely to be png or jpeg files
    if (alphaInfo == kCGImageAlphaNone)
        alphaInfo = kCGImageAlphaNoneSkipLast;

    // Build a bitmap context that's the size of the thumbRect
    CGContextRef bitmap = CGBitmapContextCreate(
                                                NULL,
                                                size.width,       // width
                                                size.height,      // height
                                                CGImageGetBitsPerComponent(imageRef),   // really needs to always be 8
                                                4 * size.width,   // rowbytes
                                                CGImageGetColorSpace(imageRef),
                                                alphaInfo
                                                );

    // Draw into the context, this scales the image
    CGContextDrawImage(bitmap, CGRectMake(0, 0, size.width, size.height), imageRef);

    // Get an image from the context and a UIImage
    CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    UIImage* resizedImage = [UIImage imageWithCGImage:ref];

    CGContextRelease(bitmap);   // ok if NULL
    CGImageRelease(ref);

    [self saveImage:resizedImage toFilePath:destinationUri];
}

- (void)upscaleImage:(NSString *)sourceUri toDestinationUri:(NSString *)destinationUri withSize:(CGSize)size {

    UIImage *originalImage = [self loadImage:sourceUri];
    CGImageRef cgOriginalImage = originalImage.CGImage;

    size_t bitsPerComponent = CGImageGetBitsPerComponent(cgOriginalImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgOriginalImage);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgOriginalImage);
    CGBitmapInfo info = CGImageGetBitmapInfo(cgOriginalImage);

    CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, bitsPerComponent, bytesPerRow, colorSpace, info);

    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);

    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), cgOriginalImage);

    CGImageRef cgResizedImage = CGBitmapContextCreateImage(context);

    UIImage *resizedImage = [UIImage imageWithCGImage:cgResizedImage];

    CGContextRelease(context);
    CGImageRelease(cgOriginalImage);
    CGImageRelease(cgResizedImage);

    [self saveImage:resizedImage toFilePath:destinationUri];
}

- (void)downscaleImage:(NSString *)sourceUri toDestinationUri:(NSString *)destinationUri withSize:(CGSize)size {

}

- (UIImage *)resizeImage:(UIImage *)originalImage toSize:(CGSize)size andKeepScale:(BOOL)keepScale {
    CGImageRef cgOriginalImage = originalImage.CGImage;

    NSLog(@"CDVImageProcessing - resizeImage() - image size (%fX%f)", originalImage.size.width, originalImage.size.height);
    NSLog(@"CDVImageProcessing - resizeImage() - desired size (%fX%f)", size.width, size.height);
    NSLog(@"CDVImageProcessing - resizeImage() - keepScale: %hhd", keepScale);

    if (keepScale) {
        size = [self estimatedScaleSize:size forImage:originalImage];
        NSLog(@"CDVImageProcessing - resizeImage() - scaled size (%fX%f)", size.width, size.height);
    }

    size_t bitsPerComponent = CGImageGetBitsPerComponent(cgOriginalImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgOriginalImage);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgOriginalImage);
    CGBitmapInfo info = CGImageGetBitmapInfo(cgOriginalImage);

    CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, bitsPerComponent, bytesPerRow, colorSpace, info);

    if (!context) {
        NSLog(@"CDVImageProcessing - resizeImage() - 0.1 - context IS NIL");
    }

    NSLog(@"CDVImageProcessing - resizeImage() - 0.1");

    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);

    NSLog(@"CDVImageProcessing - resizeImage() - 0.2");

    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), cgOriginalImage);

    NSLog(@"CDVImageProcessing - resizeImage() - 1");

    CGImageRef cgResizedImage = CGBitmapContextCreateImage(context);

    UIImage *resizedImage = [UIImage imageWithCGImage:cgResizedImage];

    NSLog(@"CDVImageProcessing - resizeImage() - 2");

    CGContextRelease(context);
    CGImageRelease(cgOriginalImage);
    CGImageRelease(cgResizedImage);

    NSLog(@"CDVImageProcessing - resizeImage() - 3");

    return resizedImage;
}

- (CGSize)estimatedScaleSize:(CGSize)newSize forImage:(UIImage *)image {
    if (image.size.width > image.size.height) {
        newSize = CGSizeMake((int)(image.size.width / image.size.height) * newSize.height, newSize.height);
    } else {
        newSize = CGSizeMake(newSize.width, (int)(image.size.height / image.size.width) * newSize.width);
    }

    return newSize;
}

*/