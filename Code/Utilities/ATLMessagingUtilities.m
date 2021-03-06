//
//  ATLUIMessagingUtilities.m
//  Atlas
//
//  Created by Kevin Coleman on 10/27/14.
//  Copyright (c) 2015 Layer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ATLMessagingUtilities.h"
#import "ATLErrors.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "ATLMessageCollectionViewCell.h"

NSString *const ATLMIMETypeTextPlain = @"text/plain";
NSString *const ATLMIMETypeTextHTML = @"text/HTML";
NSString *const ATLMIMETypeImagePNG = @"image/png";
NSString *const ATLMIMETypeImageHEIC = @"image/heic";
NSString *const ATLMIMETypeImageGIF = @"image/gif";
NSString *const ATLMIMETypeVideoQuickTime = @"video/quicktime";
NSString *const ATLMIMETypeImageSize = @"application/json+imageSize";
NSString *const ATLMIMETypeImageJPEG = @"image/jpeg";
NSString *const ATLMIMETypeImageJPEGPreview = @"image/jpeg+preview";
NSString *const ATLMIMETypeImageGIFPreview = @"image/gif+preview";
NSString *const ATLMIMETypeLocation = @"location/coordinate";
NSString *const ATLMIMETypeDate = @"text/date";
NSString *const ATLMIMETypeVideoMP4 = @"video/mp4";
NSUInteger const ATLDefaultThumbnailSize = 512;
NSUInteger const ATLDefaultGIFThumbnailSize = 64;

NSString *const ATLPasteboardImageKey = @"image";
NSString *const ATLImagePreviewWidthKey = @"width";
NSString *const ATLImagePreviewHeightKey = @"height";
NSString *const ATLLocationLatitudeKey = @"lat";
NSString *const ATLLocationLongitudeKey = @"lon";

NSString *const ATLUserNotificationInlineReplyActionIdentifier = @"layer:///actions/inline-reply";
NSString *const ATLUserNotificationDefaultActionsCategoryIdentifier = @"layer:///categories/default";

#pragma mark - Push Support

UIMutableUserNotificationCategory *ATLDefaultUserNotificationCategory()
{
    UIMutableUserNotificationAction *replyAction = [UIMutableUserNotificationAction new];
    replyAction.identifier = ATLUserNotificationInlineReplyActionIdentifier;
    replyAction.title = @"Reply";
    replyAction.activationMode = UIUserNotificationActivationModeBackground;
    replyAction.authenticationRequired = NO;
    replyAction.behavior = UIUserNotificationActionBehaviorTextInput;
    
    UIMutableUserNotificationCategory *category = [UIMutableUserNotificationCategory new];
    category.identifier = ATLUserNotificationDefaultActionsCategoryIdentifier;
    [category setActions:@[ replyAction ] forContext:UIUserNotificationActionContextDefault];
    
    return category;
}

#pragma mark - Max Cell Dimensions

CGFloat ATLMaxCellWidth()
{
    return 215;
}

CGFloat ATLMaxCellHeight()
{
    return 300;
}

#pragma mark - Private Image Utilities

CGSize ATLSizeProportionallyConstrainedToSize(CGSize nativeSize, CGSize maxSize)
{
    if (nativeSize.width < maxSize.width && nativeSize.height < maxSize.height) return nativeSize;
    CGSize itemSize;
    CGFloat widthScale = maxSize.width / nativeSize.width;
    CGFloat heightScale = maxSize.height / nativeSize.height;
    if (heightScale < widthScale) {
        itemSize = CGSizeMake(nativeSize.width * heightScale, maxSize.height);
    } else {
        itemSize = CGSizeMake(maxSize.width, nativeSize.height * widthScale);
    }
    return itemSize;
}

UIImage *ATLAdjustOrientationForImage(UIImage *originalImage)
{
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    [originalImage drawInRect:(CGRect){0, 0, originalImage.size}];
    UIImage *fixedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return fixedImage;
}

#pragma mark - Image Utilities

CGSize ATLImageSizeForData(NSData *data)
{
    UIImage *image = [UIImage imageWithData:data];
    return ATLImageSize(image);
}

CGSize ATLImageSizeForJSONData(NSData *data)
{
    NSError *error;
    NSDictionary *sizeDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (!sizeDictionary) {
        NSLog(@"failed to deserialize image dimensions JSON with %@", error);
        return CGSizeZero;
    }
    CGFloat width = [sizeDictionary[ATLImagePreviewWidthKey] floatValue];
    CGFloat height = [sizeDictionary[ATLImagePreviewHeightKey] floatValue];
    return CGSizeMake(width, height);
}

CGSize ATLImageSize(UIImage *image)
{
    CGSize maxSize = CGSizeMake(ATLMaxCellWidth(), ATLMaxCellHeight());
    CGSize itemSize = ATLSizeProportionallyConstrainedToSize(image.size, maxSize);
    return itemSize;
}

CGSize ATLConstrainImageSizeToCellSize(CGSize imageSize)
{
    CGSize maxSize = CGSizeMake(ATLMaxCellWidth(), ATLMaxCellHeight());
    CGSize itemSize = ATLSizeProportionallyConstrainedToSize(imageSize, maxSize);
    return itemSize;
}

CGSize ATLTextPlainSize(NSString *text, UIFont *font)
{
    CGRect rect = [text boundingRectWithSize:CGSizeMake(ATLMaxCellWidth(), CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{NSFontAttributeName: font}
                                     context:nil];
    return rect.size;
}

CGRect ATLImageRectConstrainedToSize(CGSize imageSize, CGSize maxSize)
{
    CGSize itemSize = ATLSizeProportionallyConstrainedToSize(imageSize, maxSize);
    CGRect thumbRect = {0, 0, itemSize};
    return thumbRect;
}

CGFloat ATLDegreeToRadians(CGFloat degrees)
{
    return ((M_PI * degrees)/ 180);
}

#pragma mark - Conversation Helpers

LYRIdentity *ATLIdentityFromSet(NSString *userID, NSSet *participants)
{
    for (LYRIdentity *identity in participants) {
        if ([identity.userID isEqualToString:userID]) {
            return identity;
        }
    }
    return nil;
}


#pragma mark - Private Message Part Helpers

CGSize  ATLSizeFromOriginalSizeWithConstraint(CGSize originalSize, CGFloat constraint)
{
    if (originalSize.height > constraint && (originalSize.height > originalSize.width)) {
        CGFloat heightRatio = constraint / originalSize.height;
        return CGSizeMake(originalSize.width * heightRatio, constraint);
    } else if (originalSize.width > constraint) {
        CGFloat widthRatio = constraint / originalSize.width;
        return CGSizeMake(constraint, originalSize.height * widthRatio);
    }
    return originalSize;
}

#pragma mark - Message Utilities

LYRMessage *ATLMessageForParts(LYRClient *layerClient, NSArray *messageParts, NSString *pushText, NSString *pushSound)
{
    LYRPushNotificationConfiguration *defaultConfiguration = [LYRPushNotificationConfiguration new];
    defaultConfiguration.alert = pushText;
    defaultConfiguration.sound = pushSound;
    defaultConfiguration.category = ATLUserNotificationDefaultActionsCategoryIdentifier;
    
    LYRMessageOptions *messageOptions = [LYRMessageOptions new];
    messageOptions.pushNotificationConfiguration = defaultConfiguration;
    NSError *error;
    LYRMessage *message = [layerClient newMessageWithParts:messageParts options:messageOptions error:&error];
    if (error) {
        return nil;
    }
    return message;
}

#pragma mark - Message Parts Utilities

NSArray *ATLMessagePartsWithMediaAttachment(ATLMediaAttachment *mediaAttachment)
{
    NSMutableArray *messageParts = [NSMutableArray array];
    if (!mediaAttachment.mediaInputStream) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot create an LYRMessagePart with `nil` mediaInputStream." userInfo:nil];
    }
    
    if ([mediaAttachment.mediaMIMEType isEqualToString:ATLMIMETypeTextPlain]) {
        return @[[LYRMessagePart messagePartWithText:mediaAttachment.textRepresentation]];
    }
    
    // Create the message part for the main media (should be on index zero).
    [messageParts addObject:[LYRMessagePart messagePartWithMIMEType:mediaAttachment.mediaMIMEType stream:mediaAttachment.mediaInputStream]];
    
    // If there's a thumbnail in the attachment, add it to the message parts on the second index.
    if (mediaAttachment.thumbnailInputStream) {
        [messageParts addObject:[LYRMessagePart messagePartWithMIMEType:mediaAttachment.thumbnailMIMEType stream:mediaAttachment.thumbnailInputStream]];
    }

    // If there's any additional metadata, add it to the message parts on the third index.
    if (mediaAttachment.metadataInputStream) {
        [messageParts addObject:[LYRMessagePart messagePartWithMIMEType:mediaAttachment.metadataMIMEType stream:mediaAttachment.metadataInputStream]];
    }
    return messageParts;
}

LYRMessagePart *ATLMessagePartForMIMEType(LYRMessage *message, NSString *MIMEType)
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"MIMEType == %@", MIMEType];
    return [[message.parts filteredArrayUsingPredicate:predicate] firstObject];
}

#pragma mark - Image Capture Utilities

void ATLAssetURLOfLastPhotoTaken(void(^completionHandler)(NSURL *assetURL, NSError *error))
{
    // Credit goes to @iBrad Apps on Stack Overflow
    // http://stackoverflow.com/questions/8867496/get-last-image-from-photos-app
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    // Enumerate just the photos and videos group by using ALAssetsGroupSavedPhotos.
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // When done, the group enumeration block is called another time with group set to nil.
        if (!group) return;

        // Within the group enumeration block, filter to enumerate just photos.
        [group setAssetsFilter:[ALAssetsFilter allAssets]];

        if ([group numberOfAssets] == 0) {
            completionHandler(nil, [NSError errorWithDomain:ATLErrorDomain code:ATLErrorNoPhotos userInfo:@{NSLocalizedDescriptionKey: @"There are no photos."}]);
            return;
        }
        
        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *innerStop) {
            // When done, the asset enumeration block is called another time with result set to nil.
            if (!result) return;

            // Stop the enumerations
            *innerStop = YES;
            *stop = YES;
            completionHandler(result.defaultRepresentation.url, nil);
        }];
    } failureBlock:^(NSError *error) {
        completionHandler(nil, error);
    }];
}

void ATLLastPhotoTaken(void(^completionHandler)(UIImage *image, NSError *error))
{
    // Credit goes to @iBrad Apps on Stack Overflow
    // http://stackoverflow.com/questions/8867496/get-last-image-from-photos-app
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    // Enumerate just the photos and videos group by using ALAssetsGroupSavedPhotos.
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // When done, the group enumeration block is called another time with group set to nil.
        if (!group) return;
        
        // Within the group enumeration block, filter to enumerate just photos.
        [group setAssetsFilter:[ALAssetsFilter allPhotos]];
        
        if ([group numberOfAssets] == 0) {
            completionHandler(nil, [NSError errorWithDomain:ATLErrorDomain code:ATLErrorNoPhotos userInfo:@{NSLocalizedDescriptionKey: @"There are no photos."}]);
            return;
        }
        
        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *innerStop) {
            // When done, the asset enumeration block is called another time with result set to nil.
            if (!result) return;
            
            ALAssetRepresentation *representation = [result defaultRepresentation];
            UIImage *latestPhoto = [UIImage imageWithCGImage:[representation fullScreenImage]];
            
            // Stop the enumerations
            *innerStop = YES;
            *stop = YES;
            completionHandler(latestPhoto, nil);
        }];
    } failureBlock:^(NSError *error) {
        completionHandler(nil, error);
    }];
}

UIImage *ATLPinPhotoForSnapshot(MKMapSnapshot *snapshot, CLLocationCoordinate2D location)
{
    // Create a pin image.
    MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];
    UIImage *pinImage = pin.image;
    
    // Draw the image.
    UIImage *image = snapshot.image;
    UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
    [image drawAtPoint:CGPointMake(0, 0)];
    
    // Draw the pin.
    CGPoint point = [snapshot pointForCoordinate:location];
    [pinImage drawAtPoint:CGPointMake(point.x, point.y - pinImage.size.height)];
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return finalImage;
}

NSArray *ATLTextCheckingResultsForText(NSString *text, NSTextCheckingType linkTypes)
{
    if (!text) return nil;
    
    NSError *error;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:linkTypes
                                                               error:&error];
    if (error) return nil;
    return [detector matchesInString:text options:kNilOptions range:NSMakeRange(0, text.length)];
}

NSBundle *ATLResourcesBundle(void)
{
    // CocoaPods resource bundle
    NSBundle *bundlePath = [NSBundle bundleWithIdentifier:@"org.cocoapods.Atlas"];
    NSString *path = [bundlePath pathForResource:@"AtlasResource" ofType:@"bundle"];
    NSBundle *resourcesBundle = [NSBundle bundleWithPath:path];
    if (resourcesBundle) {
        return resourcesBundle;
    }
    // Carthage resources
    NSBundle *atlasBundle = [NSBundle bundleWithIdentifier:@"com.layer.Atlas"];
    if (atlasBundle) {
        return atlasBundle;
    }
    
    NSString *resourcesBundlePath = [[NSBundle mainBundle] pathForResource:@"AtlasResource" ofType:@"bundle"];
    if (resourcesBundlePath) {
        return [NSBundle bundleWithPath:resourcesBundlePath];
    } else {
        NSBundle *parentBundle = [NSBundle bundleForClass:[ATLMessageCollectionViewCell class]];
        NSBundle *resourcesBundle = [NSBundle bundleWithPath:[parentBundle pathForResource:@"AtlasResource" ofType:@"bundle"]];
        if (!resourcesBundle) [NSException raise:NSInternalInconsistencyException format:@"Failed to locate `resources.bundle` in %@", resourcesBundle];
        return resourcesBundle;
    }
}
