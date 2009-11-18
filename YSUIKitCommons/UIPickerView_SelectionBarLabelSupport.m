// UIPickerView_SelectionBarLabelSupport.m
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

#import "UIPickerView_SelectionBarLabelSupport.h"


// used to find existing component labels among UIPicker's children
#define kMagicTag 89464534
// a private UIKit implementation detail, but we do degrade gracefully in case it stops working
#define kSelectionBarClassName @"_UIPickerViewSelectionBar"

// used to sort per-component selection bars in a left-to-right order
static NSInteger compareViews(UIView *a, UIView *b, void *context) {
	CGFloat ax = a.frame.origin.x, bx = b.frame.origin.x;
	if (ax < bx)
		return -1;
	else if (ax > bx)
		return 1;
	else
		return 0;
}


@implementation UIPickerView (SelectionBarLabelSupport)

- (UILabel *)shadedLabelWithText:(NSString *)label ofSize:(CGFloat)pointSize {
	UIFont *font = [UIFont boldSystemFontOfSize:pointSize];
	CGSize size = [label sizeWithFont:font];
	UILabel *labelView = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)] autorelease];
	labelView.font = font;
	labelView.adjustsFontSizeToFitWidth = NO;
	labelView.shadowOffset = CGSizeMake(1, 1);
	labelView.textColor = [UIColor blackColor];
	labelView.shadowColor = [UIColor whiteColor];
	labelView.opaque = NO;
	labelView.backgroundColor = [UIColor clearColor];
	labelView.text = label;
	labelView.userInteractionEnabled = NO;
	return labelView;
}

- (UIView *)viewForShadedLabelWithText:(NSString *)title ofSize:(CGFloat)pointSize forComponent:(NSInteger)component rightAlignedAt:(CGFloat)offset reusingView:(UIView *)view {
	UILabel *label;
	UIView *wrapper;
	if (view != nil) {
		wrapper = view;
		label = (UILabel *)[wrapper viewWithTag:1];
	} else {
		CGFloat width = [self.delegate pickerView:self widthForComponent:component];
		
		label = [self shadedLabelWithText:title ofSize:pointSize];
		CGSize size = label.frame.size;
		label.frame = CGRectMake(0, 0, offset, size.height);
		label.tag = 1;
		label.textAlignment = UITextAlignmentRight;
		label.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		
		wrapper = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, width, size.height)] autorelease];
		wrapper.autoresizesSubviews = NO;
		wrapper.userInteractionEnabled = NO;
		[wrapper addSubview:label];
	}
	label.text = title;
	return wrapper;
}

- (void)addLabel:(NSString *)label ofSize:(CGFloat)pointSize toComponent:(NSInteger)component leftAlignedAt:(CGFloat)offset baselineAlignedWithFontOfSize:(CGFloat)titlePointSize {
	NSParameterAssert(component < [self numberOfComponents]);
	
	NSInteger tag = kMagicTag + component;
	UILabel *oldLabel = (UILabel *) [self viewWithTag:tag];
	if (oldLabel != nil && [oldLabel.text isEqualToString:label])
		return;
	
	NSInteger n = [self numberOfComponents];
	CGFloat total = 0.0;
	for (int c = 0; c < component; c++)
		offset += [self.delegate pickerView:self widthForComponent:c];
	for (int c = 0; c < n; c++)
		total += [self.delegate pickerView:self widthForComponent:c];
	offset += (self.bounds.size.width - total) / 2;
	
	offset += 2 * component; // internal UIPicker metrics, measured on a screenshot
	offset += 4; // add a gap
	
	CGFloat baselineHeight = [@"X" sizeWithFont:[UIFont boldSystemFontOfSize:titlePointSize]].height;
	CGFloat labelHeight = [@"X" sizeWithFont:[UIFont boldSystemFontOfSize:pointSize]].height;
	
	UILabel *labelView = [self shadedLabelWithText:label ofSize:pointSize];
	labelView.frame = CGRectMake(offset,
								 (self.bounds.size.height - baselineHeight) / 2 + (baselineHeight - labelHeight) - 1,
								 labelView.frame.size.width,
								 labelView.frame.size.height);
	labelView.tag = tag;

	UIView *selectionBarView = nil;
	NSMutableArray *selectionBars = [NSMutableArray array];
	for (UIView *subview in self.subviews) {
		if ([[[subview class] description] isEqualToString:kSelectionBarClassName])
			[selectionBars addObject:subview];
	}
	if ([selectionBars count] == n) {
		[selectionBars sortUsingFunction:compareViews context:NULL];
		selectionBarView = [selectionBars objectAtIndex:component];
	}
	if (oldLabel != nil) {
		[UIView beginAnimations:nil context:oldLabel];
		[UIView setAnimationDuration:0.25];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(YS_barLabelHideAnimationDidStop:finished:context:)];
		oldLabel.alpha = 0.0f;
		[UIView commitAnimations];
	}
	// if the selection bar hack stops working, degrade to using 60% alpha
	CGFloat normalAlpha = (selectionBarView == nil ? 0.6f : 1.0f);
	if (selectionBarView != nil)
		[self insertSubview:labelView aboveSubview:selectionBarView];
	else
		[self addSubview:labelView];
	if (oldLabel != nil) {
		labelView.alpha = 0.0f;
		[UIView beginAnimations:nil context:oldLabel];
		[UIView setAnimationDuration:0.25];
		[UIView setAnimationDelay:0.25];
		labelView.alpha = normalAlpha;
		[UIView commitAnimations];
	} else {
		labelView.alpha = normalAlpha;
	}
}

- (void)YS_barLabelHideAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(UIView *)oldLabel {
	[oldLabel removeFromSuperview];
}

@end
