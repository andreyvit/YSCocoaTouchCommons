
#import "ATPageView.h"

#define kUseDebugColoring 0

enum {
	TAG_PAGE_SCROLL_VIEW = 101,
	TAG_WRAPPER_VIEW
};


static CGRect zoomRectForScaleWithCenter(float scale, CGPoint center, UIScrollView *aScrollView) {
	CGRect zoomRect;
	zoomRect.size.width  = aScrollView.frame.size.width  / scale;
	zoomRect.size.height = aScrollView.frame.size.height / scale;
	zoomRect.origin.x = center.x - (zoomRect.size.width  / 2.0);
	zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0);
	return zoomRect;
}

static CGRect fitSizeInRect(CGSize targetSize, CGRect rect, BOOL centerIfSmall) {
	CGSize size;
	if (centerIfSmall && targetSize.width < rect.size.width && targetSize.height < rect.size.height)
		size = targetSize;
		else {
			CGFloat ratioX = rect.size.width / targetSize.width, ratioY = rect.size.height / targetSize.height;
			size = (ratioX < ratioY ?
					CGSizeMake(rect.size.width, ratioX * targetSize.height) :
					CGSizeMake(ratioY * targetSize.width, rect.size.height));
		}
	return CGRectMake(rect.origin.x + (rect.size.width - size.width) / 2,
					  rect.origin.y + (rect.size.height - size.height) / 2,
					  size.width, size.height);
}



#pragma mark -
@interface ATPageView () <UIScrollViewDelegate>

- (void)updateContentSize;

- (void)enqueuePageViewsInCacheIndexRange:(NSRange)range;

- (void)enqueuePageView:(UIView *)view;

- (void)updateCurrentPageIndex:(NSInteger)newIndex;

- (void)loadAndLayoutPageAtIndex:(NSInteger)index;

- (void)resetPageViewCache;

- (void)shiftCachedPageViewsArrayBy:(NSInteger)delta;

- (UIView *)viewForPageAtIndex:(NSInteger)index load:(BOOL)load;

- (UIView *)loadViewForPageAtIndex:(NSUInteger)pageIndex;

- (void)preloadPageViews;

- (UIView *)contentViewForPageView:(UIView *)view;

- (void)layoutContentViewAndResetZoomScaleForPageAtIndex:(NSUInteger)pageIndex;

- (void)updateContentInsetForPageScrollView:(UIScrollView *)pageScrollView;

@end



#pragma mark -
@implementation ATPageView


@synthesize delegate=delegate_;
@synthesize pagingScrollView=pagingScrollView_;
@synthesize currentPageIndex=currentPageIndex_;
@synthesize pageGap=pageGap_;
@synthesize neighbourPageViewsToPreload=neighbourPageViewsToPreload_;
@synthesize neighbourPageViewsToCache=neighbourPageViewsToCache_;
@synthesize numberOfPages=cachedPageCount_;


#pragma mark -
#pragma mark ATPageView view methods


- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
		pageGap_ = 20.0f;
		neighbourPageViewsToPreload_ = 1;
		neighbourPageViewsToCache_ = 2;
		
		reusablePageViews_ = [[NSMutableArray alloc] init];
		cachedPageViews_   = [[NSMutableArray alloc] init];
		
		pagingScrollView_ = [[UIScrollView alloc] init];
		pagingScrollView_.pagingEnabled = YES;
		pagingScrollView_.delegate = self;
		pagingScrollView_.showsHorizontalScrollIndicator = NO;
		pagingScrollView_.showsVerticalScrollIndicator = NO;
#if kUseDebugColoring
		pagingScrollView_.backgroundColor = [UIColor cyanColor];
#endif
		[self addSubview:pagingScrollView_];
		
		rotationInProgress_ = NO;
		
		[self resetPageViewCache];
    }
    return self;
}


- (void)dealloc {
	pagingScrollView_.delegate = nil;
	[pagingScrollView_ release], pagingScrollView_ = nil;
	delegate_ = nil;
    [super dealloc];
}


- (void)layoutSubviews {
	//NSLog(@"layoutSubviews");
	CGRect r = self.bounds;
	CGPoint origin = pagingScrollView_.bounds.origin;
	pagingScrollView_.bounds = CGRectMake(origin.x, origin.y, r.size.width + pageGap_, r.size.height);
	pagingScrollView_.center = CGPointMake(r.size.width / 2, r.size.height / 2);
	[self updateContentSize];
}


#pragma mark -
#pragma mark ATPageView public methods


- (NSInteger)numberOfPages {
	return [delegate_ numberOfPagesInPageView:self];
}


- (void)reload {
	[self resetPageViewCache];
	currentPageIndex_ = 0;
	cachedPageCount_ = [delegate_ numberOfPagesInPageView:self];
	[self updateContentSize];
	[self preloadPageViews];
}


- (NSInteger)currentPageIndex {
	return currentPageIndex_;
}


- (void)setCurrentPageIndex:(NSInteger)newIndex {
	[self setCurrentPageIndex:newIndex animated:NO];
}


- (void)setCurrentPageIndex:(NSInteger)newIndex animated:(BOOL)animated {
	[self loadAndLayoutPageAtIndex:newIndex];
	[pagingScrollView_ setContentOffset:CGPointMake(newIndex * pagingScrollView_.frame.size.width, 0) animated:animated];
}


- (void)setNeighbourPageViewsToPreload:(NSInteger)newValue {
	neighbourPageViewsToPreload_ = newValue;
	if (newValue + 1 > neighbourPageViewsToCache_)
		self.neighbourPageViewsToCache = newValue + 1;
	else
		[self preloadPageViews];
}


- (void)setNeighbourPageViewsToCache:(NSInteger)newValue {
	neighbourPageViewsToCache_ = newValue;
	[self resetPageViewCache];
	
	if (neighbourPageViewsToPreload_ > newValue - 1)
		self.neighbourPageViewsToPreload = newValue - 1;
	else
		[self reload];
}


- (UIView *)dequeueReusablePage {
	if ([reusablePageViews_ count] == 0)
		return nil;
	UIView *retVal = [reusablePageViews_ lastObject];
	[reusablePageViews_ removeLastObject];
	return [self contentViewForPageView:retVal];
}


#pragma mark -
#pragma mark ATPageView private methods: page view cache


- (void)enqueuePageViewsInCacheIndexRange:(NSRange)range {
	NSInteger end = range.location + range.length;
	for (NSInteger i = range.location; i < end; ++i) {
		id obj = [cachedPageViews_ objectAtIndex:i];
		if (obj != [NSNull null])
			[self enqueuePageView:obj];
	}
}


- (void)resetPageViewCache {
	[self enqueuePageViewsInCacheIndexRange:NSMakeRange(0, [cachedPageViews_ count])];
	[cachedPageViews_ removeAllObjects];
	for (NSInteger i = 0; i < neighbourPageViewsToCache_ * 2 + 1; ++i)
		[cachedPageViews_ addObject:[NSNull null]];
}

- (void)shiftCachedPageViewsArrayBy:(NSInteger)delta {
	NSInteger absdelta = (delta >= 0 ? delta : -delta);
	NSInteger count = [cachedPageViews_ count];
	
	if (absdelta >= count) {
		[self resetPageViewCache];
	} else if (delta > 0) {
		NSRange range = NSMakeRange(0, delta);
		[self enqueuePageViewsInCacheIndexRange:range];
		[cachedPageViews_ removeObjectsInRange:range];
		for (NSInteger i = 0; i < delta; ++i)
			[cachedPageViews_ addObject:[NSNull null]];
	} else if (delta < 0) {
		NSRange range = NSMakeRange(count - absdelta, absdelta);
		[self enqueuePageViewsInCacheIndexRange:range];
		[cachedPageViews_ removeObjectsInRange:range];
		for (NSInteger i = 0; i < absdelta; ++i)
			[cachedPageViews_ insertObject:[NSNull null] atIndex:0];
	}
}


- (void)enqueuePageView:(UIView *)view {
	[reusablePageViews_ addObject:view];
}


- (UIView *)viewForPageAtIndex:(NSInteger)index load:(BOOL)load {
	NSInteger first = currentPageIndex_ - neighbourPageViewsToCache_;
	NSInteger last = currentPageIndex_ + neighbourPageViewsToCache_;
	if (index < first || index > last) {
		NSAssert3(load == NO, @"Attempt to load a page at index %d outside of cachable range (%d .. %d)",
				  index, first, last);
		return nil;
	}
	if (index < 0 || index > cachedPageCount_)
		return nil; // q: ok if load==YES in this case?
	id obj = [cachedPageViews_ objectAtIndex:index - first];
	if (obj != [NSNull null])
		return obj;
	else if (!load)
		return nil;
	else {
		UIView *view = [self loadViewForPageAtIndex:index];
		[cachedPageViews_ replaceObjectAtIndex:index - first withObject:view];
		[pagingScrollView_ addSubview:view];
		return view;
	}
}


#pragma mark -
#pragma mark ATPageView private methods: outer scroll view layouting


- (void)updateContentSize {
	CGRect r = self.bounds;
	NSInteger n = [delegate_ numberOfPagesInPageView:self];
	CGSize cs = CGSizeMake((r.size.width + pageGap_) * n , r.size.height);
	if (!CGSizeEqualToSize(pagingScrollView_.contentSize, cs)) {
		NSLog(@"Updated content size to %@", NSStringFromCGSize(cs));
		pagingScrollView_.contentSize = cs;
	}
}


#pragma mark -
#pragma mark ATPageView private methods: page creation and layouting


- (UIView *)loadViewForPageAtIndex:(NSUInteger)pageIndex {
	UIView *contentView = [delegate_ pageView:self viewForPageAtIndex:pageIndex];
	
	UIView *wrapperView = [[[UIView alloc] init] autorelease];
	wrapperView.tag = TAG_WRAPPER_VIEW;
	[wrapperView addSubview:contentView];
	
	UIScrollView *pageScrollView = [[[UIScrollView alloc] init] autorelease];
	pageScrollView.tag = TAG_PAGE_SCROLL_VIEW;
	pageScrollView.delegate = self;
	pageScrollView.contentSize = contentView.frame.size;
	pageScrollView.minimumZoomScale = 1.0f;
	pageScrollView.maximumZoomScale = 10.0f;
	pageScrollView.bouncesZoom = YES;
	[pageScrollView addSubview:wrapperView];

#if kUseDebugColoring
	wrapperView.backgroundColor = [UIColor orangeColor];
	pageScrollView.backgroundColor = [UIColor magentaColor];
#endif
	
	NSLog(@"Loaded view for page %d", pageIndex);
	return pageScrollView;
}


- (UIView *)contentViewForPageView:(UIView *)view {
	return [[view viewWithTag:TAG_WRAPPER_VIEW].subviews objectAtIndex:0];
}


- (void)loadAndLayoutPageAtIndex:(NSInteger)index {
	NSLog(@"loadAndLayoutPageAtIndex: %d", index);
	UIView *pageView = [self viewForPageAtIndex:index load:YES];
	CGSize pageSize = self.bounds.size;
	pageView.frame = CGRectMake(index * (pageSize.width + pageGap_) + pageGap_/2, 0, pageSize.width, pageSize.height);
	[self layoutContentViewAndResetZoomScaleForPageAtIndex:index];
}


- (void)layoutContentViewAndResetZoomScaleForPageAtIndex:(NSUInteger)pageIndex {
	NSLog(@"layoutPageImageViewAndResetZoomScale: %d", pageIndex);
	UIView *pageView = [self viewForPageAtIndex:pageIndex load:NO];
	if (pageView == nil)
		return;
	
	CGSize pageSize = self.bounds.size;
	
	UIScrollView *pageScrollView = (UIScrollView *)[pageView viewWithTag:TAG_PAGE_SCROLL_VIEW];
	UIView *wrapperView = [pageScrollView viewWithTag:TAG_WRAPPER_VIEW];
	
	pageScrollView.zoomScale = 1.0f;
	pageScrollView.contentSize = CGSizeMake(pageSize.width, pageSize.height);

	wrapperView.center = CGPointMake(pageSize.width / 2.0, pageSize.height / 2.0);
	
	[self updateContentInsetForPageScrollView:pageScrollView];
}


- (void)updateContentInsetForPageScrollView:(UIScrollView *)pageScrollView {
	UIView *imageView = [self contentViewForPageView:pageScrollView];
	UIView *wrapperView = [pageScrollView viewWithTag:TAG_WRAPPER_VIEW];
	
	CGSize pageSize = self.bounds.size;
	CGSize imageSize = imageView.bounds.size;
	
	//CGRect initialImageRect = fitSizeInRect(imageSize, CGRectMake(0, 0, pageSize.width, pageSize.height), YES);
	
	float zoomScale = pageScrollView.zoomScale;
	//CGSize zoomedImageSize = CGSizeMake(initialImageRect.size.width * zoomScale, initialImageRect.size.height * zoomScale);
	CGSize wrapperSize = CGSizeMake(pageSize.width, pageSize.height);
	//	CGSize wrapperSize = CGSizeMake(MAX(pageSize.width, zoomedImageSize.width),
	//									MAX(pageSize.height, zoomedImageSize.height));
	
	CGRect rect = fitSizeInRect(imageSize, CGRectMake(0, 0, wrapperSize.width, wrapperSize.height), YES);
	imageView.bounds = CGRectMake(0, 0, rect.size.width, rect.size.height);
	imageView.center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
	
	CGSize prevWrapperSize = wrapperView.bounds.size;
	wrapperView.bounds = CGRectMake(0, 0, wrapperSize.width, wrapperSize.height);
	
	//CGSize wrapperSizeDelta = CGSizeMake(wrapperSize.width - prevWrapperSize.width, wrapperSize.height - prevWrapperSize.height);
	CGPoint prevOffset = pageScrollView.contentOffset;
	//	pageScrollView.contentOffset = CGPointMake(prevOffset.x + wrapperSizeDelta.width / 2.0,
	//											   prevOffset.y + wrapperSizeDelta.height / 2.0);
	//	pageScrollView.contentSize = wrapperSize;
	
	NSLog(@"UPD. zoomScale = %f. contentOffset: %@ => %@. contentSize: %@.", zoomScale,
		  NSStringFromCGPoint(prevOffset),
		  NSStringFromCGPoint(pageScrollView.contentOffset),
		  NSStringFromCGSize(pageScrollView.contentSize)
		  );
	NSLog(@"WRAPPER center: %@, size: %@ => %@. IMAGE center: %@ size: %@.",
		  NSStringFromCGPoint(wrapperView.center),
		  NSStringFromCGSize(prevWrapperSize),
		  NSStringFromCGSize(wrapperView.bounds.size),
		  NSStringFromCGPoint(imageView.center),
		  NSStringFromCGSize(imageView.bounds.size)
		  );
	
	//	if (imageSize.width <= pageSize.width && imageSize.height < pageSize.height) {
	//		
	//		CGFloat topInset = MAX(0.0, (pageSize.height - zoomedImageSize.height) / 2.0);
	//		CGFloat sideInset = MAX(0.0, (pageSize.width - PAGEGAP - zoomedImageSize.width) / 2.0);
	//		
	//		imageView.bounds = CGRectMake(sideInset, topInset, imageSize.width, imageSize.height);
	//		
	//		// remove or reintroduce excessive size here
	//		// if zoomedImageSize.height > pageSize.height, then no exceessive space is needed
	//		// 
	//		
	//		
	////		CGSize oldContentSize = pageScrollView.contentSize;
	////		if (targetContentSize.width != oldContentSize.width || targetContentSize.height != oldContentSize.height)
	////			pageScrollView.contentSize = targetContentSize;
	//		
	////		CGSize contentSizeDelta = CGSizeMake(targetContentSize.width - oldContentSize.width,
	////											 targetContentSize.height - oldContentSize.height);
	//
	//		CGPoint oldOffset = pageScrollView.contentOffset;
	////		pageScrollView.contentOffset = CGPointMake(oldOffset.x + contentSizeDelta.width / 2.0,
	////												   oldOffset.y + contentSizeDelta.height / 2.0);
	//		
	//		CGPoint oldCenter = imageView.center;
	////		imageView.center = CGPointMake(oldCenter.x - contentSizeDelta.width / 2.0,
	////									   oldCenter.y - contentSizeDelta.height / 2.0);
	//
	//		
	//		NSLog(@"contentSize %@ => %@, contentOffset %@ => %@",
	//			  NSStringFromCGSize(oldContentSize),
	//			  NSStringFromCGSize(targetContentSize),
	//			  NSStringFromCGPoint(oldOffset),
	//			  NSStringFromCGPoint(pageScrollView.contentOffset));
	//		
	//		
	//		if (topInset < 0.0) topInset = 0.0;
	//		if (sideInset < 0.0) sideInset = 0.0;
	//		
	////		UIEdgeInsets oldInsets = pageScrollView.contentInset;
	////		CGFloat sideInsetDelta = sideInset - oldInsets.left, topInsetDelta = topInset - oldInsets.top;
	////		pageScrollView.contentInset = UIEdgeInsetsMake(topInset, sideInset, topInset, sideInset);
	////		CGRect rect = CGRectMake(sideInset, topInset, zoomedImageSize.width, zoomedImageSize.height);
	////		imageView.center = CGPointMake(160 + imageSize.width / 2.0 * (zoomScale - 1),
	////									   240 + imageSize.height / 2.0 * (zoomScale - 1));
	//		
	//		
	////		pageScrollView.contentOffset = CGPointMake(oldOffset.x + sideInsetDelta, oldOffset.y + topInsetDelta);
	////		pageScrollView.contentOffset = oldOffset;
	//	}
}


#pragma mark -
#pragma mark ATPageView private methods: current page index changes


- (void)preloadPageViews {
	NSInteger first = currentPageIndex_ - neighbourPageViewsToPreload_;
	NSInteger last  = currentPageIndex_ + neighbourPageViewsToPreload_;
	for (NSInteger index = first; index <= last; ++index)
		if (index >= 0 && index < cachedPageCount_)
			[self loadAndLayoutPageAtIndex:index];
}


- (void)updateCurrentPageIndex:(NSInteger)newIndex {
	NSLog(@"updateCurrentPageIndex: %d", newIndex);
	[self shiftCachedPageViewsArrayBy:newIndex - currentPageIndex_];
	currentPageIndex_ = newIndex;
	[self preloadPageViews];
	[delegate_ currentPageIndexDidChangeInPageView:self];
}


#pragma mark -
#pragma mark ATPageView: scroll view delegate methods


- (void)scrollViewDidScroll:(UIScrollView *)sender {
	//NSLog(@"Content offset: %@. Content size: %@.", NSStringFromCGPoint(sender.contentOffset), NSStringFromCGSize(sender.contentSize));
	if (sender != pagingScrollView_) {
//		NSLog(@"Zoom = %f. Content offset: %@. Center: %@. contentSize: %@.", sender.zoomScale,
//			  NSStringFromCGPoint(sender.contentOffset),
//			  NSStringFromCGPoint([sender viewWithTag:TAG_IMAGE_VIEW].center),
//			  NSStringFromCGSize(sender.contentSize));
		return;
	}
	if (rotationInProgress_)
		return; // UIScrollView layoutSubviews code adjusts contentOffset, breaking our logic
	
	CGSize pageSize = pagingScrollView_.frame.size;
	NSUInteger newPageIndex = (pagingScrollView_.contentOffset.x + pageSize.width / 2) / pageSize.width;
	
	// could happen when scrolling fast
	if (newPageIndex < 0)
		newPageIndex = 0;
	else if (newPageIndex >= cachedPageCount_)
		newPageIndex = cachedPageCount_;
	
	if (newPageIndex != currentPageIndex_) {
		[self updateCurrentPageIndex:newPageIndex];
	}

	if (pagingScrollView_.contentOffset.x == currentPageIndex_ * pageSize.width) {
		[self layoutContentViewAndResetZoomScaleForPageAtIndex:currentPageIndex_-1];
		[self layoutContentViewAndResetZoomScaleForPageAtIndex:currentPageIndex_+1];
	}
}


- (UIView *)viewForZoomingInScrollView:(UIScrollView *)aScrollView {
	if (aScrollView == pagingScrollView_)
		return nil;
	return [aScrollView viewWithTag:TAG_WRAPPER_VIEW];
}


- (void)scrollViewDidEndZooming:(UIScrollView *)innerScrollView withView:(UIView *)view atScale:(float)scale {
	// UIKit bug workaround, as per Apple samples -- this code can be removed when targetting 3.1+
	//	[innerScrollView setZoomScale:scale+0.01 animated:NO];
	//	[innerScrollView setZoomScale:scale animated:NO];
	// end UIKit bug workaround
	
	//	[self performSelector:@selector(updateContentInsetForPageScrollView:) withObject:innerScrollView afterDelay:0.75f];
	[self updateContentInsetForPageScrollView:innerScrollView];
}


@end



#pragma mark -
@implementation ATPageViewController


@synthesize pageView=pageView_;


- (void)loadView {
	pageView_ = [[ATPageView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
	pageView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view = pageView_;
}


- (void)viewDidLoad {
	pageView_.delegate = self;
}


- (void)viewWillAppear:(BOOL)animated {
	[self.pageView reload];
}


- (void)currentPageIndexDidChangeInPageView:(ATPageView *)pageView {
	self.navigationItem.title = [NSString stringWithFormat:@"%d of %d", 1+pageView.currentPageIndex, pageView.numberOfPages];
}


- (NSInteger)numberOfPagesInPageView:(ATPageView *)pageView {
	return 3;
}


- (UIView *)pageView:(ATPageView *)pageView viewForPageAtIndex:(NSInteger)page {
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
	UIColor *colors[] = {
		[UIColor redColor], [UIColor greenColor], [UIColor blueColor]
	};
	view.backgroundColor = colors[page % 3];
	return view;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return YES;
}


@end
