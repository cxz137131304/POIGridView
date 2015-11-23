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
    CGFloat _oldOffset_y;
    CGFloat _oldOffset_x;
    
    BOOL _isLoading;
    
    NSInteger _columnCount;   // 列数
    NSInteger _rowCount;      // 行数
    NSInteger _cellsTotal;    // 总的数据数
    
    __unsafe_unretained id <POIGridViewDataSource> _dataSource;
    __unsafe_unretained id <POIGridViewDelegate> _delegate;
    
    CGFloat _contentWidth;
    CGFloat _contentHeight;
    
    CGSize _reloadSize;
}
@end

@implementation POIGridView

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame style:(POIGridViewStyle)style {
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)awakeFromNib {
    [self setAutoresizesSubviews:NO];
    [self initialize];
}

- (void)initialize {
    _isLoading = NO;
    _oldOffset_y = 0.0f;
    _oldOffset_x = 0.0f;
    
    _contentWidth = 0.0f;
    _contentHeight = 0.0f;
    self.contentInsets = UIEdgeInsetsZero;
    
    [self performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

-(void)dealloc {
    [self setDelegate:nil];
    _dataSource = nil;
    _delegate = nil;
}

- (NSMutableArray *)visibleCells {
    if (_visibleCells == nil) {
        _visibleCells = [[NSMutableArray alloc] init];
    }
    return _visibleCells;
}

- (NSMutableDictionary *)reusableCells {
    if (_reusableCells == nil) {
        _reusableCells = [[NSMutableDictionary alloc] init];
    }
    return _reusableCells;
}

- (NSMutableDictionary *)cellRects {
    if (_cellRects == nil) {
        _cellRects = [[NSMutableDictionary alloc] init];
    }
    return _cellRects;
}

-(void)setFrame:(CGRect)frame {
    [super setFrame:frame];
//    if (_backgroundView) {
//        [_backgroundView setFrame:self.bounds];
//    }
//    [self reloadData];
}

- (void)setDelegate:(id<POIGridViewDelegate>)delegate {
    _delegate = delegate;
    [super setDelegate:_delegate];
}

- (CGSize)contentSize {
    return CGSizeMake(_contentWidth, _contentHeight);
}

#pragma mark - Set
- (void)setBackgroundView:(UIView *)backgroundView {
    if (_backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = nil;
    }
    _backgroundView = backgroundView;
    [_backgroundView setFrame:CGRectMake(self.contentOffset.x, self.contentOffset.y, self.frame.size.width, self.frame.size.height)];
    [self addSubview:_backgroundView];
}

- (void)setGridHeaderView:(UIView *)gridHeaderView {
    if (_gridHeaderView) {
        [_gridHeaderView removeFromSuperview];
        _gridHeaderView = nil;
    }
    _gridHeaderView = gridHeaderView;
}

- (void)setGridFooterView:(UIView *)gridFooterView {
    if (_gridFooterView) {
        [_gridFooterView removeFromSuperview];
        _gridFooterView = nil;
    }
    _gridFooterView = gridFooterView;
}

#pragma mark - Cell Selected
- (void)cellSelected:(POIGridViewCell *)cell
{
    if (_delegate && [_delegate respondsToSelector:@selector(gridView:didSelectRowAtIndexPath:)])
    {
        [_delegate gridView:self didSelectRowAtIndexPath:cell.indexPath];
    }
}

#pragma mark-
#pragma mark - manage and reuse cells
- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
    if (!identifier || identifier == 0 ) return nil;
    
    NSArray *cellsWithIndentifier = [NSArray arrayWithArray:[self.reusableCells objectForKey:identifier]];
    if (cellsWithIndentifier &&  cellsWithIndentifier.count > 0)
    {
        POIGridViewCell *cell = [cellsWithIndentifier lastObject];
        [[self.reusableCells objectForKey:identifier] removeLastObject];
        return cell;
    }
    return nil;
}

- (void)recycleCellIntoReusableQueue:(POIGridViewCell *)cell
{
    // 添加不可见的Cell到可重用reusableCells
    if ([cell.reuseIdentifier isKindOfClass:[NSString class]] == NO || [cell isKindOfClass:[POIGridViewCell class]] == NO) {
        return;
    }
    
    if(!self.reusableCells)
    {
        self.reusableCells = [[NSMutableDictionary alloc] init];
        
        NSMutableArray *array = [NSMutableArray arrayWithObject:cell];
        [self.reusableCells setObject:array forKey:cell.reuseIdentifier];
    }
    else
    {
        if (![self.reusableCells objectForKey:cell.reuseIdentifier])
        {
            NSMutableArray *array = [NSMutableArray arrayWithObject:cell];
            [self.reusableCells setObject:array forKey:cell.reuseIdentifier];
        }
        else
        {
            [[self.reusableCells objectForKey:cell.reuseIdentifier] addObject:cell];
        }
    }
}

- (POIGridViewCell *)cellForIndexPath:(NSIndexPath *)indexPath {
    for (POIGridViewCell *cell in self.visibleCells) {
        if (cell.indexPath.row == indexPath.row) {
            return cell;
        }
    }
    return nil;
}

#pragma mark -
#pragma mark - methods
- (void)setup
{
    // 获取总条数
    _cellsTotal = 0;
    if (_dataSource && [_dataSource respondsToSelector:@selector(numberOfTotalInGridView:)]) {
        _cellsTotal = [_dataSource numberOfTotalInGridView:self];
    }
    // 多少列
    _columnCount = 1;
    if (_dataSource && [_dataSource respondsToSelector:@selector(numberOfColumnInGridView:)]) {
        _columnCount = [_dataSource numberOfColumnInGridView:self];
    }
    
    // 横向，多少行
    _rowCount = 1;
    if (self.style == POIGridViewStyleVertical && _dataSource && [_dataSource respondsToSelector:@selector(numberOfRowInGridView:)]) {
        _rowCount = [_dataSource numberOfRowInGridView:self];
    }
    
    // 每个Cell的大小
    CGSize cellSize = CGSizeZero;
    if (_delegate && [_delegate respondsToSelector:@selector(sizeForCellInGridView:)]) {
        cellSize = [_delegate sizeForCellInGridView:self];
    }
    
    // 计算每个cell的间隔
    CGFloat cell_x = 0;
    if (self.style == POIGridViewStyleHorizontal && self.isPagingEnabled == NO) {
        if (_delegate && [_delegate respondsToSelector:@selector(edgeWidthInGridView:)]) {
            cell_x = [_delegate edgeWidthInGridView:self];
        }
    } else {
        if (_columnCount > 1) {
            cell_x = (self.frame.size.width - cellSize.width * _columnCount - self.contentInsets.left - self.contentInsets.right) / (_columnCount - 1);
        }
    }
    
    CGFloat cell_y = 0;
    if (self.style == POIGridViewStyleVertical && self.isPagingEnabled == NO) {
        // 竖向, 需要用户设置, 调用回调, 默认 0.0
        if (_delegate && [_delegate respondsToSelector:@selector(edgeHeightInGridView:)]) {
            cell_y = [_delegate edgeHeightInGridView:self];
        }
    } else {
        // 横向, 需要计算高度间隔
        cell_y = (self.frame.size.height - cellSize.height * _rowCount) / (_rowCount + 1);
    }
    
    // 头尾高度
    CGFloat gridHeaderHeight = 0.0f;
    CGFloat gridHeaderWidth = 0.0f;
    if ([_gridHeaderView isKindOfClass:[UIView class]]) {
        if (self.style == POIGridViewStyleVertical) {
            gridHeaderHeight = _gridHeaderView.frame.size.height;
        } else {
            gridHeaderWidth = _gridHeaderView.frame.size.width;
        }
    }
    
    CGFloat gridFooterHeight = 0.0f;
    CGFloat gridFooterWidth = 0.0f;
    if ([_gridFooterView isKindOfClass:[UIView class]]) {
        if (self.style == POIGridViewStyleVertical) {
            gridFooterHeight = _gridFooterView.frame.size.height;
        } else {
            gridFooterWidth = _gridFooterView.frame.size.width;
        }
    }
    
    // 每个Cell的位置
    for (NSInteger i = 0; i < _cellsTotal; i ++) {
        NSDictionary *rectDic = nil;
        if (self.style == POIGridViewStyleVertical) {
            // 确定竖向视图各个Cell的位置
            CGFloat x = self.contentInsets.left + (i % _columnCount) * (cell_x + cellSize.width);
            CGFloat y = self.contentInsets.top + (i / _columnCount) * (cell_y + cellSize.height) + gridHeaderHeight;
            
            rectDic = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithFloat:x], @"x",
                       [NSNumber numberWithFloat:y], @"y",
                       [NSNumber numberWithFloat:cellSize.width], @"width",
                       [NSNumber numberWithFloat:cellSize.height], @"height",nil];
        }
        if (self.style == POIGridViewStyleHorizontal && self.isPagingEnabled == NO) {
            CGFloat x = (i / _rowCount) * (cell_x + cellSize.width) + gridHeaderWidth;
            CGFloat y = cell_y + (i % _rowCount) * (cell_y + cellSize.height);
            rectDic = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithFloat:x], @"x",
                       [NSNumber numberWithFloat:y], @"y",
                       [NSNumber numberWithFloat:cellSize.width], @"width",
                       [NSNumber numberWithFloat:cellSize.height], @"height",nil];
        }
        if (self.style == POIGridViewStyleHorizontal && self.isPagingEnabled == YES) {
            NSInteger page = i / (_rowCount * _columnCount);
            CGFloat x = page * self.frame.size.width + cell_x + (i % _columnCount) * (cell_x + cellSize.width);
            CGFloat y = cell_y + (i / _columnCount) % _rowCount * (cell_y + cellSize.height);
            rectDic = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithFloat:x], @"x",
                       [NSNumber numberWithFloat:y], @"y",
                       [NSNumber numberWithFloat:cellSize.width], @"width",
                       [NSNumber numberWithFloat:cellSize.height], @"height",nil];
        }
        [self.cellRects setValue:rectDic forKey:[NSString stringWithFormat:@"%ld",(long)i]];
    }
    
    if (self.style == POIGridViewStyleVertical) {
        // 为头尾定位
        if ([_gridHeaderView isKindOfClass:[UIView class]]) {
            [_gridHeaderView setOrigin:CGPointZero];
        }
        
        if ([_gridFooterView isKindOfClass:[UIView class]]) {
            NSInteger rowCount = _cellsTotal / _columnCount + (_cellsTotal % _columnCount ? 1 : 0);
            CGFloat contentHeight = rowCount * cellSize.height + MAX(0, rowCount - 1) * cell_y + gridHeaderHeight;
            [_gridFooterView setOrigin:CGPointMake(0, contentHeight)];
        }
    } else {
        // 为头尾定位
        if ([_gridHeaderView isKindOfClass:[UIView class]]) {
            [_gridHeaderView setOrigin:CGPointZero];
        }
        
        if ([_gridFooterView isKindOfClass:[UIView class]]) {
            NSInteger columnCount = _cellsTotal / _rowCount + (_cellsTotal % _rowCount ? 1 : 0);
            CGFloat contentWidth = columnCount * cellSize.width + MAX(0, columnCount - 1) * cell_x + gridHeaderWidth;
            [_gridFooterView setOrigin:CGPointMake(contentWidth, 0)];
        }
    }
    
    // 设置 GridView 内容大小
    _contentWidth = self.frame.size.width;
    _contentHeight = self.frame.size.height;
    
//    CGFloat tempContentWidth = self.frame.size.width;
//    CGFloat tempContentHeight = self.frame.size.height;
    
    if (self.style == POIGridViewStyleVertical) {
        // 竖向
        if (_columnCount != 0) {
            NSInteger rowCount = _cellsTotal / _columnCount + (_cellsTotal % _columnCount ? 1 : 0);
            _contentHeight = rowCount * cellSize.height + MAX(0, rowCount - 1) * cell_y + gridHeaderHeight + gridFooterHeight + self.contentInsets.top + self.contentInsets.bottom;
            if (self.height > _contentHeight) {
                _contentHeight += self.bounces;
            }
//            tempContentHeight = MAX(_contentHeight, self.frame.size.height + (self.bounces ? 1 : 0));
        }
    }
    
    if (self.style == POIGridViewStyleHorizontal && self.isPagingEnabled == NO) {
        // 横向
        if (_rowCount != 0) {
            NSInteger columnCount = _cellsTotal / _rowCount + (_cellsTotal % _rowCount ? 1 : 0);
            _contentWidth = columnCount * cellSize.width + MAX(0, columnCount - 1) * cell_x + gridHeaderWidth + gridFooterWidth;
            if (self.width > _contentWidth) {
                _contentWidth += self.bounces;
            }
//            tempContentWidth = MAX(_contentWidth, self.frame.size.width + (self.bounces ? 1 : 0));
        }
    }
    
    if (self.style == POIGridViewStyleHorizontal && self.isPagingEnabled == YES) {
        NSInteger page = _cellsTotal / (_rowCount * _columnCount) + (_cellsTotal % (_rowCount * _columnCount) ? 1 : 0);
        _contentWidth = page * self.frame.size.width;
        if (self.width > _contentWidth) {
            _contentWidth += self.bounces;
        }
//        tempContentWidth = MAX(_contentWidth, self.frame.size.width + (self.bounces ? 1 : 0));
    }
    
//    [self setContentSize:CGSizeMake(tempContentWidth, tempContentHeight)];
//    if (self.style == POIGridViewStyleHorizontal) {
//        [self setContentSize:CGSizeMake(_contentWidth, 0)];
//    } else {
//        [self setContentSize:CGSizeMake(0, _contentHeight)];
//    }
    [self setContentSize:CGSizeMake(_contentWidth, _contentHeight)];
    
    [self traverseAllCell];
    
    [self waterFlowScroll];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.style == POIGridViewStyleHorizontal && _reloadSize.height != self.height) {
        [self reloadData];
    } else if (self.style == POIGridViewStyleVertical && _reloadSize.width != self.width) {
        [self reloadData];
    }else {
        [self waterFlowScroll];
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self traverseAllCell];
    [self waterFlowScroll];
}

- (void)reloadData
{
    if (_isLoading) {
        return;
    }
    _isLoading = YES;
    
    _reloadSize = self.size;
    
    [self.backgroundView setSize:self.size];
    if (self.style == POIGridViewStyleVertical) {
        [self.gridHeaderView setWidth:self.width];
    } else {
        [self.gridHeaderView setHeight:self.height];
    }
    
    if (self.style == POIGridViewStyleVertical) {
        [self.gridFooterView setWidth:self.width];
    } else {
        [self.gridFooterView setHeight:self.height];
    }
    
    //移出并添加可视cell到可重用数组
    NSMutableArray *tempCells = [NSMutableArray array];
    for (id cell in self.visibleCells) {
        [self recycleCellIntoReusableQueue:cell];
        [tempCells addObject:cell];
        [cell removeFromSuperview];
    }
    for (id cell in tempCells) {
        [self.visibleCells removeObject:cell];
    }
    
    [self setup];
    
    _isLoading = NO;
}

-(void)waterFlowScroll {
    [_backgroundView setFrame:CGRectMake(self.contentOffset.x, self.contentOffset.y, self.frame.size.width, self.frame.size.height)];
    
    // 证明有数据
    if (self.visibleCells.count > 0) {
        // 判断方向，减少遍历次数
        BOOL direction = YES;       // 正方向 或 负方向
        if (self.style == POIGridViewStyleVertical) {
            direction = self.contentOffset.y >= _oldOffset_y ? 1 : 0;  // 1代表向下滑动,0代表向上滑动
        }
        if (self.style == POIGridViewStyleHorizontal) {
            direction = self.contentOffset.x >= _oldOffset_x ? 1 : 0;  // 1代表向右滑动,0代表向左滑动
        }
        
        POIGridViewCell *firstCell = [self.visibleCells firstObject];
        NSInteger firstIndex = firstCell.indexPath.row;    // 之前加的
        POIGridViewCell *lastCell = [self.visibleCells lastObject];
        NSInteger lastIndex = lastCell.indexPath.row;      // 最新添加的
        if (lastIndex > firstIndex) {
            firstIndex = lastIndex - self.visibleCells.count - 1;
        } else {
            firstIndex = lastIndex + self.visibleCells.count - 1;
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
            
            NSDictionary *rectDic = [self.cellRects objectForKey:[NSString stringWithFormat:@"%ld",(long)i]];
            
            // 在可视范围内则添加
            if (![self isInVisibleCells:i] && [self isVisibleCellWithCellFrame:[self rectWithCellRectDic:rectDic]]) {
                POIGridViewCell *cell = [_dataSource gridView:self cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                [cell setIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                CGRect cellRect = [self rectWithCellRectDic:rectDic];
                [cell setFrame:cellRect];
                [self addSubview:cell];
                [self.visibleCells addObject:cell];
            }
        }
    } else {
        [self traverseAllCell];
    }
    
    // 头
    if ([_gridHeaderView isKindOfClass:[UIView class]]) {
        if ([_gridHeaderView.superview isEqual:self]) {
            // 当已经在视图上时，判断是不是超出范围了, 是则移除
            if ([self isVisibleViewWithFrame:_gridHeaderView.frame] == NO) {
                [_gridHeaderView removeFromSuperview];
            }
        } else {
            // 没有在视图上时，判断是不是在范围内, 是则添加
            if ([self isVisibleViewWithFrame:_gridHeaderView.frame] == YES) {
                [self addSubview:_gridHeaderView];
            }
        }
    }
    // 底
    if ([_gridFooterView isKindOfClass:[UIView class]]) {
        if ([_gridFooterView.superview isEqual:self]) {
            // 当已经在视图上时，判断是不是超出范围了, 是则移除
            if ([self isVisibleViewWithFrame:_gridFooterView.frame] == NO) {
                [_gridFooterView removeFromSuperview];
            }
        } else {
            // 没有在视图上时，判断是不是在范围内, 是则添加
            if ([self isVisibleViewWithFrame:_gridFooterView.frame] == YES) {
                [self addSubview:_gridFooterView];
            }
        }
    }
    
    [self removeUnVisibleCell];
    
    _oldOffset_x = self.contentOffset.x;
    _oldOffset_y = self.contentOffset.y;
}

-(void)traverseAllCell {
    // 重新reloadData
    int foundFlag = 0; // NO没找到过，YES找到过了
    for (NSInteger i = [self traverseWithDivisor:self.cellRects.count/10 FromIndex:0]; i < _cellsTotal; i ++) {
        NSDictionary *rectDic = [self.cellRects objectForKey:[NSString stringWithFormat:@"%ld",(long)i]];
        // 在可视范围内则添加
        if (![self isInVisibleCells:i] && [self isVisibleCellWithCellFrame:[self rectWithCellRectDic:rectDic]]) {
            POIGridViewCell *cell = [_dataSource gridView:self cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            [cell setIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            CGRect cellRect = [self rectWithCellRectDic:rectDic];
            [cell setFrame:cellRect];
            [self addSubview:cell];
            [self.visibleCells addObject:cell];
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
- (NSInteger)traverseWithDivisor:(NSInteger)divisor FromIndex:(NSInteger)index {
    if (self.cellRects.count == 0 || index > (self.cellRects.count - 1)) {
        return 0;
    }
    if (divisor == 0) {
        divisor = 1;
    }
    NSInteger foundIndex = index;
    BOOL isFound = NO;
    for (NSInteger i = index; i < self.cellRects.count; i += divisor) {
        NSDictionary *rectDic = [self.cellRects objectForKey:[NSString stringWithFormat:@"%ld",(long)i]];
        if ([self isVisibleCellWithCellFrame:[self rectWithCellRectDic:rectDic]]) {
            foundIndex = i;
            isFound = YES;
            break;
        }
    }
    
    if (isFound == NO) {
        if (divisor == 1) {
            // 防止死循环找不到数据
            return 0;
        }
        return [self traverseWithDivisor:divisor/2 FromIndex:foundIndex];
    }
    
    if (divisor == 1) {
        return foundIndex;
    } else {
        return [self traverseWithDivisor:divisor/10 FromIndex:foundIndex-divisor];
    }
}

// 判断是不是在可视范围内
-(BOOL)isVisibleCellWithCellFrame:(CGRect)frame {
    CGRect visibleRect = CGRectMake(self.contentOffset.x - self.frame.size.width/2, self.contentOffset.y - self.frame.size.height/2, self.frame.size.width + self.frame.size.width, self.frame.size.height + self.frame.size.height);
    BOOL visibleFlag = CGRectIntersectsRect(visibleRect, frame);
    return visibleFlag;
//    BOOL visibleFlag = YES; // 初始化为可视
//    // 需要加载的cell的可视范围
//    if (self.style == POIGridViewStyleVertical) {
//        // 竖向，检查高度
//        CGFloat offset_top = self.contentOffset.y - self.frame.size.height/2;
//        CGFloat offset_bottom = self.contentOffset.y + self.frame.size.height + self.frame.size.height/2;
////        CGFloat offset_top = self.contentOffset.y;
////        CGFloat offset_bottom = self.contentOffset.y + self.frame.size.height;
//        
//        CGFloat top = frame.origin.y;
//        CGFloat bottom = frame.origin.y + frame.size.height;
//        // 情况1,假设视图高度没有超出屏幕，头尾都没在可视范围内
//        if ((top < offset_top || top > offset_bottom) && (bottom < offset_top || bottom > offset_bottom)) {
//            visibleFlag = NO;   // 不可视
//        }
//        // 情况2,假设视图高度超出屏幕，头尾都没在可视范围内,但视图在可视范围内
//        if (((bottom - top) > self.frame.size.height) && (top < offset_top) && (bottom > offset_bottom)) {
//            visibleFlag = YES;   // 可视
//        }
//    }
//    
//    if (self.style == POIGridViewStyleHorizontal) {
//        // 横向，检查宽度
//        CGFloat offset_left = self.contentOffset.x - self.frame.size.width/2;
//        CGFloat offset_right = self.contentOffset.x + self.frame.size.width + self.frame.size.width/2;
////        CGFloat offset_left = self.contentOffset.x;
////        CGFloat offset_right = self.contentOffset.x + self.frame.size.width;
//        
//        CGFloat left = frame.origin.x;
//        CGFloat right = frame.origin.x + frame.size.width;
//        
//        // 情况1,假设视图高度没有超出屏幕，头尾都没在可视范围内
//        if ((left < offset_left || left > offset_right) && (right < offset_left || right > offset_right)) {
//            visibleFlag = NO;   // 不可视
//        }
//        // 情况2,假设视图高度超出屏幕，头尾都没在可视范围内,但视图在可视范围内
//        if (((right - left) > self.frame.size.width) && (left < offset_left) && (right > offset_right)) {
//            visibleFlag = YES;   // 可视
//        }
//    }
//    return visibleFlag;
}

-(void)removeUnVisibleCell {
    // 遍历完成后，保留可见的cell，将不可见的去除
    NSMutableArray *tempCells = [NSMutableArray array];
    if (self.visibleCells.count > 0 && self.visibleCells.count > _columnCount * _rowCount * 2) {
        for (NSInteger i = 0; i < self.visibleCells.count; i ++) {
            POIGridViewCell *cell = [self.visibleCells objectAtIndex:i];
            // 不可视则移出
            if (![self isVisibleCellWithCellFrame:cell.frame]) {
                [cell removeFromSuperview];
                [self recycleCellIntoReusableQueue:cell];
                [tempCells addObject:cell];
            }
        }
    }
    [self.visibleCells removeObjectsInArray:tempCells];
}

// 判断是不是已经存在
- (BOOL)isInVisibleCells:(NSInteger)row {
    BOOL isIn = NO;
    for (POIGridViewCell *cell in self.visibleCells) {
        if (cell.indexPath.row == row) {
            isIn = YES;
            break;
        }
    }
    return isIn;
}

// 转换CellRectDic为CGRect
- (CGRect)rectWithCellRectDic:(NSDictionary *)rectDic {
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

// 判断View 是不是在显示范围内
- (BOOL)isVisibleViewWithFrame:(CGRect)frame {
    CGRect visibleRect = CGRectMake(self.contentOffset.x - self.frame.size.width/2, self.contentOffset.y - self.frame.size.height/2, self.frame.size.width + self.frame.size.width, self.frame.size.height + self.frame.size.height);
    BOOL visibleFlag = CGRectIntersectsRect(visibleRect, frame); // 初始化为可视
//    BOOL visibleFlag = YES;
//    CGFloat offset_top = self.contentOffset.y;
//    CGFloat offset_bottom = self.contentOffset.y + self.frame.size.height;
//    
//    CGFloat top = frame.origin.y;
//    CGFloat bottom = frame.origin.y + frame.size.height;
//    // 情况1,假设视图高度没有超出屏幕，头尾都没在可视范围内
//    if ((top < offset_top || top > offset_bottom) && (bottom < offset_top || bottom > offset_bottom)) {
//        visibleFlag = NO;   // 不可视
//    }
//    // 情况2,假设视图高度超出屏幕，头尾都没在可视范围内,但视图在可视范围内
//    if (((bottom - top) > self.frame.size.height) && (top < offset_top) && (bottom > offset_bottom)) {
//        visibleFlag = YES;   // 可视
//    }
    return visibleFlag;
}

@end
