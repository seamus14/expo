/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI35_0_0RCTDevMenu.h"

#import "ABI35_0_0RCTBridge+Private.h"
#import "ABI35_0_0RCTDevSettings.h"
#import "ABI35_0_0RCTKeyCommands.h"
#import "ABI35_0_0RCTLog.h"
#import "ABI35_0_0RCTUtils.h"

#if ABI35_0_0RCT_DEV

#if ABI35_0_0RCT_ENABLE_INSPECTOR
#import "ABI35_0_0RCTInspectorDevServerHelper.h"
#endif

NSString *const ABI35_0_0RCTShowDevMenuNotification = @"ABI35_0_0RCTShowDevMenuNotification";

@implementation UIWindow (ABI35_0_0RCTDevMenu)

- (void)ABI35_0_0RCT_motionEnded:(__unused UIEventSubtype)motion withEvent:(UIEvent *)event
{
  if (event.subtype == UIEventSubtypeMotionShake) {
    [[NSNotificationCenter defaultCenter] postNotificationName:ABI35_0_0RCTShowDevMenuNotification object:nil];
  }
}

@end

@implementation ABI35_0_0RCTDevMenuItem
{
  ABI35_0_0RCTDevMenuItemTitleBlock _titleBlock;
  dispatch_block_t _handler;
}

- (instancetype)initWithTitleBlock:(ABI35_0_0RCTDevMenuItemTitleBlock)titleBlock
                           handler:(dispatch_block_t)handler
{
  if ((self = [super init])) {
    _titleBlock = [titleBlock copy];
    _handler = [handler copy];
  }
  return self;
}

ABI35_0_0RCT_NOT_IMPLEMENTED(- (instancetype)init)

+ (instancetype)buttonItemWithTitleBlock:(NSString *(^)(void))titleBlock handler:(dispatch_block_t)handler
{
  return [[self alloc] initWithTitleBlock:titleBlock handler:handler];
}

+ (instancetype)buttonItemWithTitle:(NSString *)title
                            handler:(dispatch_block_t)handler
{
  return [[self alloc] initWithTitleBlock:^NSString *{ return title; } handler:handler];
}

- (void)callHandler
{
  if (_handler) {
    _handler();
  }
}

- (NSString *)title
{
  if (_titleBlock) {
    return _titleBlock();
  }
  return nil;
}

@end

typedef void(^ABI35_0_0RCTDevMenuAlertActionHandler)(UIAlertAction *action);

@interface ABI35_0_0RCTDevMenu () <ABI35_0_0RCTBridgeModule, ABI35_0_0RCTInvalidating>

@end

@implementation ABI35_0_0RCTDevMenu
{
  UIAlertController *_actionSheet;
  NSMutableArray<ABI35_0_0RCTDevMenuItem *> *_extraMenuItems;
}

@synthesize bridge = _bridge;

+ (NSString *)moduleName { return @"ABI35_0_0RCTDevMenu"; }

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (instancetype)init
{
  if ((self = [super init])) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showOnShake)
                                                 name:ABI35_0_0RCTShowDevMenuNotification
                                               object:nil];
    _extraMenuItems = [NSMutableArray new];

#if TARGET_OS_SIMULATOR
    ABI35_0_0RCTKeyCommands *commands = [ABI35_0_0RCTKeyCommands sharedInstance];
    __weak __typeof(self) weakSelf = self;

    // Toggle debug menu
    [commands registerKeyCommandWithInput:@"d"
                            modifierFlags:UIKeyModifierCommand
                                   action:^(__unused UIKeyCommand *command) {
                                     [weakSelf toggle];
                                   }];

    // Toggle element inspector
    [commands registerKeyCommandWithInput:@"i"
                            modifierFlags:UIKeyModifierCommand
                                   action:^(__unused UIKeyCommand *command) {
                                     [weakSelf.bridge.devSettings toggleElementInspector];
                                   }];

    // Reload in normal mode
    [commands registerKeyCommandWithInput:@"n"
                            modifierFlags:UIKeyModifierCommand
                                   action:^(__unused UIKeyCommand *command) {
                                     [weakSelf.bridge.devSettings setIsDebuggingRemotely:NO];
                                   }];
#endif
  }
  return self;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)invalidate
{
  _presentedItems = nil;
  [_actionSheet dismissViewControllerAnimated:YES completion:^(void){}];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showOnShake
{
  if ([_bridge.devSettings isShakeToShowDevMenuEnabled]) {
    [self show];
  }
}

- (void)toggle
{
  if (_actionSheet) {
    [_actionSheet dismissViewControllerAnimated:YES completion:^(void){}];
    _actionSheet = nil;
  } else {
    [self show];
  }
}

- (BOOL)isActionSheetShown
{
  return _actionSheet != nil;
}

- (void)addItem:(NSString *)title handler:(void(^)(void))handler
{
  [self addItem:[ABI35_0_0RCTDevMenuItem buttonItemWithTitle:title handler:handler]];
}

- (void)addItem:(ABI35_0_0RCTDevMenuItem *)item
{
  [_extraMenuItems addObject:item];
}

- (NSArray<ABI35_0_0RCTDevMenuItem *> *)_menuItemsToPresent
{
  NSMutableArray<ABI35_0_0RCTDevMenuItem *> *items = [NSMutableArray new];

  // Add built-in items
  __weak ABI35_0_0RCTBridge *bridge = _bridge;
  __weak ABI35_0_0RCTDevSettings *devSettings = _bridge.devSettings;

  [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitle:@"Reload" handler:^{
    [bridge reload];
  }]];

  if (devSettings.isNuclideDebuggingAvailable) {
    [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitle:[NSString stringWithFormat:@"Debug JS in Nuclide %@", @"\U0001F4AF"] handler:^{
#if ABI35_0_0RCT_ENABLE_INSPECTOR
      [ABI35_0_0RCTInspectorDevServerHelper attachDebugger:@"ReactABI35_0_0Native" withBundleURL:bridge.bundleURL withView: ABI35_0_0RCTPresentedViewController()];
#endif
    }]];
  }

  if (!devSettings.isRemoteDebuggingAvailable) {
    [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitle:@"Remote JS Debugger Unavailable" handler:^{
      UIAlertController *alertController = [UIAlertController
        alertControllerWithTitle:@"Remote JS Debugger Unavailable"
        message:@"You need to include the ABI35_0_0RCTWebSocket library to enable remote JS debugging"
        preferredStyle:UIAlertControllerStyleAlert];
      __weak typeof(alertController) weakAlertController = alertController;
      [alertController addAction:
       [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [weakAlertController dismissViewControllerAnimated:YES completion:nil];
      }]];
      [ABI35_0_0RCTPresentedViewController() presentViewController:alertController animated:YES completion:NULL];
    }]];
  } else {
    [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitleBlock:^NSString *{
      NSString *title = devSettings.isDebuggingRemotely ? @"Stop Remote JS Debugging" : @"Debug JS Remotely";
      if (devSettings.isNuclideDebuggingAvailable) {
        return [NSString stringWithFormat:@"%@ %@", title, @"\U0001F645"];
      } else {
        return title;
      }
    } handler:^{
      devSettings.isDebuggingRemotely = !devSettings.isDebuggingRemotely;
    }]];
  }

  if (devSettings.isLiveReloadAvailable) {
    [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitleBlock:^NSString *{
      return devSettings.isLiveReloadEnabled ? @"Disable Live Reload" : @"Enable Live Reload";
    } handler:^{
      devSettings.isLiveReloadEnabled = !devSettings.isLiveReloadEnabled;
    }]];
    [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitleBlock:^NSString *{
      return devSettings.isProfilingEnabled ? @"Stop Systrace" : @"Start Systrace";
    } handler:^{
      if (devSettings.isDebuggingRemotely) {
        UIAlertController *alertController = [UIAlertController
          alertControllerWithTitle:@"Systrace Unavailable"
          message:@"You need to stop remote JS debugging to enable Systrace"
          preferredStyle:UIAlertControllerStyleAlert];
        __weak typeof(alertController) weakAlertController = alertController;
        [alertController addAction:
         [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
          [weakAlertController dismissViewControllerAnimated:YES completion:nil];
        }]];
        [ABI35_0_0RCTPresentedViewController() presentViewController:alertController animated:YES completion:NULL];
      } else {
        devSettings.isProfilingEnabled = !devSettings.isProfilingEnabled;
      }
    }]];
  }

  if (_bridge.devSettings.isHotLoadingAvailable) {
    [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitleBlock:^NSString *{
      return devSettings.isHotLoadingEnabled ? @"Disable Hot Reloading" : @"Enable Hot Reloading";
    } handler:^{
      devSettings.isHotLoadingEnabled = !devSettings.isHotLoadingEnabled;
    }]];
  }

  [items addObject:[ABI35_0_0RCTDevMenuItem buttonItemWithTitleBlock:^NSString *{
    return @"Toggle Inspector";
  } handler:^{
    [devSettings toggleElementInspector];
  }]];

  [items addObjectsFromArray:_extraMenuItems];
  return items;
}

ABI35_0_0RCT_EXPORT_METHOD(show)
{
  if (_actionSheet || !_bridge || ABI35_0_0RCTRunningInAppExtension()) {
    return;
  }

  NSString *desc = _bridge.bridgeDescription;
  if (desc.length == 0) {
    desc = NSStringFromClass([_bridge class]);
  }
  NSString *title = [NSString stringWithFormat:@"ReactABI35_0_0 Native: Development (%@)", desc];
  // On larger devices we don't have an anchor point for the action sheet
  UIAlertControllerStyle style = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? UIAlertControllerStyleActionSheet : UIAlertControllerStyleAlert;
  _actionSheet = [UIAlertController alertControllerWithTitle:title
                                                     message:@""
                                              preferredStyle:style];

  NSArray<ABI35_0_0RCTDevMenuItem *> *items = [self _menuItemsToPresent];
  for (ABI35_0_0RCTDevMenuItem *item in items) {
    [_actionSheet addAction:[UIAlertAction actionWithTitle:item.title
                                                     style:UIAlertActionStyleDefault
                                                   handler:[self alertActionHandlerForDevItem:item]]];
  }

  [_actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                   style:UIAlertActionStyleCancel
                                                 handler:[self alertActionHandlerForDevItem:nil]]];

  _presentedItems = items;
  [ABI35_0_0RCTPresentedViewController() presentViewController:_actionSheet animated:YES completion:nil];
}

- (ABI35_0_0RCTDevMenuAlertActionHandler)alertActionHandlerForDevItem:(ABI35_0_0RCTDevMenuItem *__nullable)item
{
  return ^(__unused UIAlertAction *action) {
    if (item) {
      [item callHandler];
    }

    self->_actionSheet = nil;
  };
}

#pragma mark - deprecated methods and properties

#define WARN_DEPRECATED_DEV_MENU_EXPORT() ABI35_0_0RCTLogWarn(@"Using deprecated method %s, use ABI35_0_0RCTDevSettings instead", __func__)

- (void)setShakeToShow:(BOOL)shakeToShow
{
  _bridge.devSettings.isShakeToShowDevMenuEnabled = shakeToShow;
}

- (BOOL)shakeToShow
{
  return _bridge.devSettings.isShakeToShowDevMenuEnabled;
}

ABI35_0_0RCT_EXPORT_METHOD(reload)
{
  WARN_DEPRECATED_DEV_MENU_EXPORT();
  [_bridge reload];
}

ABI35_0_0RCT_EXPORT_METHOD(debugRemotely:(BOOL)enableDebug)
{
  WARN_DEPRECATED_DEV_MENU_EXPORT();
  _bridge.devSettings.isDebuggingRemotely = enableDebug;
}

ABI35_0_0RCT_EXPORT_METHOD(setProfilingEnabled:(BOOL)enabled)
{
  WARN_DEPRECATED_DEV_MENU_EXPORT();
  _bridge.devSettings.isProfilingEnabled = enabled;
}

- (BOOL)profilingEnabled
{
  return _bridge.devSettings.isProfilingEnabled;
}

ABI35_0_0RCT_EXPORT_METHOD(setLiveReloadEnabled:(BOOL)enabled)
{
  WARN_DEPRECATED_DEV_MENU_EXPORT();
  _bridge.devSettings.isLiveReloadEnabled = enabled;
}

- (BOOL)liveReloadEnabled
{
  return _bridge.devSettings.isLiveReloadEnabled;
}

ABI35_0_0RCT_EXPORT_METHOD(setHotLoadingEnabled:(BOOL)enabled)
{
  WARN_DEPRECATED_DEV_MENU_EXPORT();
  _bridge.devSettings.isHotLoadingEnabled = enabled;
}

- (BOOL)hotLoadingEnabled
{
  return _bridge.devSettings.isHotLoadingEnabled;
}

@end

#else // Unavailable when not in dev mode

@implementation ABI35_0_0RCTDevMenu

- (void)show {}
- (void)reload {}
- (void)addItem:(NSString *)title handler:(dispatch_block_t)handler {}
- (void)addItem:(ABI35_0_0RCTDevMenu *)item {}
- (BOOL)isActionSheetShown { return NO; }
+ (NSString *)moduleName { return @""; }

@end

@implementation ABI35_0_0RCTDevMenuItem

+ (instancetype)buttonItemWithTitle:(NSString *)title handler:(void(^)(void))handler {return nil;}
+ (instancetype)buttonItemWithTitleBlock:(NSString * (^)(void))titleBlock
                                 handler:(void(^)(void))handler {return nil;}

@end

#endif

@implementation  ABI35_0_0RCTBridge (ABI35_0_0RCTDevMenu)

- (ABI35_0_0RCTDevMenu *)devMenu
{
#if ABI35_0_0RCT_DEV
  return [self moduleForClass:[ABI35_0_0RCTDevMenu class]];
#else
  return nil;
#endif
}

@end
