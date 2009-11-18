// YSTableViewCells.h
//
// A set of cells for implementing Preferences-like tables.
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

#import <UIKit/UIKit.h>

// cell with UISwitch
@class YSSwitchCell;
// cell that displays a value selected from a list of predefined options
@class YSListCell;
@class YSHeaderLabelCell;

// presents a list of items in UITableView, selected item has a checkmark
// used by YSListCell detailController
@class YSListPickerController;
@protocol YSListPickerControllerDelegate;

// presents an editing screen with the given rows and Cancel/Save buttons
@class YSFieldEditorController;
@protocol YSFieldEditorControllerDelegate;
// a specialization of YSFieldEditorController for editing a single text field
@class YSStringFieldEditorController;


// Presents a grouped UITableView defined declaratively using a dictionary/plist.
// Uses selectors and KVC to keep things flexible.
@class YSSettingsTableViewController;


////////////////////////////////////////////////////////////////////////////////
// Presents a grouped UITableView defined declaratively using a dictionary/plist.
// Uses selectors and KVC to keep things flexible.
//
// Data/plist must be a dictionary, required items are marked with (*):
// - Sections: array
// - - Header: string
// - - Footer: string
// - - Rows: array
// - - - (item): dictionary
// - - - - Factory: string (*), a prefix of the selector to create the cell, e.g. "list" results in "[self listCellWithReuseIdentifier:id row:rowDict]" being called
// - - - - ConfigureSelector: string, a selector to populate the cell with data, e.g. "configureNameCell:"
// - - - - Action: string, a selector to run when the cell is selected, e.g. "controllerForEditingNameCell:" (pushes the returned view controller if any)
// - - - - textLabel.text: string, the text to use for the cell
// - - - - ...any key that starts with a lowercase letter is set using [cell setValue:value forKeyPath:key]
// - - - - ...any key that starts with an uppercase letter is ignored and can be used by cell factory/configure methods
//
// Predefined values for "Factory" are "switch" and "list".
// Define your own factory methods (myCellWithReuseIdentifier:row:) to add other cell types ("my").
//
// "List" additionally interprets "Items" key as an array to pass to the constructor of YSListCell.
// See the properties of cell classes for possible KVC keys.
// If a cell class responds to "detailController" message, it will be called when the cell is selected if no action is defined in the plist.
//
// Note that cell classes in this file will use this view controller as their default model; define "-(id)model" method to override.
@interface YSSettingsTableViewController : UITableViewController {
	NSString *_plistName;
	NSDictionary *_data;
	NSDictionary *_currentStateData;
	NSDictionary *_previousVisibility;
}

// Use this to create the controller programmatically. Can also use initWithNibName:bundle:
// (or set nibName via Inteface Builder) to load data from a plist named after the nib file.
- (id)initWithDictionary:(NSDictionary *)data;
- (id)initWithPlistName:(NSString *)name;

@property(nonatomic, copy) NSString *plistName;

@end


// informal protocol
@interface UITableViewCell (YSSettingsTableViewControllerMagicMethods)

@property(nonatomic, readonly, retain) UIViewController *detailController;
@property(nonatomic, readonly) BOOL allowSelection;
@property(nonatomic, readonly) BOOL allowSelectionWhenEditing;
@property(nonatomic, readonly) BOOL allowSelectionNow;

@end



////////////////////////////////////////////////////////////////////////////////
// helper base class for cells that use KVC/KVO to communicate their value;
// when deriving is not handy, just copy the code into your own class
@interface YSBindableTableViewCell : UITableViewCell {
	id _model;
}

- (void)loadValuesFromModel;
- (void)saveValuesToModel;
- (void)startObservingModel;
- (void)stopObservingModel;

// if not set explicitly, defaults to the closest view controller in responder chain
@property(nonatomic, retain) id model;

@end


////////////////////////////////////////////////////////////////////////////////
@interface YSSwitchCell : YSBindableTableViewCell {
	UISwitch *_switchView;
	NSString *_valueKeyPath;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property(nonatomic,retain,readonly) UISwitch *switchView;
@property(nonatomic,copy) NSString *valueKeyPath;

@end


////////////////////////////////////////////////////////////////////////////////
@interface YSListPickerController : UITableViewController {
	NSArray *_items;
	id<YSListPickerControllerDelegate> _delegate;
	NSInteger _selectedItemIndex;
}

- (id)initWithItems:(NSArray *)values selectedItemIndex:(NSInteger)selectedItemIndex delegate:(id<YSListPickerControllerDelegate>)delegate;

@end

@protocol YSListPickerControllerDelegate <NSObject>
@required

- (void)listPickerController:(YSListPickerController *)controller didPickItem:(id)item atIndex:(NSInteger)index;

@end


////////////////////////////////////////////////////////////////////////////////
@interface YSFieldEditorController : YSSettingsTableViewController {
	NSMutableDictionary *_dirtyData;
	id _editableModel;
	id<YSFieldEditorControllerDelegate> _delegate;
}

@property(nonatomic, retain) id<YSFieldEditorControllerDelegate> delegate;
@property(nonatomic, retain) id editableModel;

@end

@protocol YSFieldEditorControllerDelegate <NSObject>
@required

- (void)fieldEditorControllerDidSave:(YSFieldEditorController *)controller;
- (void)fieldEditorControllerDidCancel:(YSFieldEditorController *)controller;

@end


@interface YSStringFieldEditorController : YSFieldEditorController {
}

- (id)initWithKeyPath:(NSString *)keyPath placeholder:(NSString *)placeholder;

@end


////////////////////////////////////////////////////////////////////////////////
@interface YSTextFieldCell : YSBindableTableViewCell <UITextFieldDelegate> {
	UITextField *_textField;
	NSString *_valueKeyPath;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property(nonatomic,retain,readonly) UITextField *textField;
@property(nonatomic,copy) NSString *valueKeyPath;

@end


////////////////////////////////////////////////////////////////////////////////
@interface YSListCell : YSBindableTableViewCell <YSListPickerControllerDelegate> {
	NSArray *_items;
	NSInteger _selectedItemIndex;
	NSString *_valueKeyPath;
	NSString *_detailControllerTitle;
	UIViewController *_controller;
	BOOL _allowSelection, _allowSelectionWhenEditing;
}

- (id)initWithItems:(NSArray *)values reuseIdentifier:(NSString *)reuseIdentifier;

@property(nonatomic,retain,readonly) NSArray *items;
@property(nonatomic) NSInteger selectedItemIndex;
@property(nonatomic, retain) id selectedValue; // value provided by Value key, index if none
@property(nonatomic,copy) NSString *valueKeyPath;

@property(nonatomic) BOOL allowSelection;
@property(nonatomic) BOOL allowSelectionWhenEditing;

@property(nonatomic,copy) NSString *detailControllerTitle;

@end


////////////////////////////////////////////////////////////////////////////////
@interface YSHeaderLabelCell : YSBindableTableViewCell {
	UIView *_defaultBackgroundView;
	UIView *_defaultSelectedBackgroundView;
	NSString *_valueKeyPath;
	NSString *_placeholder;

	NSString *_detailControllerTitle;
	NSArray *_detailControllerRows;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property(nonatomic,copy) NSString *placeholder;
@property(nonatomic,copy) NSString *valueKeyPath;

@property(nonatomic,copy) NSString *detailControllerTitle;
@property(nonatomic,copy) NSArray *detailControllerRows;

@end

