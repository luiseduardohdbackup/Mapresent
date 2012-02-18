//
//  DSMRTimelineView.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineView.h"

#import "DSMRTimelineMarker.h"
#import "DSMRTimelineMarkerView.h"

@interface DSMRTimeLineViewTimeline : UIView

@end

#pragma mark -

@interface DSMRTimelineView ()

@property (nonatomic, assign, getter=isPlaying) BOOL playing;
@property (nonatomic, strong) UIScrollView *scroller;
@property (nonatomic, strong) DSMRTimeLineViewTimeline *timeline;
@property (nonatomic, strong) NSTimer *playTimer;

@end

#pragma mark -

@implementation DSMRTimelineView

@synthesize delegate;
@synthesize playing;
@synthesize exporting;
@synthesize scroller;
@synthesize timeline;
@synthesize playTimer;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    if (self)
    {
        [self setBackgroundColor:[UIColor blackColor]];
        
        scroller = [[UIScrollView alloc] initWithFrame:[self bounds]];
        
        [self insertSubview:scroller atIndex:0];
        
        timeline = [[DSMRTimeLineViewTimeline alloc] initWithFrame:CGRectMake(0, 0, [self bounds].size.width * 3, [self bounds].size.height)];
        
        [scroller addSubview:timeline];

        scroller.contentSize = timeline.frame.size;
        scroller.delegate = self;
    }
    
    return self;
}

#pragma mark -

- (void)togglePlay
{
    if ([self.playTimer isValid])
    {
        [self.playTimer invalidate];
        
        self.playing = NO;
        
        if (self.isExporting)
            self.exporting = NO;
    }
    else
    {
        self.playing = YES;
        
        self.playTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / (self.isExporting ? 8.0 : 64.0)) 
                                                          target:self 
                                                        selector:@selector(firePlayTimer:) 
                                                        userInfo:nil 
                                                         repeats:YES];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayToggled object:self];
}

- (void)firePlayTimer:(NSTimer *)timer
{
    CGPoint targetOffset = CGPointMake(self.scroller.contentOffset.x + 1.0, self.scroller.contentOffset.y);
    
    if (targetOffset.x > self.timeline.bounds.size.width - self.scroller.bounds.size.width)
    {
        [self togglePlay];
    }
    else
    {
        [self.scroller setContentOffset:targetOffset animated:NO];
     
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayProgressed object:[NSNumber numberWithFloat:targetOffset.x]];
    }
}

- (void)redrawMarkers
{
    [self.timeline.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    for (DSMRTimelineMarker *marker in [self.delegate timelineMarkers])
    {
        DSMRTimelineMarkerView *markerView = [[DSMRTimelineMarkerView alloc] initWithMarker:marker];
        
        UITapGestureRecognizer *markerTap = [[UITapGestureRecognizer alloc] initWithHandler:^(UIGestureRecognizer *sender, UIGestureRecognizerState state, CGPoint location)
        {
            if (state == UIGestureRecognizerStateEnded)
            {
                DSMRTimelineMarkerView *markerView = ((DSMRTimelineMarkerView *)((UIGestureRecognizer *)sender).view);
                
                [self.delegate timelineMarkerTapped:markerView.marker];
            }
        }];
        
        [markerView addGestureRecognizer:markerTap];
        
        CGFloat placement;
        
        switch (marker.markerType)
        {
            case DSMRTimelineMarkerTypeLocation:
            {
                placement = 85;
                break;
            }
            case DSMRTimelineMarkerTypeAudio:
            {
                placement = 130;
                break;
            }
            case DSMRTimelineMarkerTypeTheme:
            {
                placement = 175;
                break;
            }
            case DSMRTimelineMarkerTypeDrawing:
            case DSMRTimelineMarkerTypeDrawingClear:
            {
                placement = 220;
                break;
            }
        }
        
        markerView.frame = CGRectMake((marker.timeOffset * 64.0) + 512.0, placement, markerView.frame.size.width, markerView.frame.size.height);
        
        [self.timeline addSubview:markerView];
    }
}

- (void)rewindToBeginning
{
    [self.scroller setContentOffset:CGPointMake(0, 0) animated:YES];
}

#pragma mark -

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([self.playTimer isValid])
        [self togglePlay];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.dragging && scrollView.contentOffset.x >= 0 && scrollView.contentOffset.x <= (self.timeline.bounds.size.width - self.scroller.bounds.size.width))
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayProgressed object:[NSNumber numberWithFloat:scroller.contentOffset.x]];
    
    if (scrollView.contentOffset.x > scrollView.contentSize.width - scrollView.bounds.size.width)
    {
        self.timeline.frame = CGRectMake(self.timeline.frame.origin.x, 
                                         self.timeline.frame.origin.y, 
                                         self.timeline.frame.size.width + scrollView.bounds.size.width, 
                                         self.timeline.frame.size.height);
        
        scrollView.contentSize = self.timeline.frame.size;
        
        [self.timeline setNeedsDisplayInRect:CGRectMake(self.timeline.frame.size.width - scrollView.bounds.size.width, 
                                                        self.timeline.frame.origin.y, 
                                                        scrollView.bounds.size.width, 
                                                        self.timeline.frame.size.height)];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayProgressed object:[NSNumber numberWithFloat:scroller.contentOffset.x]];
}

@end

#pragma mark -

@implementation DSMRTimeLineViewTimeline

- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    // lay down base color
    //
    CGContextSetFillColorWithColor(c, [[UIColor darkGrayColor] CGColor]);
    CGContextFillRect(c, rect);

    // draw darker start of timeline
    //
    if (rect.origin.x == 0 && rect.size.width >= 512.0)
    {
        CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:0.0 alpha:0.5] CGColor]);
        CGContextFillRect(c, CGRectMake(0, 0, 512.0, rect.size.height));
    }

    // draw time hatches
    //
    CGContextSetStrokeColorWithColor(c, [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor]);
    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor]);

    CGContextSetLineWidth(c, 2);

    int start = ((rect.origin.x == 0 && rect.size.width > 512.0) ? 512.0 : rect.origin.x);
    
    for (float i = start; i < rect.size.width; i = i + 8.0)
    {
        CGContextBeginPath(c);
        
        float y;
        
        if (fmodf(i, 64.0) == 0.0)
        {
            // big, labeled hatch
            //
            [[NSString stringWithFormat:@"%i", (int)(i - 512.0) / 64] drawAtPoint:CGPointMake(i + 4.0, 65.0) withFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize]]];

            y = 75.0;
        }
        else
        {
            // intermediate hatch
            //
            y = 50.0;
        }
        
        CGContextMoveToPoint(c, i, 0.0);
        CGContextAddLineToPoint(c, i, y);
        
        CGContextStrokePath(c);
    }
}

@end