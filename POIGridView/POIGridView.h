//
//  POIGridTableView.h
//  POIGridTable
//
//  Created by zfgj on 13-12-30.
//  Copyright (c) 2013年 zfgj. All rights reserved.
//  横向Page 增加两种不同情况的样式展示
//  增加Page属性, 增加page属性
//  Page：YES
//  口口口口
//  口
//  Page：NO
//  口口口
//  口口
//

#import <UIKit/UIKit.h>

typedef enum {
    POIGridViewStyleVertical = 0,   // 竖向
    POIGridViewStyleHorizontal      // 横向
} POIGridViewStyle;

@class POIGridViewCell;
@protocol POIGridViewDatasource;
@protocol POIGridViewDelegate;

@interface POIGridView : UIScrollView <UIScrollViewDelegate>
// 背景图，可替换
@property (nonatomic, strong) UIView *backgroundView;                   // backgroundView 大小跟 POIGridView大小 一样

// 数据源
@property (nonatomic, assign) id <POIGridViewDatasource> gridDatasource;
@property (nonatomic, assign) id <POIGridViewDelegate> gridDelegate;

- (id)initWithFrame:(CGRect)frame style:(POIGridViewStyle)style;
- (void)reloadData;
- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier;
@end


////DataSource and Delegate
@protocol POIGridViewDatasource <NSObject>
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


@interface POIGridViewCell : UIView
@property (nonatomic, retain) NSIndexPath *indexPath;
@property (nonatomic, retain) NSString *reuseIdentifier;
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;
@end