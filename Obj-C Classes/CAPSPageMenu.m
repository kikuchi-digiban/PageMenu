//
//  CAPSPageMenu.m
//
//
//  Created by Jin Sasaki on 2015/05/30.
//
//

#import "CAPSPageMenu.h"
#import "TestTableViewController.h"

@interface MenuItemView ()

@end

@implementation MenuItemView

- (void)setUpMenuItemView:(CGFloat)menuItemWidth menuScrollViewHeight:(CGFloat)menuScrollViewHeight indicatorHeight:(CGFloat)indicatorHeight separatorPercentageHeight:(CGFloat)separatorPercentageHeight separatorWidth:(CGFloat)separatorWidth separatorRoundEdges:(BOOL)separatorRoundEdges menuItemSeparatorColor:(UIColor *)menuItemSeparatorColor
{
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, menuItemWidth, menuScrollViewHeight - indicatorHeight)];
    _menuItemSeparator = [[UIView alloc] initWithFrame:CGRectMake(menuItemWidth - (separatorWidth / 2), floor(menuScrollViewHeight * ((1.0 - separatorPercentageHeight) / 2.0)), separatorWidth, floor(menuScrollViewHeight * separatorPercentageHeight))];
    
    if (separatorRoundEdges) {
        _menuItemSeparator.layer.cornerRadius = _menuItemSeparator.frame.size.width / 2;
    }
    
    _menuItemSeparator.hidden = YES;
    [self addSubview:_menuItemSeparator];
    [self addSubview:_titleLabel];
}
- (void)setTitleText:(NSString *)text
{
    if (_titleLabel) {
        _titleLabel.text = text;
        _titleLabel.numberOfLines = 0;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
    }
}

@end

typedef NS_ENUM(NSUInteger, CAPSPageMenuScrollDirection) {
    CAPSPageMenuScrollDirectionLeft,
    CAPSPageMenuScrollDirectionRight,
    CAPSPageMenuScrollDirectionOther
};

@interface CAPSPageMenu ()

@property (nonatomic) NSMutableArray *mutableMenuItems;
@property (nonatomic) CGFloat startingMenuMargin;

@property (nonatomic) UIView *selectionIndicatorView;

@property (nonatomic) BOOL currentOrientationIsPortrait;
@property (nonatomic) NSInteger pageIndexForOrientationChange;
@property (nonatomic) BOOL didLayoutSubviewsAfterRotation;
@property (nonatomic) BOOL didScrollAlready;

@property (nonatomic) CGFloat lastControllerScrollViewContentOffset;
@property (nonatomic) CAPSPageMenuScrollDirection lastScrollDirection;
@property (nonatomic) NSInteger startingPageForScroll;
@property (nonatomic) BOOL didTapMenuItemToScroll;
@property (nonatomic) NSMutableSet *pagesAddedSet;

@property (nonatomic) CGFloat functionViewHeight;      // FunctionViewの高さ
@property (nonatomic) CGFloat lastFunctionViewOffsetY; // ベースとなるUIScrollViewの最終スクロール位置を保持
@property (nonatomic) NSMutableDictionary *lastContentTableViewOffsetY; // コンテンツとなるUITableViewの最終スクロール位置を保持
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) BOOL didPullToRefresh;

@property (nonatomic) NSTimer *tapTimer;
@property (nonatomic) NSTimer *scrollTimer;            // 中途半端な位置でスクロールが止めたときに処理をコール

@end

@implementation CAPSPageMenu

NSString * const CAPSPageMenuOptionSelectionIndicatorHeight             = @"selectionIndicatorHeight";
NSString * const CAPSPageMenuOptionMenuItemSeparatorWidth               = @"menuItemSeparatorWidth";
NSString * const CAPSPageMenuOptionScrollMenuBackgroundColor            = @"scrollMenuBackgroundColor";
NSString * const CAPSPageMenuOptionViewBackgroundColor                  = @"viewBackgroundColor";
NSString * const CAPSPageMenuOptionBottomMenuHairlineColor              = @"bottomMenuHairlineColor";
NSString * const CAPSPageMenuOptionSelectionIndicatorColor              = @"selectionIndicatorColor";
NSString * const CAPSPageMenuOptionMenuItemSeparatorColor               = @"menuItemSeparatorColor";
NSString * const CAPSPageMenuOptionMenuMargin                           = @"menuMargin";
NSString * const CAPSPageMenuOptionMenuHeight                           = @"menuHeight";
NSString * const CAPSPageMenuOptionSelectedMenuItemLabelColor           = @"selectedMenuItemLabelColor";
NSString * const CAPSPageMenuOptionUnselectedMenuItemLabelColor         = @"unselectedMenuItemLabelColor";
NSString * const CAPSPageMenuOptionMenuItemSeparatorRoundEdges          = @"menuItemSeparatorRoundEdges";
NSString * const CAPSPageMenuOptionMenuItemFont                         = @"menuItemFont";
NSString * const CAPSPageMenuOptionMenuItemSeparatorPercentageHeight    = @"menuItemSeparatorPercentageHeight";
NSString * const CAPSPageMenuOptionMenuItemWidth                        = @"menuItemWidth";
NSString * const CAPSPageMenuOptionEnableHorizontalBounce               = @"enableHorizontalBounce";
NSString * const CAPSPageMenuOptionAddBottomMenuHairline                = @"addBottomMenuHairline";
NSString * const CAPSPageMenuOptionScrollAnimationDurationOnMenuItemTap = @"scrollAnimationDurationOnMenuItemTap";
NSString * const CAPSPageMenuOptionHideTopMenuBar                       = @"hideTopMenuBar";

- (instancetype)initWithViewControllers:(NSArray *)viewControllers frame:(CGRect)frame options:(NSDictionary *)options
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    
    [self initValues];
    
    _controllerArray = viewControllers;
    
    self.view.frame = frame;
    
    if (options) {
        for (NSString *key in options) {
            if ([key isEqualToString:CAPSPageMenuOptionSelectionIndicatorHeight]) {
                _selectionIndicatorHeight = [options[key] floatValue];
            } else if ([key isEqualToString: CAPSPageMenuOptionMenuItemSeparatorWidth]) {
                _menuItemSeparatorWidth = [options[key] floatValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionScrollMenuBackgroundColor]) {
                _scrollMenuBackgroundColor = (UIColor *)options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionViewBackgroundColor]) {
                _viewBackgroundColor = options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionBottomMenuHairlineColor]) {
                _bottomMenuHairlineColor = options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionSelectionIndicatorColor]) {
                _selectionIndicatorColor = options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionMenuItemSeparatorColor]) {
                _menuItemSeparatorColor = options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionMenuMargin]) {
                _menuMargin = [options[key] floatValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionMenuHeight]) {
                _menuHeight = [options[key] floatValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionSelectedMenuItemLabelColor]) {
                _selectedMenuItemLabelColor = options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionUnselectedMenuItemLabelColor]) {
                _unselectedMenuItemLabelColor = options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionMenuItemSeparatorRoundEdges]) {
                _menuItemSeparatorRoundEdges = [options[key] boolValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionMenuItemFont]) {
                _menuItemFont = options[key];
            } else if ([key isEqualToString:CAPSPageMenuOptionMenuItemSeparatorPercentageHeight]) {
                _menuItemSeparatorPercentageHeight = [options[key] floatValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionMenuItemWidth]) {
                _menuItemWidth = [options[key] floatValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionEnableHorizontalBounce]) {
                _enableHorizontalBounce = [options[key] boolValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionAddBottomMenuHairline]) {
                _addBottomMenuHairline = [options[key] boolValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionScrollAnimationDurationOnMenuItemTap]) {
                _scrollAnimationDurationOnMenuItemTap = [options[key] integerValue];
            } else if ([key isEqualToString:CAPSPageMenuOptionHideTopMenuBar]) {
                _hideTopMenuBar = [options[key] boolValue];
            }
        }
        
        if (_hideTopMenuBar) {
            _addBottomMenuHairline = NO;
            _menuHeight = 0.0;
        }
    }
    
    [self setUpUserInterface];
    if (_menuScrollView.subviews.count == 0) {
        [self configureUserInterface];
    }
    return self;
}


- (void)initValues
{
    // add
    _dummyView            = [UIView new];
    _functionScrollView   = [UIScrollView new];
    
    _menuScrollView       = [UIScrollView new];
    _controllerScrollView = [UIScrollView new];
    _mutableMenuItems       = [NSMutableArray array];
    
    _menuHeight                           = 34.0;
    _menuMargin                           = 15.0;
    _menuItemWidth                        = 111.0;
    _selectionIndicatorHeight             = 3.0;
    _scrollAnimationDurationOnMenuItemTap = 500;
    _startingMenuMargin                   = 0.0;
    
    _selectionIndicatorView = [UIView new];
    
    _currentPageIndex = 0;
    _lastPageIndex    = 0;
    
    _selectionIndicatorColor      = [UIColor whiteColor];
    _selectedMenuItemLabelColor   = [UIColor whiteColor];
    _unselectedMenuItemLabelColor = [UIColor lightGrayColor];
    _scrollMenuBackgroundColor    = [UIColor blackColor];
    _viewBackgroundColor          = [UIColor whiteColor];
    _bottomMenuHairlineColor      = [UIColor whiteColor];
    _menuItemSeparatorColor       = [UIColor lightGrayColor];
    
    _menuItemFont = [UIFont systemFontOfSize:15.0];
    _menuItemSeparatorPercentageHeight = 0.2;
    _menuItemSeparatorWidth            = 0.5;
    _menuItemSeparatorRoundEdges       = NO;
    
    _addBottomMenuHairline              = YES;
    _enableHorizontalBounce             = YES;
    _hideTopMenuBar                     = NO;
    
    _currentOrientationIsPortrait   = YES;
    _pageIndexForOrientationChange  = 0;
    _didLayoutSubviewsAfterRotation = NO;
    _didScrollAlready               = NO;
    
    _lastControllerScrollViewContentOffset = 0.0;
    _startingPageForScroll = 0;
    _didTapMenuItemToScroll = NO;
    
    _pagesAddedSet = [NSMutableSet set];

    // add
    _functionViewHeight = 100.0;
    _lastFunctionViewOffsetY = 0.0;
    _lastContentTableViewOffsetY = [NSMutableDictionary dictionaryWithCapacity:100];;
    _didPullToRefresh = NO;
}

- (void)setUpUserInterface
{
#if 0 // AutoLayoutは後回し
    NSDictionary *viewsDictionary = @{
                                      @"menuScrollView" : _menuScrollView,
                                      @"controllerScrollView":_controllerScrollView
                                      };
#endif
    // FunctionScrollViewの設定
    _functionScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _functionScrollView.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height);
    _functionScrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_functionScrollView];
    
    // Refreshコントール
    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(pullToRefresh:) forControlEvents:UIControlEventValueChanged];
    [_functionScrollView addSubview:_refreshControl];
    
    // DummyView
    _dummyView.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, _functionViewHeight);
    _dummyView.backgroundColor = [UIColor redColor];
    [_functionScrollView addSubview:_dummyView];
    
    // controllerScrollViewの設定
    _controllerScrollView.pagingEnabled                             = YES;
    //_controllerScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _controllerScrollView.alwaysBounceHorizontal = _enableHorizontalBounce;
    _controllerScrollView.bounces                = _enableHorizontalBounce;
    _controllerScrollView.frame = CGRectMake(0.0, _functionViewHeight, self.view.frame.size.width, self.view.frame.size.height - _menuHeight);
    [_functionScrollView addSubview:_controllerScrollView];
    
#if 0 // AutoLayoutは後回し
    NSArray *controllerScrollView_constraint_H = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[controllerScrollView]|" options:0 metrics:nil views:viewsDictionary];
    NSString *controllerScrollView_constraint_V_Format = [NSString stringWithFormat:@"V:|-0-[controllerScrollView]|"];
    NSArray *controllerScrollView_constraint_V = [NSLayoutConstraint constraintsWithVisualFormat:controllerScrollView_constraint_V_Format options:0 metrics:nil views:viewsDictionary];
    [self.view addConstraints:controllerScrollView_constraint_H];
    [self.view addConstraints:controllerScrollView_constraint_V];
#endif
    
    // menuScrollViewの設定
    //_menuScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _menuScrollView.frame = CGRectMake(0.0, _functionViewHeight, self.view.frame.size.width, _menuHeight);
    [_functionScrollView addSubview:_menuScrollView];

#if 0 // AutoLayoutは後回し
    NSArray *menuScrollView_constraint_H = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[menuScrollView]|" options:0 metrics:nil views:viewsDictionary];
    NSString *menuScrollView_constrant_V_Format = [NSString stringWithFormat:@"V:|[menuScrollView(%.f)]",_menuHeight];
    NSArray *menuScrollView_constraint_V = [NSLayoutConstraint constraintsWithVisualFormat:menuScrollView_constrant_V_Format options:0 metrics:nil views:viewsDictionary];
    [self.view addConstraints:menuScrollView_constraint_H];
    [self.view addConstraints:menuScrollView_constraint_V];
#endif
    
    if (_addBottomMenuHairline) {
        UIView *menuBottomHairline = [UIView new];
        
        menuBottomHairline.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self.view addSubview:menuBottomHairline];
#if 0 // AutoLayoutは後回し
        NSArray *menuBottomHairline_constraint_H = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[menuBottomHairline]|" options:0 metrics:nil views:@{@"menuBottomHairline":menuBottomHairline}];
        NSString *menuBottomHairline_constraint_V_Format = [NSString stringWithFormat:@"V:|-%f-[menuBottomHairline(0.5)]",_menuHeight];
        NSArray *menuBottomHairline_constraint_V = [NSLayoutConstraint constraintsWithVisualFormat:menuBottomHairline_constraint_V_Format options:0 metrics:nil views:@{@"menuBottomHairline":menuBottomHairline}];
        
        [self.view addConstraints:menuBottomHairline_constraint_H];
        [self.view addConstraints:menuBottomHairline_constraint_V];
#endif
        menuBottomHairline.backgroundColor = _bottomMenuHairlineColor;
    }
    
    // Disable scroll bars
    _menuScrollView.showsHorizontalScrollIndicator       = NO;
    _menuScrollView.showsVerticalScrollIndicator         = NO;
    _controllerScrollView.showsHorizontalScrollIndicator = NO;
    _controllerScrollView.showsVerticalScrollIndicator   = NO;
    _functionScrollView.showsHorizontalScrollIndicator = YES;
    _functionScrollView.showsVerticalScrollIndicator   = YES;
    
    // Set background color behind scroll views and for menu scroll view
    self.view.backgroundColor = _viewBackgroundColor;
    _menuScrollView.backgroundColor = _scrollMenuBackgroundColor;
    _functionScrollView.backgroundColor = [UIColor whiteColor];
}

- (void)configureUserInterface
{
    UITapGestureRecognizer *menuItemTapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleMenuItemTap:)];
    menuItemTapGestureRecognizer.numberOfTapsRequired    = 1;
    menuItemTapGestureRecognizer.numberOfTouchesRequired = 1;
    menuItemTapGestureRecognizer.delegate                = self;
    [_menuScrollView addGestureRecognizer:menuItemTapGestureRecognizer];
    
    // Set delegate for controller scroll view
    _controllerScrollView.delegate = self;
    _functionScrollView.delegate   = self;
    
    // When the user taps the status bar, the scroll view beneath the touch which is closest to the status bar will be scrolled to top,
    // but only if its `scrollsToTop` property is YES, its delegate does not return NO from `shouldScrollViewScrollToTop`, and it is not already at the top.
    // If more than one scroll view is found, none will be scrolled.
    // Disable scrollsToTop for menu and controller scroll views so that iOS finds scroll views within our pages on status bar tap gesture.
    _menuScrollView.scrollsToTop       = NO;;
    _controllerScrollView.scrollsToTop = NO;;
    _functionScrollView.scrollsToTop   = NO;
    
    _menuScrollView.contentSize = CGSizeMake((_menuItemWidth + _menuMargin) * (CGFloat)_controllerArray.count + _menuMargin, _menuHeight);
    _controllerScrollView.contentSize = CGSizeMake(self.view.frame.size.width * (CGFloat)_controllerArray.count, 0.0);
    _functionScrollView.contentSize = CGSizeMake(self.view.frame.size.width , self.view.frame.size.height + _functionViewHeight);
    
    CGFloat index = 0.0;
    
    for (UIViewController *controller in _controllerArray) {
        if (index == 0.0) {
            // Add first two controllers to scrollview and as child view controller
            [controller viewWillAppear:YES];
            [self addPageAtIndex:0];
            [controller viewDidAppear:YES];
        }
        
        // controller(TableView)を監視する
        // contentSize
        TestTableViewController* contentTableView = (TestTableViewController*)controller;
        [contentTableView.tableView addObserver:self
                     forKeyPath:@"contentSize"
                        options:NSKeyValueObservingOptionNew
                        context:(__bridge void *)contentTableView.title];
        // contentOffset
        [contentTableView.tableView addObserver:self
                     forKeyPath:@"contentOffset"
                        options:NSKeyValueObservingOptionNew
                        context:(__bridge void *)contentTableView.title];
        
        // Set up menu item for menu scroll view
        CGRect menuItemFrame;
        menuItemFrame = CGRectMake(_menuItemWidth * index + _menuMargin * (index + 1) + _startingMenuMargin, 0.0, _menuItemWidth, _menuHeight);
        
        MenuItemView *menuItemView = [[MenuItemView alloc] initWithFrame:menuItemFrame];
        [menuItemView setUpMenuItemView:_menuItemWidth menuScrollViewHeight:_menuHeight indicatorHeight:_selectionIndicatorHeight separatorPercentageHeight:_menuItemSeparatorPercentageHeight separatorWidth:_menuItemSeparatorWidth separatorRoundEdges:_menuItemSeparatorRoundEdges menuItemSeparatorColor:_menuItemSeparatorColor];

        
        // Configure menu item label font if font is set by user
        menuItemView.titleLabel.font = _menuItemFont;
        
        menuItemView.titleLabel.textAlignment = NSTextAlignmentCenter;
        menuItemView.titleLabel.textColor = _unselectedMenuItemLabelColor;
        
        // Set title depending on if controller has a title set
        if (controller.title != nil) {
            [menuItemView setTitleText:controller.title];
        } else {
            [menuItemView setTitleText:[NSString stringWithFormat:@"Menu %.0f",index + 1]];
        }
        
        // Add menu item view to menu scroll view
        [_menuScrollView addSubview:menuItemView];
        
        [_mutableMenuItems addObject:menuItemView];
        
        index++;
    }
    
    // Set selected color for title label of selected menu item
    if (_mutableMenuItems.count > 0) {
        if ([_mutableMenuItems[_currentPageIndex] titleLabel] != nil) {
            [_mutableMenuItems[_currentPageIndex] titleLabel].textColor = _selectedMenuItemLabelColor;
        }
    }
    
    // Configure selection indicator view
    CGRect selectionIndicatorFrame;
    selectionIndicatorFrame = CGRectMake(_menuMargin, _menuHeight - _selectionIndicatorHeight, _menuItemWidth, _selectionIndicatorHeight);
    
    _selectionIndicatorView = [[UIView alloc] initWithFrame:selectionIndicatorFrame];
    _selectionIndicatorView.backgroundColor = _selectionIndicatorColor;
    [_menuScrollView addSubview:_selectionIndicatorView];
}

#pragma mark - Scroll view delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!_didLayoutSubviewsAfterRotation) { // 1度だけ
        if ([scrollView isEqual:_functionScrollView]) {
            NSLog(@"functionScrollView (%f, %f)", scrollView.contentOffset.x, scrollView.contentOffset.y);
            _lastFunctionViewOffsetY = scrollView.contentOffset.y; // 最後のスクロール位置を保持
        }
        if ([scrollView isEqual:_controllerScrollView]) {
            if (scrollView.contentOffset.x >= 0.0 && scrollView.contentOffset.x <= ((CGFloat)(_controllerArray.count - 1) * self.view.frame.size.width)) {
                UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
                if ((_currentOrientationIsPortrait && UIInterfaceOrientationIsPortrait(orientation)) || (!_currentOrientationIsPortrait && UIInterfaceOrientationIsLandscape(orientation))){
                    // Check if scroll direction changed
                    if (!_didTapMenuItemToScroll) {
                        if (_didScrollAlready) {
                            CAPSPageMenuScrollDirection newScrollDirection  = CAPSPageMenuScrollDirectionOther;
                            
                            if ((CGFloat)_startingPageForScroll * scrollView.frame.size.width > scrollView.contentOffset.x) {
                                newScrollDirection = CAPSPageMenuScrollDirectionRight;
                            } else if ((CGFloat)_startingPageForScroll * scrollView.frame.size.width < scrollView.contentOffset.x) {
                                newScrollDirection = CAPSPageMenuScrollDirectionLeft;
                            }
                            
                            if (newScrollDirection != CAPSPageMenuScrollDirectionOther) {
                                if (_lastScrollDirection != newScrollDirection) {
                                    NSInteger index = newScrollDirection == CAPSPageMenuScrollDirectionLeft ? _currentPageIndex + 1 : _currentPageIndex - 1;
                                    if (index >= 0 && index < _controllerArray.count ){
                                        // Check dictionary if page was already added
                                        if (![_pagesAddedSet containsObject:@(index)]) {

                                            [self addPageAtIndex:index];

                                            [_pagesAddedSet addObject:@(index)];
                                        }
                                    }
                                }
                            }
                            
                            _lastScrollDirection = newScrollDirection;
                        }
                        
                        if (!_didScrollAlready) {
                            if (_lastControllerScrollViewContentOffset > scrollView.contentOffset.x) {
                                if (_currentPageIndex != _controllerArray.count - 1 ){
                                    // Add page to the left of current page
                                    NSInteger index = _currentPageIndex - 1;

                                    if (![_pagesAddedSet containsObject:@(index)] && index < _controllerArray.count && index >= 0) {
                                        [self addPageAtIndex:index];

                                        [_pagesAddedSet addObject:@(index)];
                                    }
                                    
                                    _lastScrollDirection = CAPSPageMenuScrollDirectionRight;
                                }
                            } else if (_lastControllerScrollViewContentOffset < scrollView.contentOffset.x) {
                                if (_currentPageIndex != 0) {
                                    // Add page to the right of current page
                                    NSInteger index = _currentPageIndex + 1;
                                    
                                    if (![_pagesAddedSet containsObject:@(index)] && index < _controllerArray.count && index >= 0) {

                                        [self addPageAtIndex:index];
                                        [_pagesAddedSet addObject:@(index)];
                                    }
                                    
                                    _lastScrollDirection = CAPSPageMenuScrollDirectionLeft;
                                }
                            }
                            
                            _didScrollAlready = YES;
                        }
                        
                        _lastControllerScrollViewContentOffset = scrollView.contentOffset.x;
                    }
                    
                    CGFloat ratio = 1.0;
                    
                    // Calculate ratio between scroll views
                    ratio = (_menuScrollView.contentSize.width - self.view.frame.size.width) / (_controllerScrollView.contentSize.width - self.view.frame.size.width);
                    
                    if (_menuScrollView.contentSize.width > self.view.frame.size.width ){
                        CGPoint offset  = _menuScrollView.contentOffset;
                        offset.x = _controllerScrollView.contentOffset.x * ratio;
                        [_menuScrollView setContentOffset:offset animated: NO];
                    }
                    
                    // Calculate current page
                    CGFloat width = _controllerScrollView.frame.size.width;
                    NSInteger page = (NSInteger)(_controllerScrollView.contentOffset.x + (0.5 * width)) / width;
                    
                    // Update page if changed
                    if (page != _currentPageIndex) {
                        _lastPageIndex = _currentPageIndex;
                        _currentPageIndex = page;
                        
                        
                        if (![_pagesAddedSet containsObject:@(page)] && page < _controllerArray.count && page >= 0){
                            [self addPageAtIndex:page];
                            [_pagesAddedSet addObject:@(page)];
                            
                        }
                        
                        if (!_didTapMenuItemToScroll) {
                            // Add last page to pages dictionary to make sure it gets removed after scrolling
                            if (![_pagesAddedSet containsObject:@(_lastPageIndex)]) {
                                [_pagesAddedSet addObject:@(_lastPageIndex)];
                            }
                            
                            // Make sure only up to 3 page views are in memory when fast scrolling, otherwise there should only be one in memory
                            NSInteger indexLeftTwo = page - 2;
                            if ([_pagesAddedSet containsObject:@(indexLeftTwo)]) {
                                
                                [_pagesAddedSet removeObject:@(indexLeftTwo)];
                                
                                [self removePageAtIndex:indexLeftTwo];
                            }
                            NSInteger indexRightTwo = page + 2;
                            if ([_pagesAddedSet containsObject:@(indexRightTwo)]) {

                                [_pagesAddedSet removeObject:@(indexRightTwo)];

                                [self removePageAtIndex:indexRightTwo];
                            }
                        }
                    }
                    
                    [self moveSelectionIndicator:page];
                }
            } else {
                CGFloat ratio = 1.0;
                
                ratio = (_menuScrollView.contentSize.width - self.view.frame.size.width) / (_controllerScrollView.contentSize.width - self.view.frame.size.width);
                
                if (_menuScrollView.contentSize.width > self.view.frame.size.width) {
                    CGPoint offset = self.menuScrollView.contentOffset;
                    offset.x = _controllerScrollView.contentOffset.x * ratio;
                    [self.menuScrollView setContentOffset:offset animated:NO];
                }
                
                if ([scrollView isEqual:_functionScrollView]){
                    NSLog(@"FunctionScrollView1");
                }
            }
        }
    } else {
        
        if ([scrollView isEqual:_functionScrollView]){
            NSLog(@"FunctionScrollView2");
        }
        _didLayoutSubviewsAfterRotation = NO;
        
        // Move selection indicator view when swiping
        [self moveSelectionIndicator:self.currentPageIndex];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if ([scrollView isEqual:_controllerScrollView]) {
        // Call didMoveToPage delegate function
        UIViewController *currentController = _controllerArray[_currentPageIndex];
        if ([_delegate respondsToSelector:@selector(didMoveToPage:index:)]) {
            [_delegate didMoveToPage:currentController index:_currentPageIndex];
        }
        
        // Remove all but current page after decelerating
        for (NSNumber *num in _pagesAddedSet) {
            if (![num isEqualToNumber:@(self.currentPageIndex)]) {
                [self removePageAtIndex:num.integerValue];
            }
        }
        
        _didScrollAlready = NO;
        _startingPageForScroll = _currentPageIndex;
        
        // Empty out pages in dictionary
        [_pagesAddedSet removeAllObjects];
    }
    else if ([scrollView isEqual:_functionScrollView]) {
        NSLog(@"functionScrollView (%f, %f) STOP!", scrollView.contentOffset.x, scrollView.contentOffset.y);
    }
    NSLog(@"scrollViewDidEndDecelerating STOP");
}


- (void)scrollViewDidEndTapScrollingAnimation
{
    // Call didMoveToPage delegate function
    UIViewController *currentController = _controllerArray[_currentPageIndex];
    if ([_delegate respondsToSelector:@selector(didMoveToPage:index:)]) {
        [_delegate didMoveToPage:currentController index:_currentPageIndex];
    }
    
    // Remove all but current page after decelerating
    for (NSNumber *num in _pagesAddedSet) {
        if (![num isEqualToNumber:@(self.currentPageIndex)]) {
            [self removePageAtIndex:num.integerValue];
        }
    }

    _startingPageForScroll = _currentPageIndex;
    _didTapMenuItemToScroll = NO;
    
    // Empty out pages in dictionary
    [_pagesAddedSet removeAllObjects];
}


// MARK: - Handle Selection Indicator
- (void)moveSelectionIndicator:(NSInteger)pageIndex
{
    if (pageIndex >= 0 && pageIndex < _controllerArray.count) {
        [UIView animateWithDuration:0.15 animations:^{
            
            CGFloat selectionIndicatorWidth = self.selectionIndicatorView.frame.size.width;
            CGFloat selectionIndicatorX = 0.0;

            selectionIndicatorX = self.menuItemWidth * (CGFloat)pageIndex + self.menuMargin * (CGFloat)(pageIndex + 1) + self.startingMenuMargin;
            
            self.selectionIndicatorView.frame = CGRectMake(selectionIndicatorX, self.selectionIndicatorView.frame.origin.y, selectionIndicatorWidth, self.selectionIndicatorView.frame.size.height);
            
            // Switch newly selected menu item title label to selected color and old one to unselected color
            if (self.menuItems.count > 0) {
                if ([self.menuItems[self.lastPageIndex] titleLabel] != nil && [self.menuItems[self.currentPageIndex] titleLabel] != nil) {
                    [self.menuItems[self.lastPageIndex] titleLabel].textColor = self.unselectedMenuItemLabelColor;
                    [self.menuItems[self.currentPageIndex] titleLabel].textColor = self.selectedMenuItemLabelColor;
                }
            }
        }];
    }
}


// MARK: - Tap gesture recognizer selector
- (void)handleMenuItemTap:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint tappedPoint = [gestureRecognizer locationInView:_menuScrollView];
    
    if (tappedPoint.y < self.menuScrollView.frame.size.height) {
        
        // Calculate tapped page
        NSInteger itemIndex = 0;

        CGFloat rawItemIndex = ((tappedPoint.x - _startingMenuMargin) - _menuMargin / 2) / (_menuMargin + _menuItemWidth);
        
        // Prevent moving to first item when tapping left to first item
        if (rawItemIndex < 0) {
            itemIndex = -1;
        } else {
            itemIndex = (NSInteger)rawItemIndex;
        }
        
        if (itemIndex >= 0 && itemIndex < _controllerArray.count) {
            // Update page if changed
            if (itemIndex != _currentPageIndex) {
                _startingPageForScroll = itemIndex;
                _lastPageIndex = _currentPageIndex;
                _currentPageIndex = itemIndex;
                _didTapMenuItemToScroll = YES;
                
                // Add pages in between current and tapped page if necessary
                NSInteger smallerIndex = _lastPageIndex < _currentPageIndex ? _lastPageIndex : _currentPageIndex;
                NSInteger largerIndex = _lastPageIndex > _currentPageIndex ? _lastPageIndex : _currentPageIndex;
                
                if (smallerIndex + 1 != largerIndex) {
                    for (NSInteger i=smallerIndex + 1; i< largerIndex; i++) {
                        
                        if (![_pagesAddedSet containsObject:@(i)]) {
                            [self addPageAtIndex:i];
                            [_pagesAddedSet addObject:@(i)];
                        }
                    }
                }
                
                [self addPageAtIndex:itemIndex];
                
                // Add page from which tap is initiated so it can be removed after tap is done
                [_pagesAddedSet addObject:@(_lastPageIndex)];
                
            }
            
            // Move controller scroll view when tapping menu item
            double duration = _scrollAnimationDurationOnMenuItemTap / 1000.0;
            
            [UIView animateWithDuration:duration animations:^{
                CGFloat xOffset = (CGFloat)itemIndex * _controllerScrollView.frame.size.width;
                [_controllerScrollView setContentOffset:CGPointMake(xOffset, _controllerScrollView.contentOffset.y)];
            }];
            
            if (_tapTimer != nil) {
                [_tapTimer invalidate];
            }
            
            NSTimeInterval timerInterval = (double)_scrollAnimationDurationOnMenuItemTap * 0.001;
            _tapTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(scrollViewDidEndTapScrollingAnimation) userInfo:nil repeats:NO];
        }
    }
}

// MARK: - Remove/Add Page
- (void)addPageAtIndex:(NSInteger)index
{
    // Call didMoveToPage delegate function
    UIViewController *currentController = _controllerArray[index];
    if ([_delegate respondsToSelector:@selector(willMoveToPage:index:)]) {
        [_delegate willMoveToPage:currentController index:index];
    }
    UIViewController *newVC = _controllerArray[index];
    
    [newVC willMoveToParentViewController:self];
    
    newVC.view.frame = CGRectMake(self.view.frame.size.width * (CGFloat)index, _menuHeight, self.view.frame.size.width, self.view.frame.size.height - _menuHeight);
    
    [self addChildViewController:newVC];
    [_controllerScrollView addSubview:newVC.view];
    [newVC didMoveToParentViewController:self];
}

- (void)removePageAtIndex:(NSInteger)index
{
    UIViewController *oldVC = _controllerArray[index];
    
    [oldVC willMoveToParentViewController:nil];
    
    [oldVC.view removeFromSuperview];
    [oldVC removeFromParentViewController];
    
    [oldVC didMoveToParentViewController:nil];
}


// MARK: - Orientation Change

- (void)viewDidLayoutSubviews
{
    // Configure controller scroll view content size
    _controllerScrollView.contentSize = CGSizeMake(self.view.frame.size.width * (CGFloat)_controllerArray.count, self.view.frame.size.height - _menuHeight);
    
    NSLog(@"contentSize.height = %f", _functionScrollView.contentSize.height);
    
    BOOL oldCurrentOrientationIsPortrait = _currentOrientationIsPortrait;
    
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    _currentOrientationIsPortrait = UIInterfaceOrientationIsPortrait(orientation);
    
    if ((oldCurrentOrientationIsPortrait && UIInterfaceOrientationIsLandscape(orientation)) || (!oldCurrentOrientationIsPortrait && UIInterfaceOrientationIsPortrait(orientation))){
        _didLayoutSubviewsAfterRotation = YES;
        
        for (UIView *view in _controllerScrollView.subviews) {
            view.frame = CGRectMake(self.view.frame.size.width * (CGFloat)(_currentPageIndex), _menuHeight, _controllerScrollView.frame.size.width, self.view.frame.size.height - _menuHeight);
        }
        
        CGFloat xOffset = (CGFloat)(self.currentPageIndex) * _controllerScrollView.frame.size.width;
        [_controllerScrollView setContentOffset:CGPointMake(xOffset, _controllerScrollView.contentOffset.y)];
        
        CGFloat ratio = (_menuScrollView.contentSize.width - self.view.frame.size.width) / (_controllerScrollView.contentSize.width - self.view.frame.size.width);
        
        if (_menuScrollView.contentSize.width > self.view.frame.size.width) {
            CGPoint offset = _menuScrollView.contentOffset;
            offset.x = _controllerScrollView.contentOffset.x * ratio;
            [_menuScrollView setContentOffset:offset animated:NO];
        }
    }
    
    // Hsoi 2015-02-05 - Running on iOS 7.1 complained: "'NSInternalInconsistencyException', reason: 'Auto Layout
    // still required after sending -viewDidLayoutSubviews to the view controller. ViewController's implementation
    // needs to send -layoutSubviews to the view to invoke auto layout.'"
    //
    // http://stackoverflow.com/questions/15490140/auto-layout-error
    //
    // Given the SO answer and caveats presented there, we'll call layoutIfNeeded() instead.
    [self.view layoutIfNeeded];
}


// MARK: - Move to page index

/**
 Move to page at index
 
 :param: index Index of the page to move to
 */
- (void)moveToPage:(NSInteger)index
{
    if (index >= 0 && index < _controllerArray.count) {
        // Update page if changed
        if (index != _currentPageIndex) {
            _startingPageForScroll = index;
            _lastPageIndex = _currentPageIndex;
            _currentPageIndex = index;
            _didTapMenuItemToScroll = YES;
            
            // Add pages in between current and tapped page if necessary
            NSInteger smallerIndex = _lastPageIndex < _currentPageIndex ? _lastPageIndex : _currentPageIndex;
            NSInteger largerIndex = _lastPageIndex > _currentPageIndex ? _lastPageIndex : _currentPageIndex;
            
            if (smallerIndex + 1 != largerIndex) {
                for (NSInteger i=smallerIndex + 1; i<largerIndex; i++) {
                    
                    if (![_pagesAddedSet containsObject:@(i)]) {
                        [self addPageAtIndex:i];
                        [_pagesAddedSet addObject:@(i)];
                    }
                }
            }
            [self addPageAtIndex:index];
            
            // Add page from which tap is initiated so it can be removed after tap is done
            [_pagesAddedSet addObject:@(_lastPageIndex)];
        }
        
        // Move controller scroll view when tapping menu item
        double duration = (double)(_scrollAnimationDurationOnMenuItemTap) / (double)(1000);
        
        [UIView animateWithDuration:duration animations:^{
            CGFloat xOffset = (CGFloat)index * self.controllerScrollView.frame.size.width;
            [self.controllerScrollView setContentOffset:CGPointMake(xOffset, self.controllerScrollView.contentOffset.y) animated:NO];
        }];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}


- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return YES;
}


// MARK: Getter 
- (NSArray *)menuItems
{
    return _mutableMenuItems;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context

{
    if ([keyPath isEqualToString:@"contentSize"]) {
        ;
    }
    else if ([keyPath isEqualToString:@"contentOffset"]) {
        
        // Timerを落とす
        if (_scrollTimer != nil) {
            [_scrollTimer invalidate];
        }
        
        // 該当Tableのタイトルを取得。KEYで利用
        NSString *title = (__bridge NSString *)context;
        
        // 格納していたTableViewの1つ前のオフセット位置を取得
        NSValue *val = [_lastContentTableViewOffsetY objectForKey:title];
        CGPoint lastTableViewPoint = [val CGPointValue];
        CGFloat lastTableViewOffsetY = lastTableViewPoint.y;

        // TableViewのオフセットを取得
        UITableView* contentTableView = (UITableView*)object;
        CGFloat offsetY = contentTableView.contentOffset.y; // この値のプラスマイナスで上 or 下のスクロールが分かる
        NSLog(@"offsetY=%f, lastOffsetY=%f", offsetY, lastTableViewOffsetY);
        
        if(_lastFunctionViewOffsetY < _functionViewHeight && offsetY > 0.0 && offsetY > lastTableViewOffsetY){
            // FunctionViewが見えている状態のTableViewの上スクロール。
            CGFloat diff = offsetY - lastTableViewOffsetY;
            if (_lastFunctionViewOffsetY + diff > _functionViewHeight) { // スクロールが早いと余分に上側にズレるため調整
                diff = _functionViewHeight - _lastFunctionViewOffsetY;   // ちょうどの高さにする
            }
            _functionScrollView.contentOffset = CGPointMake(0, _lastFunctionViewOffsetY + diff); // FunctionScrollViewの位置を上側に移動
            if (offsetY != lastTableViewOffsetY) {
                contentTableView.contentOffset = CGPointMake(0, lastTableViewOffsetY);               // TableViewの移動位置を戻す(引っ付く感じ)
            }
            //contentTableView.contentOffset = CGPointMake(0, 0);                                  // TableViewの移動位置を戻す(引っ付く感じ)
            if (_lastFunctionViewOffsetY < 0) {
                // Timerを起動
                NSTimeInterval timerInterval = (double)0.1f;
                _scrollTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
                                                                target:self selector:@selector(scrollViewDidEndScrolling) userInfo:nil repeats:NO];
            }
            NSLog(@"上 スクロール　lastFunctionOffsetY=%f, offsetY=%f", _lastFunctionViewOffsetY, offsetY);

        }
        else if(_lastFunctionViewOffsetY >= 0 && offsetY < 0.0){  // ★1 -150
            // FunctionViewが見えている状態の下スクロールで、まだ引っ張られていない場所
            CGFloat diff = offsetY - lastTableViewOffsetY;
            _functionScrollView.contentOffset = CGPointMake(0, _lastFunctionViewOffsetY + diff); // FunctionScrollViewの位置を下側に移動
            //contentTableView.contentOffset = CGPointMake(0, lastTableViewOffsetY);               // TableViewの移動位置を戻す(引っ付く感じ)
            contentTableView.contentOffset = CGPointMake(0, 0);                                  // TableViewの移動位置を戻す(引っ付く感じ)
            NSLog(@"下1スクロール　lastFunctionOffsetY=%f, offsetY=%f", _lastFunctionViewOffsetY, offsetY);
            
        }
        else if(_lastFunctionViewOffsetY > -150.0 && offsetY < 0.0){  // ★1 -150
            // FunctionViewが見えている状態の下スクロールで、引っ張られている場所
            CGFloat diff = offsetY - lastTableViewOffsetY;  // 移動量取得
            _functionScrollView.contentOffset = CGPointMake(0, _lastFunctionViewOffsetY + diff); // FunctionScrollViewの位置を下側に移動
            contentTableView.contentOffset = CGPointMake(0, 0);                                  // TableViewの移動位置を戻す(引っ付く感じ)
            // Timerを起動
            NSTimeInterval timerInterval = (double)0.1f;
            _scrollTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
                                                            target:self selector:@selector(scrollViewDidEndScrolling) userInfo:nil repeats:NO];
            NSLog(@"下2スクロール　lastFunctionOffsetY=%f, offsetY=%f", _lastFunctionViewOffsetY, offsetY);
            
        }
        else if(_lastFunctionViewOffsetY > -1000.00 && offsetY < 0.0){
            // Pull to Refresh起動
            _functionScrollView.contentOffset = CGPointMake(0, -200); // ★2 -200 (Pull to Refreshのようにみせる)
            [_refreshControl beginRefreshing];
            [self pullToRefresh:_refreshControl];
            contentTableView.contentOffset = CGPointMake(0, 0);            // TableViewの移動位置を戻す(引っ付く感じ)
            NSLog(@"リフレッシュ 　lastFunctionOffsetY=%f, offsetY=%f", _lastFunctionViewOffsetY, offsetY);
            
        }else{
            NSLog(@"その他　　　　 lastFunctionOffsetY=%f, offsetY=%f", _lastFunctionViewOffsetY, offsetY);
            
        }
        
        // 各TableViewのオフセット値をDictionaryに保存。
        val = [NSValue valueWithCGPoint:contentTableView.contentOffset];
        [_lastContentTableViewOffsetY setObject:val forKey:title];

    }
}

- (void)pullToRefresh:(UIRefreshControl *)refreshControl
{
    if (_didPullToRefresh) {
        return;
    }
    
    if (_scrollTimer != nil) {
        [_scrollTimer invalidate];
    }
    
    _didPullToRefresh = YES;
    
    refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Refreshing data..."];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [NSThread sleepForTimeInterval:1];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"MMM d, h:mm a"];
            NSString *lastUpdate = [NSString stringWithFormat:@"Last updated on %@", [formatter stringFromDate:[NSDate date]]];
            
            refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:lastUpdate];
            
            [refreshControl endRefreshing];
            _didPullToRefresh = NO;
            NSLog(@"refresh end");
        });
    });
}

- (void)scrollViewDidEndScrolling
{
    if (_didPullToRefresh) {
        return;
    }
    
    NSLog(@"scrollViewDidEndScrolling");
    [UIView animateWithDuration:0.4f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         // アニメーションをする処理
                         _functionScrollView.contentOffset = CGPointMake(0, 0);
                     } completion:^(BOOL finished) {
                         // アニメーションが終わった後実行する処理
                     }];

}

@end
