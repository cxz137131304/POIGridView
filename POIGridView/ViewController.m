//
//  ViewController.m
//  POIGridView
//
//  Created by Poison on 14-1-23.
//  Copyright (c) 2014年 Poison. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	POIGridView *gridView = [[POIGridView alloc] initWithFrame:[UIScreen mainScreen].bounds style:POIGridViewStyleVertical];
//    [gridView setPagingEnabled:YES];
    [gridView setGridDatasource:self];
    [gridView setGridDelegate:self];
    [self.view addSubview:gridView];
}

#pragma mark - POIGridView Delegate
- (NSInteger)numberOfTotalInGridView:(POIGridView *)gridView {
    return 1000;
}

- (NSInteger)numberOfColumnInGridView:(POIGridView *)gridView {
    return 4;
}

- (NSInteger)numberOfRowInGridView:(POIGridView *)gridView {
    return 3;
}

- (CGFloat)edgeHeightInGridView:(POIGridView *)gridView {
    return 10.0f;
}

- (CGFloat)edgeWidthInGridView:(POIGridView *)gridView {
    return 10.0f;
}

- (CGSize)sizeForCellInGridView:(POIGridView *)gridView {
    return CGSizeMake(70, 70);
}
- (POIGridViewCell *)gridView:(POIGridView *)gridView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"CellIdentifier";
    POIGridViewCell *cell = [gridView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[POIGridViewCell alloc] initWithReuseIdentifier:cellIdentifier];
        [cell setBackgroundColor:[UIColor grayColor]];
    }
    
    return cell;
}

- (void)gridView:(POIGridView *)gridView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

@end
