//
//  POIGridTableView.m
//  POIGridTable
//
//  Created by zfgj on 13-12-30.
//  Copyright (c) 2013年 zfgj. All rights reserved.
//

#import "POIGridView.h"

@interface POIGridView ()
{
    POIGridViewStyle _gridViewStyle;
    
    NSMutableArray *_visibleCells;          // 显示中的Cell
    NSMutableDictionary *_reusableCells;    // 可重用的Cell
    NSMutableDictionary *_cellRects;        // 每个Cell的位置
    
    CGFloat _oldOffset_y;
    CGFloat _oldOffset_x;
    
    BOOL _isLoading;
    
    NSInteger _columnCount;   // 列数
    NSInteger _rowCount;      // 行数
    NSInteger _cellsTotal;    // 总的数据数
}
@end

@implementation POIGridView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setDelegate:self];
        [self setPagingEnabled:NO];
        [self setBounces:YES];
        
        _isLoading = NO;
        _gridViewStyle = POIGridViewStyleHorizontal;
        _oldOffset_y = 0.0f;
        _oldOffset_x = 0.0f;
        
        _reusableCells = [[NSMutableDictionary alloc] init];
        _visibleCells = [[NSMutableArray alloc] init];
        _cellRects = [[NSMutableDictionary alloc] init];
        
        [self performSelectorOnMainThread:@selector(initialize) withObject:nil waitUntilDone:NO];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame style:(POIGridViewStyle)style {
    self = [self initWithFrame:frame];
    _gridViewStyle = style;
    return self;
}

-(void)dealloc {
    [self setDelegate:nil];
    _gridDatasource = nil;
    _gridDelegate = nil;
}

-(void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if (_backgroundView) {
        [_backgroundView setFrame:self.bounds];
    }
}

- (void)setGridDelegate:(id<POIGridViewDelegate>)gridDelegate {
    _gridDelegate = gridDelegate;
    [self setDelegate:gridDelegate];
}

#pragma mark - backgroundView
- (void)setBackgroundView:(UIView *)backgroundView {
    if (_backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = nil;
    }
    _backgroundView = backgroundView;
    [_backgroundView setFrame:CGRectMake(self.contentOffset.x, self.contentOffset.y, self.frame.size.width, self.frame.size.height)];
    [self addSubview:_backgroundView];
}

#pragma mark - Cell Selected
- (void)cellSelected:(POIGridViewCell *)cell
{
    if (_gridDelegate && [_gridDelegate respondsToSelector:@selector(gridView:didSelectRowAtIndexPath:)])
    {
        [_gridDelegate gridView:self didSelectRowAtIndexPath:cell.indexPath];
    }
}

#pragma mark-
#pragma mark - manage and reuse cells
- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
    if (!identifier || identifier == 0 ) return nil;
    
    NSArray *cellsWithIndentifier = [NSArray arrayWithArray:[_reusableCells objectForKey:identifier]];
    if (cellsWithIndentifier &&  cellsWithIndentifier.count > 0)
    {
        POIGridViewCell *cell = [cellsWithIndentifier lastObject];
        [[_reusableCells objectForKey:identifier] removeLastObject];
        return cell;
    }
    return nil;
}

- (void)recycleCellIntoReusableQueue:(POIGridViewCell *)cell
{
    // 添加不可见的Cell到可重用reusableCells
    if(!_reusableCells)
    {
        _reusableCells = [[NSMutableDictionary alloc] init];
        
        NSMutableArray *array = [NSMutableArray arrayWithObject:cell];
        [_reusableCells setObject:array forKey:cell.reuseIdentifier];
    }
    else
    {
        if (![_reusableCells objectForKey:cell.reuseIdentifier])
        {
            NSMutableArray *array = [NSMutableArray arrayWithObject:cell];
            [_reusableCells setObject:array forKey:cell.reuseIdentifier];
        }
        else
        {
            [[_reusableCells objectForKey:cell.reuseIdentifier] addObject:cell];
        }
    }
}

#pragma mark -
#pragma mark - methods
- (void)initialize
{
    // 获取总条数
    _cellsTotal = 0;
    if (_gridDatasource && [_gridDatasource respondsToSelector:@selector(numberOfTotalInGridView:)]) {
        _cellsTotal = [_gridDatasource numberOfTotalInGridView:self];
    }
    // 多少列
    _columnCount = 1;
    if ((_gridViewStyle == POIGridViewStyleVertical || self.isPagingEnabled == YES) && _gridDatasource && [_gridDatasource respondsToSelector:@selector(numberOfColumnInGridView:)]) {
        _columnCount = [_gridDatasource numberOfColumnInGridView:self];
    }
    
    // 横向，多少行
    _rowCount = 1;
    if (_gridViewStyle == POIGridViewStyleHorizontal && _gridDatasource && [_gridDatasource respondsToSelector:@selector(numberOfRowInGridView:)]) {
        _rowCount = [_gridDatasource numberOfRowInGridView:self];
    }
    
    // 每个Cell的大小
    CGSize cellSize = CGSizeZero;
    if (_gridDelegate && [_gridDelegate respondsToSelector:@selector(sizeForCellInGridView:)]) {
        cellSize = [_gridDelegate sizeForCellInGridView:self];
    }
    
    // 计算每个cell的间隔
    CGFloat cell_x = 0;
    if (_gridViewStyle == POIGridViewStyleHorizontal && self.isPagingEnabled == NO) {
        if (_gridDelegate && [_gridDelegate respondsToSelector:@selector(edgeWidthInGridView:)]) {
            cell_x = ceilf([_gridDelegate edgeWidthInGridView:self]);
        }
    } else {
        cell_x = ceilf((self.frame.size.width - cellSize.width * _columnCount) / (_columnCount + 1));
    }
    
    CGFloat cell_y = 0;
    if (_gridViewStyle == POIGridViewStyleVertical) {
        // 竖向, 需要用户设置, 调用回调, 默认 0.0
        if (_gridDelegate && [_gridDelegate respondsToSelector:@selector(edgeHeightInGridView:)]) {
            cell_y = ceilf([_gridDelegate edgeHeightInGridView:self]);
        }
    } else {
        // 横向, 需要计算高度间隔
        cell_y = ceilf((self.frame.size.height - cellSize.height * _rowCount) / (_rowCount + 1));
    }
    
    // 每个Cell的位置
    for (NSInteger i = 0; i < _cellsTotal; i ++) {
        NSDictionary *rectDic = nil;
        if (_gridViewStyle == POIGridViewStyleVertical) {
            // 确定横向视图各个Cell的位置
            CGFloat x = cell_x + (i % _columnCount) * (cell_x + cellSize.width);
            CGFloat y = cell_y + (i / _columnCount) * (cell_y + cellSize.height);
            
            rectDic = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithFloat:x], @"x",
                       [NSNumber numberWithFloat:y], @"y",
                       [NSNumber numberWithFloat:cellSize.width], @"width",
                       [NSNumber numberWithFloat:cellSize.height], @"height",nil];
        }
        if (_gridViewStyle == POIGridViewStyleHorizontal && self.isPagingEnabled == NO) {
            CGFloat x = cell_x + (i / _rowCount) * (cell_x + cellSize.width);
            CGFloat y = cell_y + (i % _rowCount) * (cell_y + cellSize.height);
            rectDic = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithFloat:x], @"x",
                       [NSNumber numberWithFloat:y], @"y",
                       [NSNumber numberWithFloat:cellSize.width], @"width",
                       [NSNumber numberWithFloat:cellSize.height], @"height",nil];
        }
        if (_gridViewStyle == POIGridViewStyleHorizontal && self.isPagingEnabled == YES) {
            NSInteger page = i / (_rowCount * _columnCount);
            CGFloat x = page * self.frame.size.width + cell_x + (i % _columnCount) * (cell_x + cellSize.width);
            CGFloat y = cell_y + (i / _columnCount) % _rowCount * (cell_y + cellSize.height);
            rectDic = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithFloat:x], @"x",
                       [NSNumber numberWithFloat:y], @"y",
                       [NSNumber numberWithFloat:cellSize.width], @"width",
                       [NSNumber numberWithFloat:cellSize.height], @"height",nil];
        }
        [_cellRects setObject:rectDic forKey:[NSString stringWithFormat:@"%ld",(long)i]];
    }
    
    // 设置 GridView 内容大小
    CGFloat contentWidth = self.frame.size.width;
    CGFloat contentHeight = self.frame.size.height;
    
    if (_gridViewStyle == POIGridViewStyleVertical) {
        // 竖向
        if (_columnCount != 0) {
            contentHeight = cell_y + (_cellsTotal / _columnCount + (_cellsTotal % _columnCount ? 1 : 0)) * (cell_y + cellSize.height);
            contentHeight = MAX(contentHeight, self.frame.size.height + 1);
        }
    }
    
    if (_gridViewStyle == POIGridViewStyleHorizontal && self.isPagingEnabled == NO) {
        // 横向
        if (_rowCount != 0) {
            contentWidth = cell_x + (_cellsTotal / _rowCount + (_cellsTotal % _rowCount ? 1 : 0)) * (cell_x + cellSize.width);
            contentWidth = MAX(contentWidth, self.frame.size.width + 1);
        }
    }
    
    if (_gridViewStyle == POIGridViewStyleHorizontal && self.isPagingEnabled == YES) {
        NSInteger page = _cellsTotal / (_rowCount * _columnCount) + (_cellsTotal % (_rowCount * _columnCount) ? 1 : 0);
        contentWidth = page * self.frame.size.width;
        contentWidth = MAX(contentWidth, self.frame.size.width + 1);
    }
    
    [self setContentSize:CGSizeMake(contentWidth, contentHeight)];
    
    [self traverseAllCell];
    
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [self waterFlowScroll];
}

- (void)reloadData
{
    if (_isLoading) {
        return;
    }
    _isLoading = YES;
    
    //移出并添加可视cell到可重用数组
    NSMutableArray *tempCells = [NSMutableArray array];
    for (id cell in _visibleCells) {
        [self recycleCellIntoReusableQueue:cell];
        [tempCells addObject:cell];
        [cell removeFromSuperview];
    }
    for (id cell in tempCells) {
        [_visibleCells removeObject:cell];
    }
    
    [self initialize];
    
    _isLoading = NO;
}

-(void)waterFlowScroll {
    [_backgroundView setFrame:CGRectMake(self.contentOffset.x, self.contentOffset.y, self.frame.size.width, self.frame.size.height)];
    
    // 证明有数据
    if (_visibleCells.count > 0) {
        // 判断方向，减少遍历次数
        BOOL direction = YES;       // 正方向 或 负方向
        if (_gridViewStyle == POIGridViewStyleVertical) {
            direction = self.contentOffset.y >= _oldOffset_y ? 1 : 0;  // 1代表向下滑动,0代表向上滑动
        }
        if (_gridViewStyle == POIGridViewStyleHorizontal) {
            direction = self.contentOffset.x >= _oldOffset_x ? 1 : 0;  // 1代表向右滑动,0代表向左滑动
        }
        
        POIGridViewCell *firstCell = [_visibleCells firstObject];
        NSInteger firstIndex = firstCell.indexPath.row;    // 之前加的
        POIGridViewCell *lastCell = [_visibleCells lastObject];
        NSInteger lastIndex = lastCell.indexPath.row;      // 最新添加的
        if (lastIndex > firstIndex) {
            firstIndex = lastIndex - _visibleCells.count - 1;
        } else {
            firstIndex = lastIndex + _visibleCells.count - 1;
            NSInteger tempIndex = firstIndex;
            firstIndex = lastIndex;
            lastIndex = tempIndex;
        }
        if (direction) {
            lastIndex = lastIndex + _columnCount * _rowCount * 2;
        } else {
            firstIndex = firstIndex - _columnCount * _rowCount * 2;
        }
        
        lastIndex = MAX(lastIndex, 0);
        lastIndex = MIN(lastIndex, _cellsTotal);
        firstIndex = MAX(firstIndex, 0);
        firstIndex = MIN(firstIndex, _cellsTotal);
        
        for (NSInteger i = firstIndex; i < lastIndex; i++) {
            
            NSDictionary *rectDic = [_cellRects objectForKey:[NSString stringWithFormat:@"%ld",(long)i]];
            
            // 在可视范围内则添加
            if (![self isInVisibleCells:i] && [self isVisibleCellWithCellFrame:[self rectWithCellRectDic:rectDic]]) {
                POIGridViewCell *cell = [_gridDatasource gridView:self cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                [cell setIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                CGRect cellRect = [self rectWithCellRectDic:rectDic];
                [cell setFrame:cellRect];
                [self performSelectorOnMainThread:@selector(addSubview:) withObject:cell waitUntilDone:YES];
                [_visibleCells addObject:cell];
            }
        }
    }
    
    _oldOffset_x = self.contentOffset.x;
    _oldOffset_y = self.contentOffset.y;
}

-(void)traverseAllCell {
    // 重新reloadData
    int foundFlag = 0; // NO没找到过，YES找到过了
    for (NSInteger i = [self traverseWithDivisor:_cellRects.count/10 FromIndex:0]; i < _cellsTotal; i ++) {
        NSDictionary *rectDic = [_cellRects objectForKey:[NSString stringWithFormat:@"%ld",(long)i]];
        // 在可视范围内则添加
        if (![self isInVisibleCells:i] && [self isVisibleCellWithCellFrame:[self rectWithCellRectDic:rectDic]]) {
            POIGridViewCell *cell = [_gridDatasource gridView:self cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            [cell setIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            CGRect cellRect = [self rectWithCellRectDic:rectDic];
            [cell setFrame:cellRect];
            [self addSubview:cell];
            [_visibleCells addObject:cell];
            foundFlag = 1;
        } else if (foundFlag) {
            foundFlag++;
            if (foundFlag >= _columnCount * _rowCount * 2) {
                // 超过次数连续找不到对应的就跳出
                break;
            }
        }
    }
}

// 优化reloadData遍历
-(NSInteger)traverseWithDivisor:(NSInteger)divisor FromIndex:(NSInteger)index {
    if (_cellRects.count == 0 || index > (_cellRects.count - 1)) {
        return 0;
    }
    if (divisor == 0) {
        divisor = 1;
    }
    NSInteger foundIndex = index;
    BOOL isFound = NO;
    for (NSInteger i = index; i < _cellRects.count; i += divisor) {
        NSDictionary *rectDic = [_cellRects objectForKey:[NSString stringWithFormat:@"%ld",(long)i]];
        if ([self isVisibleCellWithCellFrame:[self rectWithCellRectDic:rectDic]]) {
            foundIndex = i;
            isFound = YES;
            break;
        }
    }
    if (isFound == NO) {
        [self traverseWithDivisor:divisor/2 FromIndex:foundIndex];
    }
    if (divisor == 1) {
        return foundIndex;
    } else {
        return [self traverseWithDivisor:divisor/10 FromIndex:foundIndex-divisor];
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        
    }];
}

// 判断是不是在可视范围内
-(BOOL)isVisibleCellWithCellFrame:(CGRect)frame {
    BOOL visibleFlag = YES; // 初始化为可视
    // 需要加载的cell的可视范围
    if (_gridViewStyle == POIGridViewStyleVertical) {
        // 竖向，检查高度
//        CGFloat offset_top = self.contentOffset.y - self.frame.size.height;
//        CGFloat offset_bottom = self.contentOffset.y + self.frame.size.height + self.frame.size.height;
        CGFloat offset_top = self.contentOffset.y;
        CGFloat offset_bottom = self.contentOffset.y + self.frame.size.height;
        
        CGFloat top = frame.origin.y;
        CGFloat bottom = frame.origin.y + frame.size.height;
        // 情况1,假设视图高度没有超出屏幕，头尾都没在可视范围内
        if ((top < offset_top || top > offset_bottom) && (bottom < offset_top || bottom > offset_bottom)) {
            visibleFlag = NO;   // 不可视
        }
        // 情况2,假设视图高度超出屏幕，头尾都没在可视范围内,但视图在可视范围内
        if (((bottom - top) > self.frame.size.height) && (top < offset_top) && (bottom > offset_bottom)) {
            visibleFlag = YES;   // 可视
        }
    }
    
    if (_gridViewStyle == POIGridViewStyleHorizontal) {
        // 横向，检查宽度
        CGFloat offset_left = self.contentOffset.x - self.frame.size.width;
        CGFloat offset_right = self.contentOffset.x + self.frame.size.width + self.frame.size.width;
        
        CGFloat left = frame.origin.x;
        CGFloat right = frame.origin.x + frame.size.width;
        
        // 情况1,假设视图高度没有超出屏幕，头尾都没在可视范围内
        if ((left < offset_left || left > offset_right) && (right < offset_left || right > offset_right)) {
            visibleFlag = NO;   // 不可视
        }
        // 情况2,假设视图高度超出屏幕，头尾都没在可视范围内,但视图在可视范围内
        if (((right - left) > self.frame.size.height) && (left < offset_left) && (right > offset_right)) {
            visibleFlag = YES;   // 可视
        }
    }
    return visibleFlag;
}

-(void)removeUnVisibleCell {
    // 遍历完成后，保留可见的cell，将不可见的去除
    NSMutableArray *tempCells = [NSMutableArray array];
    if (_visibleCells.count > 0 && _visibleCells.count > _columnCount * _rowCount * 2) {
        for (NSInteger i = 0; i < _visibleCells.count; i ++) {
            POIGridViewCell *cell = [_visibleCells objectAtIndex:i];
            // 不可视则移出
            if (![self isVisibleCellWithCellFrame:cell.frame]) {
                // 条件二，假如cell长度大于屏幕，
                [cell removeFromSuperview];
                [self recycleCellIntoReusableQueue:cell];
                [tempCells addObject:cell];
            }
        }
    }
    for (id cell in tempCells) {
        [_visibleCells removeObject:cell];
    }
}

// 判断是不是已经存在
-(BOOL)isInVisibleCells:(NSInteger)row {
    BOOL isIn = NO;
    for (POIGridViewCell *cell in _visibleCells) {
        if (cell.indexPath.row == row) {
            isIn = YES;
            break;
        }
    }
    return isIn;
}

// 转换CellRectDic为CGRect
-(CGRect)rectWithCellRectDic:(NSDictionary *)rectDic {
    CGRect cellRect = CGRectZero;
    if ([rectDic isKindOfClass:[NSDictionary class]] && [rectDic objectForKey:@"x"] && [rectDic objectForKey:@"y"] && [rectDic objectForKey:@"width"] && [rectDic objectForKey:@"height"]) {
        CGFloat x = [[rectDic objectForKey:@"x"] floatValue];
        CGFloat y = [[rectDic objectForKey:@"y"] floatValue];
        CGFloat width = [[rectDic objectForKey:@"width"] floatValue];
        CGFloat height = [[rectDic objectForKey:@"height"] floatValue];
        cellRect = CGRectMake(x, y, width, height);
    }
    return cellRect;
}

@end

//===================================================================
//
//*************************POIGridViewCell*****************************
//
//===================================================================
@implementation POIGridViewCell
@synthesize indexPath = _indexPath;
@synthesize reuseIdentifier = _reuseIdentifier;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if(self = [super init])
	{
		self.reuseIdentifier = reuseIdentifier;
	}
	
	return self;
}

- (void)dealloc
{
    self.indexPath = nil;
    self.reuseIdentifier = nil;
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UIView *superView = [self superview];
    if ([superView respondsToSelector:@selector(cellSelected:)]) {
        [superView performSelector:@selector(cellSelected:) withObject:self];
    }
}

@end
