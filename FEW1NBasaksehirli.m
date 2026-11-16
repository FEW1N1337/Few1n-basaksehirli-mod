#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// ============================================================================
// FEW1N Başakşehirli Mod v1.0.2 - PURE Objective-C (Zero Dependencies / Sideload Safe)
// - Alamofire & NSURLSession HTTP/HTTPS Inspector
// - PayPaymentModalView paymentButtonTapped -> Direct Local Payment Successful UI
// - Insufficient Balance / General Error Alert Suppressor
// - VideoDuty Instant Completion & SideMenu Visibility
// ============================================================================

static UIButton *floatingBtn = nil;
static UIView *menuView = nil;
static UITextView *networkLogView = nil;
static NSMutableArray *capturedLogs = nil;

// ----------------------------------------------------------------------------
// Helpers: Window & Logging
// ----------------------------------------------------------------------------
static UIWindow *GetKeyWindow(void) {
    if (@available(iOS 15.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) return w;
                }
                if (ws.windows.count > 0) return ws.windows.firstObject;
            }
        }
    }
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) return w;
    }
    return [UIApplication sharedApplication].windows.firstObject;
}

static void FEW1NLog(NSString *text) {
    if (!text) return;
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterNoStyle
                                                         timeStyle:NSDateFormatterMediumStyle];
    NSString *entry = [NSString stringWithFormat:@"[%@] %@", timestamp, text];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!capturedLogs) {
            capturedLogs = [NSMutableArray new];
        }
        [capturedLogs insertObject:entry atIndex:0];
        if (capturedLogs.count > 120) {
            [capturedLogs removeLastObject];
        }
        if (networkLogView) {
            networkLogView.text = [capturedLogs componentsJoinedByString:@"\n--------------------\n"];
        }
    });
}

// ----------------------------------------------------------------------------
// Safe Swizzling Helpers (Safe for Superclass-Inherited Methods)
// ----------------------------------------------------------------------------
static void SwizzleInstanceMethod(Class cls, SEL origSel, SEL newSel, IMP newImp, const char *types) {
    if (!cls) return;
    Method origMethod = class_getInstanceMethod(cls, origSel);
    if (!origMethod) return;
    IMP origImp = method_getImplementation(origMethod);
    if (origImp == newImp) return;
    const char *origTypes = method_getTypeEncoding(origMethod) ?: types;
    class_addMethod(cls, newSel, origImp, origTypes);
    class_replaceMethod(cls, origSel, newImp, origTypes);
}

static void SwizzleClassMethod(Class cls, SEL origSel, SEL newSel, IMP newImp, const char *types) {
    if (!cls) return;
    Class metaCls = object_getClass((id)cls);
    Method origMethod = class_getClassMethod(cls, origSel);
    if (!origMethod) return;
    IMP origImp = method_getImplementation(origMethod);
    if (origImp == newImp) return;
    const char *origTypes = method_getTypeEncoding(origMethod) ?: types;
    class_addMethod(metaCls, newSel, origImp, origTypes);
    class_replaceMethod(metaCls, origSel, newImp, origTypes);
}

// ----------------------------------------------------------------------------
// Helpers: Find Main Binary Base & Active PayViewController & Trigger UI
// ----------------------------------------------------------------------------
static uintptr_t GetBasaksehirliBaseAddress(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "/basaksehirli.app/basaksehirli")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return (uintptr_t)_dyld_get_image_header(0);
}

static UIViewController *FindViewControllerOfClass(UIViewController *vc, Class targetCls) {
    if (!vc || !targetCls) return nil;
    if ([vc isKindOfClass:targetCls]) return vc;

    if (vc.presentedViewController) {
        UIViewController *found = FindViewControllerOfClass(vc.presentedViewController, targetCls);
        if (found) return found;
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        for (UIViewController *child in [nav.viewControllers reverseObjectEnumerator]) {
            UIViewController *found = FindViewControllerOfClass(child, targetCls);
            if (found) return found;
        }
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)vc;
        if (tab.selectedViewController) {
            UIViewController *found = FindViewControllerOfClass(tab.selectedViewController, targetCls);
            if (found) return found;
        }
        for (UIViewController *child in tab.viewControllers) {
            UIViewController *found = FindViewControllerOfClass(child, targetCls);
            if (found) return found;
        }
    }
    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *found = FindViewControllerOfClass(child, targetCls);
        if (found) return found;
    }
    return nil;
}

static UIViewController *FindActivePayViewController(UIView *anchorView) {
    Class payCls = NSClassFromString(@"_TtC12basaksehirli17PayViewController");
    if (!payCls) return nil;

    // 1. Check responder chain starting from anchorView (e.g. PayPaymentModalView)
    UIResponder *responder = anchorView;
    while (responder) {
        if ([responder isKindOfClass:payCls]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }

    // 2. Walk keyWindow view controller hierarchy
    UIWindow *kw = GetKeyWindow();
    if (kw && kw.rootViewController) {
        UIViewController *found = FindViewControllerOfClass(kw.rootViewController, payCls);
        if (found) return found;
    }

    // 3. Fallback across all app windows
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.rootViewController) {
            UIViewController *found = FindViewControllerOfClass(w.rootViewController, payCls);
            if (found) return found;
        }
    }
    return nil;
}

static UIViewController *TopMostViewController(void) {
    UIViewController *top = GetKeyWindow().rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top;
}

typedef void *(*SwiftAllocObjectFn)(void *, size_t, size_t);
typedef void (*SwiftWeakInitFn)(void *, void *);

static BOOL TriggerLocalPaymentSuccessUI(UIViewController *payVC) {
    if (!payVC) return NO;
    uintptr_t base = GetBasaksehirliBaseAddress();
    if (!base) return NO;

    SwiftAllocObjectFn allocObj = (SwiftAllocObjectFn)dlsym(RTLD_DEFAULT, "swift_allocObject");
    SwiftWeakInitFn weakInit = (SwiftWeakInitFn)dlsym(RTLD_DEFAULT, "swift_weakInit");
    if (!allocObj || !weakInit) {
        void *swiftCore = dlopen("/usr/lib/swift/libswiftCore.dylib", RTLD_LAZY);
        if (swiftCore) {
            if (!allocObj) allocObj = (SwiftAllocObjectFn)dlsym(swiftCore, "swift_allocObject");
            if (!weakInit) weakInit = (SwiftWeakInitFn)dlsym(swiftCore, "swift_weakInit");
        }
    }

    if (!allocObj || !weakInit) {
        FEW1NLog(@"❌ swift_allocObject veya swift_weakInit bulunamadı.");
        return NO;
    }

    void *box = allocObj((void *)(base + 0xd5a8c0), 0x18, 7);
    if (!box) return NO;
    weakInit((void *)((uintptr_t)box + 0x10), (__bridge void *)payVC);

    void (*paymentSuccessFn)(void *) = (void (*)(void *))(base + 0xf2300);
    dispatch_async(dispatch_get_main_queue(), ^{
        paymentSuccessFn(box);
    });
    return YES;
}

static void EnableAllButtonsRecursively(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        btn.enabled = YES;
        btn.userInteractionEnabled = YES;
        btn.alpha = 1.0;
    }
    for (UIView *sub in view.subviews) {
        EnableAllButtonsRecursively(sub);
    }
}

// ----------------------------------------------------------------------------
// 1. Hook: Network Inspector (Alamofire SessionDelegate + NSURLSession)
// ----------------------------------------------------------------------------
static BOOL ShouldLogURL(NSString *url) {
    if (!url || url.length == 0) return NO;
    return [url containsString:@"Pay"] ||
           [url containsString:@"Duty"] ||
           [url containsString:@"basaksehir"];
}

static void LogOutgoingRequest(NSURLRequest *request) {
    if (!request) return;
    NSString *url = request.URL.absoluteString;
    if (!ShouldLogURL(url)) return;

    NSString *method = request.HTTPMethod ?: @"GET";
    NSString *bodyStr = @"";
    if (request.HTTPBody && request.HTTPBody.length > 0) {
        NSString *utf8 = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        bodyStr = utf8 ?: [NSString stringWithFormat:@"<binary %lu bytes>", (unsigned long)request.HTTPBody.length];
    }
    FEW1NLog([NSString stringWithFormat:@"➡️ REQ: %@ %@\nBody: %@", method, url, bodyStr]);
}

static id few1n_dataTaskWithRequestOnly(id self, SEL _cmd, NSURLRequest *request) {
    LogOutgoingRequest(request);
    SEL newSel = NSSelectorFromString(@"few1n_orig_dataTaskWithRequestOnly:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        return ((id (*)(id, SEL, NSURLRequest *))method_getImplementation(m))(self, _cmd, request);
    }
    return nil;
}

static id few1n_dataTaskWithRequest(id self, SEL _cmd, NSURLRequest *request, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
    LogOutgoingRequest(request);
    NSString *url = request.URL.absoluteString;

    void (^customHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (ShouldLogURL(url)) {
            NSString *respStr = @"";
            if (data && data.length > 0) {
                NSString *utf8 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                respStr = utf8 ?: [NSString stringWithFormat:@"<binary %lu bytes>", (unsigned long)data.length];
            }
            NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            FEW1NLog([NSString stringWithFormat:@"⬅️ RESP (%ld): %@\nBody: %@", (long)statusCode, url, respStr]);
        }
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };

    SEL newSel = NSSelectorFromString(@"few1n_orig_dataTaskWithRequest:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        return ((id (*)(id, SEL, NSURLRequest *, id))method_getImplementation(m))(self, _cmd, request, customHandler);
    }
    return nil;
}

static void few1n_alamofire_didReceiveData(id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data) {
    NSString *url = dataTask.originalRequest.URL.absoluteString ?: dataTask.currentRequest.URL.absoluteString;
    if (ShouldLogURL(url)) {
        NSInteger statusCode = [dataTask.response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)dataTask.response).statusCode : 0;
        NSString *respStr = @"";
        if (data && data.length > 0) {
            NSString *utf8 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            respStr = utf8 ?: [NSString stringWithFormat:@"<binary %lu bytes>", (unsigned long)data.length];
        }
        FEW1NLog([NSString stringWithFormat:@"⬅️ AF RESP (%ld): %@\nBody: %@", (long)statusCode, url ?: @"?", respStr]);
    }

    SEL newSel = NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveData:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL, id, id, id))method_getImplementation(m))(self, _cmd, session, dataTask, data);
    }
}

// ----------------------------------------------------------------------------
// 2. Hook: SideMenuViewModel isBasakParaVisible -> YES
// ----------------------------------------------------------------------------
static BOOL few1n_isBasakParaVisible(id self, SEL _cmd) {
    return YES;
}

// ----------------------------------------------------------------------------
// 3. Hook: PayBalanceView layoutSubviews -> 500,00 ₺
// ----------------------------------------------------------------------------
static void few1n_payBalanceView_layoutSubviews(UIView *self, SEL _cmd) {
    SEL newSel = NSSelectorFromString(@"few1n_orig_layoutSubviews");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL))method_getImplementation(m))(self, _cmd);
    }
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)sub;
            if ([lbl.text containsString:@"₺"] || [lbl.text containsString:@"0,00"]) {
                lbl.text = @"500,00 ₺";
            }
        }
    }
}

// ----------------------------------------------------------------------------
// 4. Hook: PayAlertManager showInsufficientBalance -> No-op
// ----------------------------------------------------------------------------
static void few1n_showInsufficientBalance(id self, SEL _cmd, id arg1) {
    FEW1NLog(@"[Hook] Insufficient Balance alert engellendi.");
}

static void few1n_showGeneralErrorAlert(id self, SEL _cmd, id arg1) {
    FEW1NLog(@"[Hook] General Error alert engellendi.");
}

// ----------------------------------------------------------------------------
// 5. Hook: PayPaymentModalView -> Direct Local Payment Successful UI
// ----------------------------------------------------------------------------
static void few1n_modal_didMoveToWindow(UIView *self, SEL _cmd) {
    SEL newSel = NSSelectorFromString(@"few1n_orig_modalDidMoveToWindow");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL))method_getImplementation(m))(self, _cmd);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        EnableAllButtonsRecursively(self);
    });
}

static void few1n_modal_contractCheckboxTapped(UIView *self, SEL _cmd, id sender) {
    SEL newSel = NSSelectorFromString(@"few1n_orig_contractCheckboxTapped:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL, id))method_getImplementation(m))(self, _cmd, sender);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        EnableAllButtonsRecursively(self);
    });
}

static void few1n_modal_paymentButtonTapped(UIView *self, SEL _cmd) {
    FEW1NLog(@"🎯 PayPaymentModalView.paymentButtonTapped yakalandı! Bankaya gitmeden yerel Payment Successful UI tetikleniyor...");

    UIViewController *payVC = FindActivePayViewController(self);
    if (payVC && TriggerLocalPaymentSuccessUI(payVC)) {
        FEW1NLog(@"✅ PayViewController Payment Successful UI akışı başlatıldı.");
        return;
    }

    FEW1NLog(@"⚠️ Aktif PayViewController bulunamadı, yedek UI uyarısı gösteriliyor.");
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = TopMostViewController();
        if (topVC) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ İşlem Başarılı (Yerel UI)"
                                                                           message:@"PayViewController bulunamadığı için yedek yerel başarı ekranı gösterildi."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [topVC presentViewController:alert animated:YES completion:nil];
        }
    });
}

// ----------------------------------------------------------------------------
// 6. Hook: VideoDutyViewController playerView:didChangeToState:
// ----------------------------------------------------------------------------
static void few1n_playerView_didChangeToState(id self, SEL _cmd, id player, NSInteger state) {
    if (state == 1 || state == 3) {
        FEW1NLog(@"[VideoDuty] Oynatma başladı, anında state: 0 (bitti) gönderiliyor.");
        state = 0;
    }
    SEL newSel = NSSelectorFromString(@"few1n_orig_playerViewDidChangeToState:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL, id, NSInteger))method_getImplementation(m))(self, _cmd, player, state);
    }
}

// ----------------------------------------------------------------------------
// UI: Floating FEW1N Menu
// ----------------------------------------------------------------------------
static void ToggleMenu(void) {
    if (!menuView) return;
    [UIView animateWithDuration:0.25 animations:^{
        menuView.hidden = !menuView.hidden;
    }];
}

@interface UIButton (FEW1NActions)
- (void)toggleMenu;
- (void)handlePan:(UIPanGestureRecognizer *)p;
- (void)openWalletRoute;
- (void)openQRRoute;
- (void)testLocalSuccessUI;
- (void)clearLogs;
@end

@implementation UIButton (FEW1NActions)
- (void)toggleMenu { ToggleMenu(); }
- (void)handlePan:(UIPanGestureRecognizer *)p {
    UIView *v = p.view;
    CGPoint trans = [p translationInView:v.superview];
    v.center = CGPointMake(v.center.x + trans.x, v.center.y + trans.y);
    [p setTranslation:CGPointZero inView:v.superview];
}
- (void)openWalletRoute {
    NSURL *url = [NSURL URLWithString:@"basaksehirli://wallet"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}
- (void)openQRRoute {
    NSURL *url = [NSURL URLWithString:@"basaksehirli://wallet/qr"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}
- (void)testLocalSuccessUI {
    UIViewController *payVC = FindActivePayViewController(nil);
    if (payVC && TriggerLocalPaymentSuccessUI(payVC)) {
        FEW1NLog(@"✅ Menüden PayViewController Payment Successful UI tetiklendi.");
        ToggleMenu();
    } else {
        FEW1NLog(@"⚠️ PayViewController şu an açık değil (önce BaşakPara ekranını aç).");
    }
}
- (void)clearLogs {
    [capturedLogs removeAllObjects];
    networkLogView.text = @"[+] Loglar temizlendi.";
}
@end

static void CreateFEW1NFloatingUI(void) {
    UIWindow *keyWindow = GetKeyWindow();
    if (!keyWindow || floatingBtn) return;

    floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingBtn.frame = CGRectMake(15, 120, 60, 60);
    floatingBtn.backgroundColor = [UIColor colorWithRed:0.09 green:0.55 blue:0.95 alpha:0.9];
    [floatingBtn setTitle:@"FEW1N" forState:UIControlStateNormal];
    floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    floatingBtn.layer.cornerRadius = 30;
    floatingBtn.layer.borderWidth = 2.0;
    floatingBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    floatingBtn.clipsToBounds = YES;
    [floatingBtn addTarget:floatingBtn action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:floatingBtn action:@selector(handlePan:)];
    [floatingBtn addGestureRecognizer:pan];

    CGFloat width = keyWindow.bounds.size.width - 40;
    CGFloat height = 490;
    menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, width, height)];
    menuView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95];
    menuView.layer.cornerRadius = 16;
    menuView.layer.borderWidth = 1.5;
    menuView.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.8].CGColor;
    menuView.clipsToBounds = YES;
    menuView.hidden = YES;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, width - 80, 24)];
    title.text = @"⚡ FEW1N MOD MENU v1.0.2";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:14];
    [menuView addSubview:title];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(width - 45, 10, 35, 28);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:floatingBtn action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:closeBtn];

    CGFloat halfW = (width - 40) / 2.0;

    UIButton *btnWallet = [UIButton buttonWithType:UIButtonTypeSystem];
    btnWallet.frame = CGRectMake(16, 45, halfW, 36);
    btnWallet.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:0.85];
    [btnWallet setTitle:@"💳 Cüzdan Aç" forState:UIControlStateNormal];
    [btnWallet setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnWallet.layer.cornerRadius = 8;
    [btnWallet addTarget:floatingBtn action:@selector(openWalletRoute) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnWallet];

    UIButton *btnQR = [UIButton buttonWithType:UIButtonTypeSystem];
    btnQR.frame = CGRectMake(24 + halfW, 45, halfW, 36);
    btnQR.backgroundColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.2 alpha:0.85];
    [btnQR setTitle:@"📷 QR Aç" forState:UIControlStateNormal];
    [btnQR setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnQR.layer.cornerRadius = 8;
    [btnQR addTarget:floatingBtn action:@selector(openQRRoute) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnQR];

    UIButton *btnTestSuccess = [UIButton buttonWithType:UIButtonTypeSystem];
    btnTestSuccess.frame = CGRectMake(16, 88, halfW, 32);
    btnTestSuccess.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:0.35 alpha:0.9];
    [btnTestSuccess setTitle:@"✅ UI Başarı Test" forState:UIControlStateNormal];
    [btnTestSuccess setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnTestSuccess.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btnTestSuccess.layer.cornerRadius = 6;
    [btnTestSuccess addTarget:floatingBtn action:@selector(testLocalSuccessUI) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnTestSuccess];

    UIButton *btnClear = [UIButton buttonWithType:UIButtonTypeSystem];
    btnClear.frame = CGRectMake(24 + halfW, 88, halfW, 32);
    btnClear.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.85];
    [btnClear setTitle:@"🗑️ Log Temizle" forState:UIControlStateNormal];
    [btnClear setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClear.titleLabel.font = [UIFont systemFontOfSize:12];
    btnClear.layer.cornerRadius = 6;
    [btnClear addTarget:floatingBtn action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnClear];

    UILabel *logLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 128, width - 32, 20)];
    logLabel.text = @"📡 CANLI AĞ TRAFİĞİ (Alamofire / v2/Pay):";
    logLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:1.0 alpha:1.0];
    logLabel.font = [UIFont boldSystemFontOfSize:12];
    [menuView addSubview:logLabel];

    networkLogView = [[UITextView alloc] initWithFrame:CGRectMake(16, 152, width - 32, height - 168)];
    networkLogView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];
    networkLogView.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0];
    networkLogView.font = [UIFont fontWithName:@"Courier" size:11];
    networkLogView.editable = NO;
    networkLogView.layer.cornerRadius = 8;
    if (capturedLogs.count > 0) {
        networkLogView.text = [capturedLogs componentsJoinedByString:@"\n--------------------\n"];
    } else {
        networkLogView.text = @"[+] FEW1N Network Inspector v1.0.2 devrede...\n[+] İstekler bekleniyor...";
    }
    [menuView addSubview:networkLogView];

    [keyWindow addSubview:menuView];
    [keyWindow addSubview:floatingBtn];
}

// ----------------------------------------------------------------------------
// Hook Installer (Idempotent, safe to re-run after launch for dynamic frameworks)
// ----------------------------------------------------------------------------
static void InstallAllHooks(void) {
    // 1a. Swizzle NSURLSession dataTaskWithRequest:completionHandler:
    Class sessionCls = [NSURLSession class];
    SwizzleInstanceMethod(sessionCls,
                          @selector(dataTaskWithRequest:completionHandler:),
                          NSSelectorFromString(@"few1n_orig_dataTaskWithRequest:"),
                          (IMP)few1n_dataTaskWithRequest,
                          "@@:@@");

    // 1b. Swizzle NSURLSession dataTaskWithRequest: (used by Alamofire)
    SwizzleInstanceMethod(sessionCls,
                          @selector(dataTaskWithRequest:),
                          NSSelectorFromString(@"few1n_orig_dataTaskWithRequestOnly:"),
                          (IMP)few1n_dataTaskWithRequestOnly,
                          "@@:@");

    // 1c. Also check concrete __NSURLSessionLocal class if it overrides either selector
    Class localSessionCls = NSClassFromString(@"__NSURLSessionLocal");
    if (localSessionCls) {
        SwizzleInstanceMethod(localSessionCls,
                              @selector(dataTaskWithRequest:completionHandler:),
                              NSSelectorFromString(@"few1n_orig_dataTaskWithRequest:"),
                              (IMP)few1n_dataTaskWithRequest,
                              "@@:@@");
        SwizzleInstanceMethod(localSessionCls,
                              @selector(dataTaskWithRequest:),
                              NSSelectorFromString(@"few1n_orig_dataTaskWithRequestOnly:"),
                              (IMP)few1n_dataTaskWithRequestOnly,
                              "@@:@");
    }

    // 1d. Swizzle Alamofire SessionDelegate URLSession:dataTask:didReceiveData:
    Class afDelegateCls = NSClassFromString(@"_TtC9Alamofire15SessionDelegate");
    if (afDelegateCls) {
        SwizzleInstanceMethod(afDelegateCls,
                              NSSelectorFromString(@"URLSession:dataTask:didReceiveData:"),
                              NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveData:"),
                              (IMP)few1n_alamofire_didReceiveData,
                              "v@:@@@");
    }

    // 2. Swizzle SideMenuViewModel isBasakParaVisible
    Class sideCls = NSClassFromString(@"_TtC12basaksehirli17SideMenuViewModel");
    if (sideCls) {
        SwizzleInstanceMethod(sideCls,
                              NSSelectorFromString(@"isBasakParaVisible"),
                              NSSelectorFromString(@"few1n_orig_isBasakParaVisible"),
                              (IMP)few1n_isBasakParaVisible,
                              "B@:");
    }

    // 3. Swizzle PayBalanceView layoutSubviews
    Class balCls = NSClassFromString(@"_TtC12basaksehirli14PayBalanceView");
    if (balCls) {
        SwizzleInstanceMethod(balCls,
                              @selector(layoutSubviews),
                              NSSelectorFromString(@"few1n_orig_layoutSubviews"),
                              (IMP)few1n_payBalanceView_layoutSubviews,
                              "v@:");
    }

    // 4. Swizzle PayAlertManager
    Class alertCls = NSClassFromString(@"_TtC12basaksehirli15PayAlertManager");
    if (alertCls) {
        SwizzleClassMethod(alertCls,
                           NSSelectorFromString(@"showInsufficientBalance:"),
                           NSSelectorFromString(@"few1n_orig_showInsufficientBalance:"),
                           (IMP)few1n_showInsufficientBalance,
                           "v@:@");

        SwizzleClassMethod(alertCls,
                           NSSelectorFromString(@"showGeneralErrorAlert:"),
                           NSSelectorFromString(@"few1n_orig_showGeneralErrorAlert:"),
                           (IMP)few1n_showGeneralErrorAlert,
                           "v@:@");
    }

    // 5. Swizzle PayPaymentModalView (actual UIKit target for payment modal button)
    Class modalCls = NSClassFromString(@"_TtC12basaksehirli19PayPaymentModalView");
    if (modalCls) {
        SwizzleInstanceMethod(modalCls,
                              @selector(didMoveToWindow),
                              NSSelectorFromString(@"few1n_orig_modalDidMoveToWindow"),
                              (IMP)few1n_modal_didMoveToWindow,
                              "v@:");

        SwizzleInstanceMethod(modalCls,
                              NSSelectorFromString(@"contractCheckboxTapped:"),
                              NSSelectorFromString(@"few1n_orig_contractCheckboxTapped:"),
                              (IMP)few1n_modal_contractCheckboxTapped,
                              "v@:@");

        SwizzleInstanceMethod(modalCls,
                              NSSelectorFromString(@"paymentButtonTapped"),
                              NSSelectorFromString(@"few1n_orig_paymentButtonTapped"),
                              (IMP)few1n_modal_paymentButtonTapped,
                              "v@:");
    }

    // 6. Swizzle VideoDutyViewController
    Class videoCls = NSClassFromString(@"_TtC12basaksehirli23VideoDutyViewController");
    if (videoCls) {
        SwizzleInstanceMethod(videoCls,
                              NSSelectorFromString(@"playerView:didChangeToState:"),
                              NSSelectorFromString(@"few1n_orig_playerViewDidChangeToState:"),
                              (IMP)few1n_playerView_didChangeToState,
                              "v@:@q");
    }
}

// ----------------------------------------------------------------------------
// Constructor
// ----------------------------------------------------------------------------
__attribute__((constructor))
static void FEW1NInit(void) {
    FEW1NLog(@"⚡ FEW1N Basaksehirli Native Mod v1.0.2 yüklendi.");
    InstallAllHooks();

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        InstallAllHooks();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            InstallAllHooks();
            CreateFEW1NFloatingUI();
        });
    }];
}
