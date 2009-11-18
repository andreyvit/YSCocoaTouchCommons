// UIPickerView_SelectionBarLabelSupport.h
//
// This file adds a new API to UIPickerView that allows to easily recreate
// the look and feel of UIDatePicker labeled components.
//
// Copyright (c) 2009, Andrey Tarantsov <andreyvit@gmail.com>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


#import <Foundation/Foundation.h>


// useful constants for your font size-related code
#define kPickerViewDefaultTitleFontSize 20.0f
#define kDatePickerTitleFontSize 25.0f
#define kDatePickerLabelFontSize 21.0f


@interface UIPickerView (SelectionBarLabelSupport)

// The primary API to add a label to the given component.
// If you want to match the look of UIDatePicker, use 21pt as pointSize and 25pt as the font size of your content views (titlePointSize).
// (Note that UIPickerView defaults to 20pt items, so you need to use custom views. See a helper method below.)
// Repeated calls will change the label with an animation effect similar to UIDatePicker's one.
- (void)addLabel:(NSString *)label ofSize:(CGFloat)pointSize toComponent:(NSInteger)component leftAlignedAt:(CGFloat)offset baselineAlignedWithFontOfSize:(CGFloat)titlePointSize;

// A helper method for your delegate's "pickerView:viewForRow:forComponent:reusingView:".
// Creates a propertly positioned right-aligned label of the given size, and also handles reuse.
// The actual UILabel is a child of the returned view, use [returnedView viewWithTag:1] to retrieve the label.
- (UIView *)viewForShadedLabelWithText:(NSString *)label ofSize:(CGFloat)pointSize forComponent:(NSInteger)component rightAlignedAt:(CGFloat)offset reusingView:(UIView *)view;

// Creates a shaded label of the given size, looking similar to the labels used by UIPickerView/UIDatePicker.
- (UILabel *)shadedLabelWithText:(NSString *)label ofSize:(CGFloat)pointSize;

@end
