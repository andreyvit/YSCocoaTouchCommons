// YSTableViewCells.m
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

#import "YSTableViewCells.h"


@implementation YSBindableTableViewCell

@synthesize model=_model;

- (void)loadValuesFromModel {
}

- (void)saveValuesToModel {
}

- (void)startObservingModel {
	
}

- (void)stopObservingModel {
	
}

- (void)dealloc {
	[self stopObservingModel];
	[_model release], _model = nil;
	[super dealloc];
}

- (void)setModel:(id)newModel {
	if (newModel == _model) return;
	[self willChangeValueForKey:@"model"];
	if (_model != nil)
		[self stopObservingModel];
	[_model autorelease]; // can't do release, e.g. if _model.someRetainedProp == newModel
	_model = [newModel retain];
	if (_model != nil) {
		[self loadValuesFromModel];
		[self startObservingModel];
	}
	[self didChangeValueForKey:@"model"];
}

- (void)didMoveToWindow {
	if (self.window == nil || self.model != nil)
		return;
	
	UIViewController *controller = nil;
	for (UIResponder *view = self.superview; view != nil; view = [view nextResponder]) {
		if ([view isKindOfClass:[UIViewController class]]) {
			controller = (UIViewController *)view;
			break;
		}
	}
	if (controller == nil)
		self.model = nil; // no view controller at all, unlikely but possible
	else if ([controller respondsToSelector:@selector(model)])
		self.model = [controller performSelector:@selector(model)];
	else
		self.model = controller;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	[self loadValuesFromModel];
}

@end



#pragma mark
#pragma mark -
#pragma mark



@implementation YSSwitchCell

@synthesize switchView=_switchView, valueKeyPath=_valueKeyPath;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]) {
        _switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
		[_switchView addTarget:self action:@selector(switchValueDidChange) forControlEvents:UIControlEventValueChanged];
		[self.contentView addSubview:_switchView];
    }
    return self;
}

- (void)dealloc {
	[_switchView release], _switchView = nil;
    [super dealloc];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[_switchView sizeToFit];
	CGSize size = _switchView.frame.size;
	_switchView.frame = CGRectMake(self.contentView.frame.size.width - size.width - 10,
								   (self.contentView.frame.size.height - size.height) / 2,
								   size.width,
								   size.height);
}

- (void)loadValuesFromModel {
	if (_valueKeyPath)
		self.switchView.on = [[_model valueForKeyPath:_valueKeyPath] boolValue];
}

- (void)saveValuesToModel {
	if (_valueKeyPath)
		[_model setValue:[NSNumber numberWithBool:self.switchView.on] forKeyPath:_valueKeyPath];
}

- (void)startObservingModel {
	if (_valueKeyPath)
		[_model addObserver:self forKeyPath:_valueKeyPath options:0 context:nil];
}

- (void)stopObservingModel {
	if (_valueKeyPath)
		[_model removeObserver:self forKeyPath:_valueKeyPath];
}

- (void)switchValueDidChange {
	[self saveValuesToModel];
}
		
@end



@implementation YSListCell

@synthesize items=_items, selectedItemIndex=_selectedItemIndex, valueKeyPath=_valueKeyPath;
@synthesize detailControllerTitle=_detailControllerTitle;
@synthesize allowSelection=_allowSelection, allowSelectionWhenEditing=_allowSelectionWhenEditing;

- (id)initWithItems:(NSArray *)values reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]) {
		_items = [[NSArray alloc] initWithArray:values];
		[self setSelectedItemIndex:0];
		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		self.allowSelection = YES;
    }
    return self;
}

- (void)dealloc {
	[_items release], _items = nil;
    [super dealloc];
}

- (NSString *)cellTextForItemAtIndex:(NSInteger)index {
	id value = [_items objectAtIndex:index];
	NSString *result;
	if ([value respondsToSelector:@selector(objectForKey:)]) {
		result = [value objectForKey:@"CellText"];
		if (result == nil)
			result = [value objectForKey:@"Text"];
	} else {
		result = value;
	}
	return result;
}

- (void)setSelectedItemIndex:(NSInteger)index {
	NSParameterAssert(index >= 0);
	NSParameterAssert(index < [_items count]);
	
	_selectedItemIndex = index;
	self.detailTextLabel.text = [self cellTextForItemAtIndex:index];
}

- (id)selectedValue {
	id value = [_items objectAtIndex:_selectedItemIndex];
	if ([value respondsToSelector:@selector(objectForKey:)]) {
		id result = [value objectForKey:@"Value"];
		if (result != nil)
			return result;
	}
	return [NSNumber numberWithInteger:_selectedItemIndex];
}

- (void)setSelectedValue:(id)value {
	int index = 0;
	for (id item in _items) {
		if ([item respondsToSelector:@selector(objectForKey:)]) {
			id itemValue = [item objectForKey:@"Value"];
			if (itemValue != nil && [itemValue isEqual:value]) {
				[self setSelectedItemIndex:index];
				return;
			}
		}
		++index;
	}
	index = [value integerValue];
	[self setSelectedItemIndex:index];
}

- (BOOL)allowSelection {
	return YES;
}

- (UIViewController *)detailController {
	YSListPickerController *c = [[[YSListPickerController alloc] initWithItems:_items selectedItemIndex:_selectedItemIndex delegate:self] autorelease];
	if (self.detailControllerTitle != nil)
		c.navigationItem.title = self.detailControllerTitle;
	else
		c.navigationItem.title = self.textLabel.text;
	return c;
}

- (void)loadValuesFromModel {
	if (_valueKeyPath)
		self.selectedValue = [_model valueForKeyPath:_valueKeyPath];
}

- (void)saveValuesToModel {
	if (_valueKeyPath)
		[_model setValue:self.selectedValue forKeyPath:_valueKeyPath];
}

- (void)startObservingModel {
	if (_valueKeyPath)
		[_model addObserver:self forKeyPath:_valueKeyPath options:0 context:nil];
}

- (void)stopObservingModel {
	if (_valueKeyPath)
		[_model removeObserver:self forKeyPath:_valueKeyPath];
}

- (void)listPickerController:(YSListPickerController *)controller didPickItem:(id)item atIndex:(NSInteger)index {
	[self setSelectedItemIndex:index];
	[self saveValuesToModel];
}

@end



@implementation YSTextFieldCell

@synthesize textField=_textField, valueKeyPath=_valueKeyPath;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]) {
        _textField = [[UITextField alloc] initWithFrame:CGRectZero];
		_textField.delegate = self;
		[self.contentView addSubview:_textField];
    }
    return self;
}

- (void)dealloc {
	[_textField release], _textField = nil;
    [super dealloc];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[_textField sizeToFit];
	CGSize size = _textField.frame.size;
	_textField.frame = CGRectMake(10,
								   (self.contentView.frame.size.height - size.height) / 2,
								   self.contentView.frame.size.width - 20,
								   size.height);
}

- (void)loadValuesFromModel {
	if (_valueKeyPath)
		self.textField.text = [_model valueForKeyPath:_valueKeyPath];
}

- (void)saveValuesToModel {
	if (_valueKeyPath)
		[_model setValue:self.textField.text forKeyPath:_valueKeyPath];
}

- (void)startObservingModel {
	if (_valueKeyPath)
		[_model addObserver:self forKeyPath:_valueKeyPath options:0 context:nil];
}

- (void)stopObservingModel {
	if (_valueKeyPath)
		[_model removeObserver:self forKeyPath:_valueKeyPath];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	[self saveValuesToModel];
}

@end



@implementation YSHeaderLabelCell

@synthesize valueKeyPath=_valueKeyPath;
@synthesize placeholder=_placeholder;
@synthesize detailControllerTitle=_detailControllerTitle, detailControllerRows=_detailControllerRows;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]) {
		self.textLabel.backgroundColor = [UIColor clearColor];
		self.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
		self.placeholder = @"";
		self.detailControllerTitle = @"Edit";
    }
    return self;
}

- (void)dealloc {
	[_defaultBackgroundView release], _defaultBackgroundView = nil;
	[_defaultSelectedBackgroundView release], _defaultSelectedBackgroundView = nil;
	[_placeholder release], _placeholder = nil;
	[_detailControllerTitle release], _detailControllerTitle = nil;
	[_detailControllerRows release], _detailControllerRows = nil;
    [super dealloc];
}

- (void)updateBackground {
	if (self.editing) {
		self.backgroundView = _defaultBackgroundView;
		self.selectedBackgroundView = _defaultSelectedBackgroundView;
	} else {
		self.backgroundView = nil;
		self.selectedBackgroundView = nil;
	}
	[self loadValuesFromModel];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:NO];
	if (_defaultBackgroundView != nil)
		[self updateBackground];
}

- (void)layoutSubviews {
	if (_defaultBackgroundView == nil) {
		_defaultBackgroundView = [self.backgroundView retain];
		_defaultSelectedBackgroundView = [self.selectedBackgroundView retain];
		[self updateBackground];
	}
	[super layoutSubviews];
}

- (void)loadValuesFromModel {
	if (_valueKeyPath) {
		NSString *value = [_model valueForKeyPath:_valueKeyPath];
		if ([value length] == 0 && self.editing) {
			self.textLabel.text = self.placeholder;
			self.textLabel.textColor = [UIColor lightGrayColor];
		} else {
			self.textLabel.text = value;
			self.textLabel.textColor = [UIColor blackColor];
		}
	}
}

- (void)startObservingModel {
	if (_valueKeyPath)
		[_model addObserver:self forKeyPath:_valueKeyPath options:0 context:nil];
}

- (void)stopObservingModel {
	if (_valueKeyPath)
		[_model removeObserver:self forKeyPath:_valueKeyPath];
}

- (BOOL)allowRowSelection {
	return self.editing;
}

- (BOOL)allowSelectionWhenEditing {
	return YES;
}

- (UIViewController *)detailController {
	NSDictionary *section = [NSDictionary dictionaryWithObjectsAndKeys:_detailControllerRows, @"Rows", nil];
	NSArray *sections = [NSArray arrayWithObject:section];
	NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:sections, @"Sections", nil];
	YSFieldEditorController *c = [[[YSFieldEditorController alloc] initWithDictionary:data] autorelease];
	c.editableModel = _model;
	c.navigationItem.title = _detailControllerTitle;
	return c;
}

@end



#pragma mark
#pragma mark -
#pragma mark



@implementation YSListPickerController

- (id)initWithItems:(NSArray *)items selectedItemIndex:(NSInteger)selectedItemIndex delegate:(id<YSListPickerControllerDelegate>)delegate {
	if (self = [super initWithNibName:nil bundle:nil]) {
		_items = [[NSArray alloc] initWithArray:items];
		_selectedItemIndex = selectedItemIndex;
		_delegate = [delegate retain];
	}
	return self;
}

- (void)dealloc {
	[_items release], _items = nil;
	[_delegate release], _delegate = nil;
	[super dealloc];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	return [_items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	id item = [_items objectAtIndex:indexPath.row];
	if (![item respondsToSelector:@selector(objectForKey:)])
		item = [NSDictionary dictionaryWithObject:item forKey:@"Text"];
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Value1"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Value1"] autorelease];
	}
	cell.accessoryType = (indexPath.row == _selectedItemIndex ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);
	cell.textLabel.text = [item objectForKey:@"Text"];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row != _selectedItemIndex) {
		[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedItemIndex inSection:0]].accessoryType = UITableViewCellAccessoryNone;
		_selectedItemIndex = indexPath.row;
		[tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
		[_delegate listPickerController:self didPickItem:[_items objectAtIndex:_selectedItemIndex] atIndex:_selectedItemIndex];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end



@implementation YSFieldEditorController

@synthesize editableModel=_editableModel, delegate=_delegate;

- (void)dealloc {
	[_editableModel release], _editableModel = nil;
	[_delegate release], _delegate = nil;
	[super dealloc];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTouched)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveTouched)] autorelease];
	if (_dirtyData == nil) {
		_dirtyData = [[NSMutableDictionary alloc] init];
	}
}

- (id)valueForKeyPath:(NSString *)keyPath {
	id result = [_dirtyData objectForKey:keyPath];
	if (result != nil)
		return (result == [NSNull null] ? nil : result);
	result = [_editableModel valueForKeyPath:keyPath];
	[_dirtyData setObject:(result == nil ? [NSNull null] : result) forKey:keyPath];
	return result;
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
	[_dirtyData setObject:(value == nil ? [NSNull null] : value) forKey:keyPath];
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
}

- (void)updateModel {
	for (UITableViewCell *cell in [self.tableView visibleCells])
		if ([cell respondsToSelector:@selector(saveValuesToModel)])
			[cell performSelector:@selector(saveValuesToModel)];

	for (NSString *keyPath in _dirtyData) {
		id value = [_dirtyData objectForKey:keyPath];
		if (value == [NSNull null]) value = nil;
		[_editableModel setValue:value forKeyPath:keyPath];
	}
}

- (void)dismiss {
	if ([self.navigationController.viewControllers count] == 1 && self.navigationController.parentViewController.modalViewController == self.navigationController)
		[self.navigationController.parentViewController dismissModalViewControllerAnimated:YES];
	else if (self.navigationController.visibleViewController == self && [self.navigationController.viewControllers count] > 0)
		[self.navigationController popViewControllerAnimated:YES];
}

- (void)cancelTouched {
	[self dismiss];
	[_delegate fieldEditorControllerDidCancel:self];
}

- (void)saveTouched {
	[self updateModel];
	[self dismiss];
	[_delegate fieldEditorControllerDidSave:self];
}

@end



@implementation YSStringFieldEditorController

- (id)initWithKeyPath:(NSString *)keyPath placeholder:(NSString *)placeholder {
	NSDictionary *row = [NSDictionary dictionaryWithObjectsAndKeys:keyPath, @"keyPath", placeholder, @"placeholder", nil];
	NSArray *rows = [NSArray arrayWithObject:row];
	NSDictionary *section = [NSDictionary dictionaryWithObjectsAndKeys:rows, @"Rows", nil];
	NSArray *sections = [NSArray arrayWithObject:section];
	NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:sections, @"Sections", nil];
	if (self = [super initWithDictionary:data]) {
	}
	return self;
}

@end



#pragma mark
#pragma mark -
#pragma mark



static UITableViewCellAccessoryType accessoryTypeForNSString(NSString *s) {
	if ([s isEqualToString:@"disclosure-indicator"])
		return UITableViewCellAccessoryDisclosureIndicator;
	if ([s isEqualToString:@"detail-disclosure-button"])
		return UITableViewCellAccessoryDetailDisclosureButton;
	if ([s isEqualToString:@"none"])
		return UITableViewCellAccessoryNone;
	if ([s isEqualToString:@"checkmark"])
		return UITableViewCellAccessoryCheckmark;
	NSCAssert1(NO, @"Unknown accessory type: '%@'", s);
	return UITableViewCellAccessoryNone;
}

static UITableViewCellEditingStyle editingStyleFromNSString(NSString *s) {
	if ([s isEqualToString:@"delete"])
		return UITableViewCellEditingStyleDelete;
	if ([s isEqualToString:@"insert"])
		return UITableViewCellEditingStyleInsert;
	if ([s isEqualToString:@"none"])
		return UITableViewCellEditingStyleNone;
	NSCAssert1(NO, @"Unknown editing style: '%@'", s);
	return UITableViewCellEditingStyleNone;
}


@implementation YSSettingsTableViewController

@synthesize plistName=_plistName;

- (id)initWithPlistName:(NSString *)name {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.plistName = name;
	}
	return self;
}

- (id)initWithDictionary:(NSDictionary *)data {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_data = [data copy];
	}
	return self;
}

- (void)loadView {
	self.tableView = [[[UITableView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame style:UITableViewStyleGrouped] autorelease];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view = self.tableView;
}

- (void)dealloc {
	[_currentStateData release], _currentStateData = nil;
	[_previousVisibility release], _previousVisibility = nil;
	[_data release], _data = nil;
	[_plistName release], _plistName = nil;
	[super dealloc];
}

- (void)refilterData {
	NSDictionary *oldData = _data;
	NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:oldData];
	
	NSDictionary *oldVisibility = _previousVisibility;
	NSMutableDictionary *newVisibility = [NSMutableDictionary dictionary];
	NSMutableArray *insertedRows = [NSMutableArray array];
	NSMutableArray *deletedRows = [NSMutableArray array];
	NSMutableIndexSet *insertedSections = [NSMutableIndexSet indexSet];
	NSMutableIndexSet *deletedSections = [NSMutableIndexSet indexSet];
	
	NSArray *oldSections = [newData objectForKey:@"Sections"];
	NSMutableArray *newSections = [NSMutableArray arrayWithCapacity:[oldSections count]];
	NSInteger section = 0, deletionSection = 0, insertionSection = 0, updatingSection = 0;
	NSInteger row, deletionRow, insertionRow;
	for (NSDictionary *oldSection in oldSections) {
		NSMutableDictionary *newSection = [NSMutableDictionary dictionaryWithDictionary:oldSection];
		
		NSArray *oldRows = [newSection objectForKey:@"Rows"];
		NSMutableArray *newRows = [NSMutableArray arrayWithCapacity:[oldRows count]];
		row = 0, deletionRow = 0, insertionRow = 0;
		BOOL wereAnyRowsVisible = NO;
		NSMutableArray *insertedRowsInSection = [NSMutableArray array];
		NSMutableArray *deletedRowsInSection = [NSMutableArray array];
		for (NSDictionary *oldRow in oldRows) {
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
			
			NSString *predicateString = [oldRow objectForKey:@"Predicate"];
			BOOL rowVisible = YES;
			if (predicateString != nil) {
				NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateString];
				rowVisible = [predicate evaluateWithObject:self];
			}
//			NSDictionary *newRow = [NSMutableDictionary dictionaryWithDictionary:oldRow];
//			[newRows addObject:[NSDictionary dictionaryWithDictionary:newRow]];
			
			if (oldVisibility) {
				BOOL wasVisible = [[oldVisibility objectForKey:indexPath] boolValue];
				if (wasVisible != rowVisible)
					if (rowVisible)
						[insertedRowsInSection addObject:[NSIndexPath indexPathForRow:insertionRow inSection:insertionSection]];
					else
						[deletedRowsInSection addObject:[NSIndexPath indexPathForRow:deletionRow inSection:updatingSection]];
				wereAnyRowsVisible |= wasVisible;
				if (wasVisible)
					++deletionRow;
				if (rowVisible)
					++insertionRow;
			}
			
			if (rowVisible)
				[newRows addObject:oldRow];
			[newVisibility setObject:[NSNumber numberWithBool:rowVisible] forKey:indexPath];
			++row;
		}
		[newSection setObject:[NSArray arrayWithArray:newRows] forKey:@"Rows"];
		
		BOOL areAnyRowsVisible = [newRows count] > 0;
		if (oldVisibility) {
			if (areAnyRowsVisible != wereAnyRowsVisible) {
				if (areAnyRowsVisible)
					[insertedSections addIndex:insertionSection];
				else
					[deletedSections addIndex:deletionSection];
			} else {
				[insertedRows addObjectsFromArray:insertedRowsInSection];
				[deletedRows addObjectsFromArray:deletedRowsInSection];
			}
			if (wereAnyRowsVisible)
				++deletionSection;
			if (areAnyRowsVisible)
				++insertionSection;
			if (wereAnyRowsVisible)
				++updatingSection;
		}
		
		if (areAnyRowsVisible)
			[newSections addObject:[NSDictionary dictionaryWithDictionary:newSection]];
		++section;
	}
	[newData setObject:[NSArray arrayWithArray:newSections] forKey:@"Sections"];
	
	[_currentStateData release], _currentStateData = nil;
	_currentStateData = [[NSDictionary alloc] initWithDictionary:newData];
	
	[_previousVisibility release], _previousVisibility = nil;
	_previousVisibility = [[NSDictionary alloc] initWithDictionary:newVisibility];
	
	if (oldVisibility) {
		[self.tableView beginUpdates];
		[self.tableView deleteSections:deletedSections withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView deleteRowsAtIndexPaths:deletedRows withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView insertRowsAtIndexPaths:insertedRows withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView insertSections:insertedSections withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView endUpdates];
	}
}

- (void)viewDidLoad {
	if (_data == nil) {
		if (self.plistName == nil)
			self.plistName = self.nibName;
		if (self.plistName == nil)
			self.plistName = NSStringFromClass([self class]);
		
		NSBundle *bundle = self.nibBundle;
		if (bundle == nil) bundle = [NSBundle mainBundle];
		
		NSString *path = [bundle pathForResource:self.plistName ofType:@"plist"];
		_data = [[NSDictionary alloc] initWithContentsOfFile:path];
		NSAssert(_data != nil, @"Failed to load .plist for a settings table");
	}
	self.tableView.allowsSelectionDuringEditing = YES;
	
	[self refilterData];
	
	[self.tableView reloadData];
	UITableViewCell *firstCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	for (UIView *subview in firstCell.contentView.subviews) {
		if ([subview canBecomeFirstResponder]) {
			[subview becomeFirstResponder];
			break;
		}
	}
}

- (void)viewDidUnload {
	[_currentStateData release], _currentStateData = nil;
	[_previousVisibility release], _previousVisibility = nil;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];
	[self refilterData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
    return [sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:section];
	NSArray *rows = [sectionInfo objectForKey:@"Rows"];
    return [rows count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:section];
	return [sectionInfo objectForKey:@"Header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:section];
	return [sectionInfo objectForKey:@"Footer"];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:indexPath.section];
	NSArray *rows = [sectionInfo objectForKey:@"Rows"];
	NSDictionary *row = [rows objectAtIndex:indexPath.row];
	
	NSNumber *h = [row objectForKey:@"Height"];
	if (h != nil)
		return [h floatValue];
	
	NSString *factory = [row objectForKey:@"Factory"];
	SEL selector = NSSelectorFromString([factory stringByAppendingString:@"CellHeightForRow:"]);
	if ([self respondsToSelector:selector]) {
		CGFloat height;
		NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[[self class] instanceMethodSignatureForSelector:selector]];
		[inv setSelector:selector];
		[inv setTarget:self];
		[inv invoke];
		[inv getReturnValue:&height];
		return height;
	}
	
	return 44;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:indexPath.section];
	NSArray *rows = [sectionInfo objectForKey:@"Rows"];
	NSDictionary *row = [rows objectAtIndex:indexPath.row];
	
    NSString *factory = [row objectForKey:@"Factory"];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:factory];
    if (cell == nil) {
		NSString *selectorName = [factory stringByAppendingString:@"CellWithReuseIdentifier:row:"];
		cell = [self performSelector:NSSelectorFromString(selectorName) withObject:factory withObject:row];
    }
	
	NSString *accessory = [row objectForKey:@"Accessory"];
	if ([accessory length] > 0)
		cell.accessoryType = accessoryTypeForNSString(accessory);

	accessory = [row objectForKey:@"EditingAccessory"];
	if ([accessory length] > 0)
		cell.editingAccessoryType = accessoryTypeForNSString(accessory);
	
    NSString *configureMethod = [row objectForKey:@"ConfigureSelector"];
	if (configureMethod != nil)
		[self performSelector:NSSelectorFromString(configureMethod) withObject:cell];
	
	for (NSString *key in row)
		if (tolower([key characterAtIndex:0]) == [key characterAtIndex:0])
			[cell setValue:[row objectForKey:key] forKeyPath:key];
	
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:indexPath.section];
	NSArray *rows = [sectionInfo objectForKey:@"Rows"];
	NSDictionary *row = [rows objectAtIndex:indexPath.row];
	
	NSString *editingStyle = [row objectForKey:@"EditingStyle"];
	if ([editingStyle length] > 0)
		return editingStyleFromNSString(editingStyle);
	else
		return UITableViewCellEditingStyleNone;
}

- (UITableViewCell *)switchCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[YSSwitchCell alloc] initWithReuseIdentifier:cellId] autorelease];
}

- (UITableViewCell *)textFieldCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[YSTextFieldCell alloc] initWithReuseIdentifier:cellId] autorelease];
}

- (UITableViewCell *)listCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[YSListCell alloc] initWithItems:[row objectForKey:@"Items"] reuseIdentifier:cellId] autorelease];
}

- (UITableViewCell *)headerLabelCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[YSHeaderLabelCell alloc] initWithReuseIdentifier:cellId] autorelease];
}

- (UITableViewCell *)staticCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId] autorelease];
}

- (UITableViewCell *)staticSettingsCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId] autorelease];
}

- (UITableViewCell *)staticContactsCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:cellId] autorelease];
}

- (UITableViewCell *)staticSubtitleCellWithReuseIdentifier:(NSString *)cellId row:(NSDictionary *)row {
	return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId] autorelease];
}

- (CGFloat)headerLabelCellHeightForRow:(NSDictionary *)row {
	return 63;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:indexPath.section];
	NSArray *rows = [sectionInfo objectForKey:@"Rows"];
	NSDictionary *row = [rows objectAtIndex:indexPath.row];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *action = [row objectForKey:(cell.editing ? @"EditingAction" : @"Action")];
	
	if (action != nil || cell.allowSelectionNow)
		return indexPath;
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *sections = [_currentStateData objectForKey:@"Sections"];
	NSDictionary *sectionInfo = [sections objectAtIndex:indexPath.section];
	NSArray *rows = [sectionInfo objectForKey:@"Rows"];
	NSDictionary *row = [rows objectAtIndex:indexPath.row];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *action = [row objectForKey:(cell.editing ? @"EditingAction" : @"Action")];
	
	UIViewController *detailController = nil;
	if (action != nil)
		detailController = [self performSelector:NSSelectorFromString(action) withObject:cell];
	if (detailController == nil && cell.allowSelectionNow)
		detailController = cell.detailController;
	
	if (detailController != nil)
		[self.navigationController pushViewController:detailController animated:YES];
	else if (self == self.navigationController.topViewController)
		[tableView deselectRowAtIndexPath:indexPath animated:YES];	
}

@end


@implementation UITableViewCell (YSSettingsTableViewControllerMagicMethods)

- (UIViewController *)detailController {
	return nil;
}

- (BOOL)allowSelectionNow {
	return (self.editing ? self.allowSelectionWhenEditing : self.allowSelection);
}

- (BOOL)allowSelection {
	return NO;
}

- (BOOL)allowSelectionWhenEditing {
	return NO;
}

@end
