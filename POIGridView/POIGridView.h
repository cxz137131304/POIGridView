//
//  POIGridTableView.h
//  POIGridTable
//
//  Created by zfgj on 13-12-30.
//  Copyright (c) 2013年 zfgj. All rights reserved.
//  横向Page 增加两种不同情况的样式展示
//  增加Page属性, 增加page属性
//  Page：YES
//  1 2 3 4
//  5
//  Page：NO
//  1 3 5
//  2 4
//

#import <UIKit/UIKit.h>
#import "POIGridViewCell.h"

typedef enum {
    POIGridViewStyleVertical = 0,   // 垂直
    POIGridViewStyleHorizontal      // 水平
} POIGridViewStyle;

@class POIGridViewCell;
@class POIGridView;

//DataSource and Delegate
@protocol POIGridViewDataSource <NSObject>
@optional
- (NSInteger)numberOfColumnInGridView:(POIGridView *)gridView;          // 列数, Defautl 0 竖直时才需要用到，横向且Page=YES时需要。
- (NSInteger)numberOfRowInGridView:(POIGridView *)gridView;             // 行数, Defautl 0 横向时才需要用到
@required
- (NSInteger)numberOfTotalInGridView:(POIGridView *)gridView;           // 总个数, Defautl 0
- (POIGridViewCell *)gridView:(POIGridView *)gridView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@protocol POIGridViewDelegate <NSObject, UIScrollViewDelegate>
@required
- (CGSize)sizeForCellInGridView:(POIGridView *)gridView;  // Defautl CGSizeZero
@optional
- (CGFloat)edgeWidthInGridView:(POIGridView *)gridView;                                     // cell水平间隔, Defautl 0.0 横向时才需要用到
- (CGFloat)edgeHeightInGridView:(POIGridView *)gridView;                                    // cell垂直间隔, Defautl 0.0 竖向时才需要用到
- (void)gridView:(POIGridView *)gridView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface POIGridView : UIScrollView <NSCoding>

@property (assign, nonatomic) POIGridViewStyle style;

// 背景图，可替换
@property (nonatomic, strong) UIView *backgroundView;                   // backgroundView 大小跟 POIGridView大小 一样
@property (nonatomic, strong) UIView *gridHeaderView;                   // 头部，只有竖向的才会显示
@property (nonatomic, strong) UIView *gridFooterView;                   // 底部，只有竖向的才会显示

@property (strong, nonatomic) NSMutableArray *visibleCells;             // 显示中的Cell
@property (strong, nonatomic) NSMutableDictionary *reusableCells;       // 可重用的Cell
@property (strong, nonatomic) NSMutableDictionary *cellRects;           // 每个Cell的位置

@property (nonatomic, assign) UIEdgeInsets contentInsets;               // 边距

// 数据源
@property (nonatomic, assign) id <POIGridViewDataSource> dataSource;
@property (nonatomic, assign) id <POIGridViewDelegate> delegate;

- (id)initWithFrame:(CGRect)frame style:(POIGridViewStyle)style;
- (void)reloadData;
- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier;

- (CGRect)rectWithCellRectDic:(NSDictionary *)rectDic;

- (POIGridViewCell *)cellForIndexPath:(NSIndexPath *)indexPath;

- (void)cellSelected:(POIGridViewCell *)cell;

@end
