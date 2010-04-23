
#import <UIKit/UIKit.h>

@protocol ATPageViewDelegate;


@interface ATPageView : UIView {
	UIScrollView *pagingScrollView_;
	id<ATPageViewDelegate> delegate_;
	NSInteger currentPageIndex_;
	CGFloat pageGap_;
	NSInteger neighbourPageViewsToPreload_;
	NSInteger neighbourPageViewsToCache_;
	NSInteger cachedPageCount_;
	NSMutableArray *reusablePageViews_;
	NSMutableArray *cachedPageViews_; // array of size (neighbourPagesToKeep_*2 + 1), always centered at the current page
	BOOL rotationInProgress_;
}

@property(nonatomic, assign) id<ATPageViewDelegate> delegate;

@property(nonatomic, retain, readonly) UIScrollView *pagingScrollView;

@property(nonatomic, readonly) NSInteger numberOfPages;

@property(nonatomic) NSInteger currentPageIndex;

@property(nonatomic) CGFloat pageGap; // spacing between pages, defaults to 20

@property(nonatomic) NSInteger neighbourPageViewsToPreload; // number of pages to preload on the either side of the current one, defaults to 1

@property(nonatomic) NSInteger neighbourPageViewsToCache; // number of pages to cache on the either side of the current one, must be at least (neighbourPageViewsToPreload+1), defaults to 2

- (void)setCurrentPageIndex:(NSInteger)newIndex animated:(BOOL)animated;

- (void)reload;

- (UIView *)dequeueReusablePage;

@end


@protocol ATPageViewDelegate <NSObject>

- (NSInteger)numberOfPagesInPageView:(ATPageView *)pageView;

- (UIView *)pageView:(ATPageView *)pageView viewForPageAtIndex:(NSInteger)page;

- (void)currentPageIndexDidChangeInPageView:(ATPageView *)pageView;

- (void)pageView:(ATPageView *)pageView configureScrollView:(UIScrollView *)scrollView forPageAtIndex:(NSInteger)page;

@end


@interface ATPageViewController : UIViewController <ATPageViewDelegate> {
	ATPageView *pageView_;
}

@property(nonatomic, retain, readonly) ATPageView *pageView;

@end
