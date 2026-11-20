#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// ============================================================================
// FEW1N Başakşehirli Mod v1.0.9 - PURE Objective-C (Zero Dependencies / Sideload Safe)
// - Pay/newTransaction QR & Payment Flow Solver (Auto-Mock & Local Success Animation)
// - Crash-Free PayViewController Local Payment Success UI (PaymentProgressView + Lottie)
// - BaşakPara Schema-Safe Mock (Patches GetUserWallet/payDashboard/userPayments -> 5000)
// - "Cevapla Kazan" Auto-Fetch & Auto-Answer (GET v2/question + POST v2/question/<id>/answer)
// - Clean JSON-Only Alamofire & NSURLSession Inspector + Live Clipboard Copy
// - Insufficient Balance / General Error Alert Suppressor & VideoDuty Skip
// ============================================================================

// ============================================================================

@interface FEW1NOverlayWindow : UIWindow
@end

@implementation FEW1NOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) {
        return nil; // Empty areas pass through touches to underlying camera / app
    }
    return hit;
}
@end

static FEW1NOverlayWindow *gOverlayWindow = nil;
static UIButton *floatingBtn = nil;
static UIView *menuView = nil;
static UITextView *networkLogView = nil;
static NSMutableArray *capturedLogs = nil;
static NSDictionary<NSString *, NSString *> *gLatestApiHeaders = nil;
static BOOL gEnableMockPay = YES;

static UIWindowScene *GetActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                if (ws.activationState == UISceneActivationStateForegroundActive) {
                    return ws;
                }
            }
        }
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                return (UIWindowScene *)scene;
            }
        }
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.windowScene) return w.windowScene;
        }
    }
    return nil;
}

static void EnsureOverlayWindow(void) {
    if (@available(iOS 13.0, *)) {
        if (gOverlayWindow && !gOverlayWindow.windowScene) {
            gOverlayWindow.windowScene = GetActiveWindowScene();
        }
    }

    if (gOverlayWindow && gOverlayWindow.rootViewController && gOverlayWindow.rootViewController.view) {
        gOverlayWindow.hidden = NO;
        return;
    }

    CGRect bounds = [UIScreen mainScreen].bounds;
    UIWindowScene *activeScene = GetActiveWindowScene();

    if (activeScene) {
        gOverlayWindow = [[FEW1NOverlayWindow alloc] initWithWindowScene:activeScene];
    } else {
        gOverlayWindow = [[FEW1NOverlayWindow alloc] initWithFrame:bounds];
    }

    gOverlayWindow.windowLevel = UIWindowLevelStatusBar + 9999.0;
    gOverlayWindow.backgroundColor = [UIColor clearColor];

    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.userInteractionEnabled = YES;
    gOverlayWindow.rootViewController = rootVC;

    gOverlayWindow.hidden = NO;
}

static BOOL ShouldMockURL(NSString *url) {
    if (!gEnableMockPay || !url || url.length == 0) return NO;
    NSString *lower = [url lowercaseString];
    if (![lower containsString:@"basaksehir.bel.tr"]) return NO;

    return [lower containsString:@"/pay/getuserwallet"] ||
           [lower containsString:@"/pay/paydashboard"] ||
           [lower containsString:@"/pay/userpayments"] ||
           [lower containsString:@"/pay/newtransaction"] ||
           [lower containsString:@"/pay/newpayment"] ||
           [lower containsString:@"/pay/usertransactions"] ||
           [lower containsString:@"/user/scanqrcode"] ||
           [lower containsString:@"/user/qrcode"] ||
           [lower containsString:@"/pay/"];
}

static NSData *ApplyMockPatchForURL(NSString *url, NSData *origData, NSInteger *outStatusCode) {
    if (!ShouldMockURL(url)) return nil;
    NSString *lower = [url lowercaseString];

    if ([lower containsString:@"/pay/getuserwallet"]) {
        if (outStatusCode) *outStatusCode = 200;
        return [@"{\"walletPoint\":\"5000\"}" dataUsingEncoding:NSUTF8StringEncoding];
    }

    if ([lower containsString:@"/pay/paydashboard"]) {
        if (origData && origData.length > 0) {
            NSError *err = nil;
            id jsonObj = [NSJSONSerialization JSONObjectWithData:origData options:NSJSONReadingMutableContainers error:&err];
            if (!err && [jsonObj isKindOfClass:[NSMutableDictionary class]]) {
                NSMutableDictionary *dict = (NSMutableDictionary *)jsonObj;
                dict[@"point"] = @"5000";
                NSData *patched = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&err];
                if (patched && !err) {
                    if (outStatusCode) *outStatusCode = 200;
                    return patched;
                }
            }
        }
        return nil;
    }

    if ([lower containsString:@"/pay/userpayments"]) {
        if (origData && origData.length > 0) {
            NSError *err = nil;
            id jsonObj = [NSJSONSerialization JSONObjectWithData:origData options:NSJSONReadingMutableContainers error:&err];
            if (!err && [jsonObj isKindOfClass:[NSMutableDictionary class]]) {
                NSMutableDictionary *dict = (NSMutableDictionary *)jsonObj;
                dict[@"point"] = @"5000";
                NSData *patched = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&err];
                if (patched && !err) {
                    if (outStatusCode) *outStatusCode = 200;
                    return patched;
                }
            }
        }
        return nil;
    }

    if ([lower containsString:@"/pay/newtransaction"]) {
        if (outStatusCode) *outStatusCode = 200;
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        if (origData && origData.length > 0) {
            NSError *err = nil;
            id jsonObj = [NSJSONSerialization JSONObjectWithData:origData options:NSJSONReadingMutableContainers error:&err];
            if (!err && [jsonObj isKindOfClass:[NSDictionary class]]) {
                [dict addEntriesFromDictionary:(NSDictionary *)jsonObj];
            }
        }
        dict[@"status"] = @YES;
        dict[@"isSuccess"] = @YES;
        dict[@"success"] = @YES;
        dict[@"result"] = @YES;
        dict[@"message"] = @"İşlem başarıyla tamamlandı";
        dict[@"transactionId"] = dict[@"transactionId"] ?: @"FEW1N-TX-1337";
        dict[@"id"] = dict[@"id"] ?: @"1337";
        dict[@"amount"] = @(50.0);
        dict[@"price"] = @(50.0);
        dict[@"fee"] = @(50.0);
        dict[@"tutar"] = @(50.0);
        dict[@"ucret"] = @(50.0);
        dict[@"totalAmount"] = @(50.0);
        dict[@"paymentAmount"] = @(50.0);
        dict[@"point"] = @"50";
        dict[@"walletPoint"] = @"5000";
        dict[@"merchantName"] = @"Başakşehir Belediyesi";
        dict[@"storeName"] = @"Başakşehir";
        dict[@"title"] = @"Başakşehir Belediyesi";
        dict[@"stationCode"] = @"101";
        dict[@"stationName"] = @"Başakşehir Şarj İstasyonu";
        dict[@"date"] = @"2026-11-20";

        NSMutableDictionary *innerData = [NSMutableDictionary dictionary];
        if ([dict[@"data"] isKindOfClass:[NSDictionary class]]) {
            [innerData addEntriesFromDictionary:dict[@"data"]];
        }
        innerData[@"status"] = @YES;
        innerData[@"isSuccess"] = @YES;
        innerData[@"success"] = @YES;
        innerData[@"result"] = @YES;
        innerData[@"message"] = @"İşlem başarıyla tamamlandı";
        innerData[@"transactionId"] = innerData[@"transactionId"] ?: @"FEW1N-TX-1337";
        innerData[@"id"] = innerData[@"id"] ?: @"1337";
        innerData[@"amount"] = @(50.0);
        innerData[@"price"] = @(50.0);
        innerData[@"fee"] = @(50.0);
        innerData[@"tutar"] = @(50.0);
        innerData[@"ucret"] = @(50.0);
        innerData[@"totalAmount"] = @(50.0);
        innerData[@"paymentAmount"] = @(50.0);
        innerData[@"point"] = @"50";
        innerData[@"walletPoint"] = @"5000";
        innerData[@"merchantName"] = @"Başakşehir Belediyesi";
        innerData[@"storeName"] = @"Başakşehir";
        innerData[@"title"] = @"Başakşehir Belediyesi";
        innerData[@"stationCode"] = @"101";
        innerData[@"stationName"] = @"Başakşehir Şarj İstasyonu";
        innerData[@"date"] = @"2026-11-20";
        dict[@"data"] = innerData;

        NSError *err = nil;
        return [NSJSONSerialization dataWithJSONObject:dict options:0 error:&err];
    }

    if ([lower containsString:@"/pay/newpayment"]) {
        if (outStatusCode) *outStatusCode = 200;
        NSDictionary *mockPay = @{
            @"status": @YES,
            @"isSuccess": @YES,
            @"success": @YES,
            @"message": @"Ödeme başarıyla tamamlandı",
            @"point": @"5000",
            @"walletPoint": @"5000",
            @"data": @{
                @"status": @YES,
                @"isSuccess": @YES,
            }
        };
        NSError *err = nil;
        return [NSJSONSerialization dataWithJSONObject:mockPay options:0 error:&err];
    }

    if ([lower containsString:@"/user/scanqrcode"]) {
        if (outStatusCode) *outStatusCode = 200;
        NSDictionary *mockScan = @{
            @"status": @YES,
            @"isSuccess": @YES,
            @"success": @YES,
            @"result": @YES,
            @"message": @"QR başarıyla okundu",
            @"amount": @(50.0),
            @"price": @(50.0),
            @"fee": @(50.0),
            @"tutar": @(50.0),
            @"ucret": @(50.0),
            @"totalAmount": @(50.0),
            @"paymentAmount": @(50.0),
            @"point": @"50",
            @"walletPoint": @"5000",
            @"merchantName": @"Başakşehir Belediyesi",
            @"storeName": @"Başakşehir",
            @"title": @"Başakşehir Belediyesi",
            @"date": @"2026-11-20",
            @"data": @{
                @"status": @YES,
                @"isSuccess": @YES,
                @"success": @YES,
                @"result": @YES,
                @"amount": @(50.0),
                @"price": @(50.0),
                @"fee": @(50.0),
                @"tutar": @(50.0),
                @"ucret": @(50.0),
                @"point": @"50",
                @"walletPoint": @"5000"
            }
        };
        NSError *err = nil;
        return [NSJSONSerialization dataWithJSONObject:mockScan options:0 error:&err];
    }

    if ([lower containsString:@"/pay/"]) {
        if (outStatusCode) *outStatusCode = 200;
        NSDictionary *defaultPay = @{
            @"status": @YES,
            @"isSuccess": @YES,
            @"success": @YES,
            @"result": @YES,
            @"message": @"İşlem başarılı",
            @"amount": @(50.0),
            @"price": @(50.0),
            @"fee": @(50.0),
            @"tutar": @(50.0),
            @"ucret": @(50.0),
            @"point": @"50",
            @"walletPoint": @"5000",
            @"data": @{
                @"status": @YES,
                @"isSuccess": @YES,
                @"amount": @(50.0),
                @"price": @(50.0),
                @"fee": @(50.0),
                @"tutar": @(50.0),
                @"ucret": @(50.0),
                @"point": @"50",
                @"walletPoint": @"5000"
            }
        };
        NSError *err = nil;
        return [NSJSONSerialization dataWithJSONObject:defaultPay options:0 error:&err];
    }

    return nil;
}

static id HeadersLock(void) {
    static id lockObj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lockObj = [NSObject new];
    });
    return lockObj;
}

// ----------------------------------------------------------------------------
// Helpers: Window & Logging
// ----------------------------------------------------------------------------
static UIWindow *GetKeyWindow(void) {
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(connectedScenes)]) {
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

static id GetObjCIvarObject(id obj, const char *ivarName) {
    if (!obj || !ivarName) return nil;
    Ivar ivar = class_getInstanceVariable([obj class], ivarName);
    if (!ivar) return nil;
    ptrdiff_t offset = ivar_getOffset(ivar);
    if (offset <= 0 || offset > 4096) return nil;
    void *ptr = *(void * const *)((const uint8_t *)(__bridge const void *)obj + offset);
    if (!ptr) return nil;
    return (__bridge id)ptr;
}

static void UpdateBalanceLabelsRecursively(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        if (lbl.text && [lbl.text containsString:@"₺"]) {
            lbl.text = @"500,00 ₺";
        }
    }
    for (UIView *sub in view.subviews) {
        UpdateBalanceLabelsRecursively(sub);
    }
}

typedef void (*SwiftPaymentSuccessFn)(void * __attribute__((swift_context))) __attribute__((swiftcall));

static BOOL TriggerLocalPaymentSuccessUI(UIViewController *payVC) {
    if (!payVC) return NO;

    id modalObj = GetObjCIvarObject(payVC, "paymentModalView");
    id progressObj = GetObjCIvarObject(payVC, "paymentProgressView");
    UIView *modalView = [modalObj isKindOfClass:[UIView class]] ? (UIView *)modalObj : nil;
    UIView *progressView = [progressObj isKindOfClass:[UIView class]] ? (UIView *)progressObj : nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (modalView) {
            [modalView endEditing:YES];
            modalView.hidden = YES;
            modalView.alpha = 0.0;
        }

        if (progressView) {
            if (!progressView.superview && payVC.view) {
                progressView.frame = payVC.view.bounds;
                progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [payVC.view addSubview:progressView];
            }
            progressView.hidden = NO;
            progressView.alpha = 1.0;
            if (payVC.view) {
                [payVC.view bringSubviewToFront:progressView];
            }

            id titleObj = GetObjCIvarObject(progressView, "titleLabel");
            if ([titleObj isKindOfClass:[UILabel class]]) {
                ((UILabel *)titleObj).text = @"İşlem Başarılı";
            }
            id subObj = GetObjCIvarObject(progressView, "subtitleLabel");
            if ([subObj isKindOfClass:[UILabel class]]) {
                ((UILabel *)subObj).text = @"Ödemeniz başarıyla tamamlandı";
            }

            Dl_info info;
            uintptr_t base = 0;
            IMP imp = class_getMethodImplementation([payVC class], @selector(viewDidLoad));
            if (imp && dladdr((const void *)imp, &info) && info.dli_fbase) {
                uintptr_t candidate = (uintptr_t)info.dli_fbase;
                if (*(const uint32_t *)(candidate + 0x1d71fc) == 0xd10183ffU) {
                    base = candidate;
                }
            }
            if (!base) {
                uintptr_t fallback = GetBasaksehirliBaseAddress();
                if (fallback && *(const uint32_t *)(fallback + 0x1d71fc) == 0xd10183ffU) {
                    base = fallback;
                }
            }
            if (base) {
                SwiftPaymentSuccessFn showSuccessFn = (SwiftPaymentSuccessFn)(base + 0x1d71fc);
                showSuccessFn((__bridge void *)progressView);
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    progressView.alpha = 0.0;
                } completion:^(BOOL finished) {
                    if (progressView.alpha < 0.1) {
                        progressView.hidden = YES;
                    }
                }];
            });
        } else {
            FEW1NLog(@"⚠️ paymentProgressView ivar bulunamadı, yedek yerel başarı uyarısı gösteriliyor.");
            UIViewController *topVC = TopMostViewController();
            if (topVC) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ İşlem Başarılı"
                                                                               message:@"Ödemeniz başarıyla tamamlandı (Yerel UI)"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
                [topVC presentViewController:alert animated:YES completion:nil];
            }
        }

        if (payVC.view) {
            UpdateBalanceLabelsRecursively(payVC.view);
        }
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
// 1. Hook: Network Inspector & API Header Capture
// ----------------------------------------------------------------------------
static BOOL ShouldLogURL(NSString *url) {
    if (!url || url.length == 0) return NO;
    NSString *lower = [url lowercaseString];
    if ([lower containsString:@"app-image.basaksehir.bel.tr"] ||
        [lower containsString:@"/cover/image"] ||
        [lower containsString:@".jpg"] ||
        [lower containsString:@".jpeg"] ||
        [lower containsString:@".png"] ||
        [lower containsString:@".webp"] ||
        [lower containsString:@".gif"]) {
        return NO;
    }
    return [lower containsString:@"pay"] ||
           [lower containsString:@"duty"] ||
           [lower containsString:@"question"] ||
           [lower containsString:@"reward"] ||
           [lower containsString:@"oyunlar"] ||
           [lower containsString:@"basaksehir"];
}

static void CaptureApiHeadersIfNeeded(NSURLSession *session, NSURLRequest *request) {
    if (!request || !request.URL.host) return;
    NSString *host = request.URL.host.lowercaseString;
    if (![host containsString:@"api-app.basaksehir.bel.tr"]) return;

    NSMutableDictionary<NSString *, NSString *> *merged = [NSMutableDictionary dictionary];
    if (session && [session.configuration.HTTPAdditionalHeaders isKindOfClass:[NSDictionary class]]) {
        [session.configuration.HTTPAdditionalHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && [obj isKindOfClass:[NSString class]]) {
                merged[key] = obj;
            }
        }];
    }
    if ([request.allHTTPHeaderFields isKindOfClass:[NSDictionary class]]) {
        [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && [obj isKindOfClass:[NSString class]]) {
                merged[key] = obj;
            }
        }];
    }
    if (merged.count == 0) return;

    @synchronized(HeadersLock()) {
        BOOL hasAuth = (merged[@"Authorization"] != nil || merged[@"authorization"] != nil);
        BOOL existingHasAuth = (gLatestApiHeaders[@"Authorization"] != nil || gLatestApiHeaders[@"authorization"] != nil);
        if (!gLatestApiHeaders || hasAuth || !existingHasAuth) {
            gLatestApiHeaders = [merged copy];
        }
    }
}

static void LogOutgoingRequest(NSURLSession *session, NSURLRequest *request) {
    if (!request) return;
    CaptureApiHeadersIfNeeded(session, request);

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

static NSMutableURLRequest *BuildApiRequest(NSString *urlString, NSString *method, NSDictionary *jsonBody) {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = method ?: @"GET";
    req.timeoutInterval = 20.0;

    NSDictionary<NSString *, NSString *> *headers = nil;
    @synchronized(HeadersLock()) {
        headers = gLatestApiHeaders;
    }
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *val, BOOL *stop) {
        NSString *lower = key.lowercaseString;
        if (![lower isEqualToString:@"content-length"] &&
            ![lower isEqualToString:@"host"] &&
            ![lower isEqualToString:@"content-type"]) {
            [req setValue:val forHTTPHeaderField:key];
        }
    }];

    if (jsonBody) {
        NSError *err = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:&err];
        if (data && !err) {
            req.HTTPBody = data;
            [req setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        }
    }
    return req;
}

static void RefreshUserPoints(void) {
    FEW1NLog(@"🔄 Güncel puan sorgulanıyor (GET /api/v2/user/point)...");
    NSMutableURLRequest *req = BuildApiRequest(@"https://api-app.basaksehir.bel.tr/api/v2/user/point", @"GET", nil);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            FEW1NLog([NSString stringWithFormat:@"❌ user/point hatası: %@", error.localizedDescription]);
            return;
        }
        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        NSString *body = data ? ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"") : @"";
        FEW1NLog([NSString stringWithFormat:@"⭐ Güncel Puan (%ld): %@", (long)code, body]);
    }];
    [task resume];
}

static void SubmitQuestionAtIndex(NSArray *questions, NSUInteger idx) {
    if (!questions || idx >= questions.count) {
        FEW1NLog(@"✅ Tüm Cevapla Kazan soruları işlendi.");
        RefreshUserPoints();
        return;
    }

    id rawQ = questions[idx];
    if (![rawQ isKindOfClass:[NSDictionary class]]) {
        SubmitQuestionAtIndex(questions, idx + 1);
        return;
    }
    NSDictionary *q = (NSDictionary *)rawQ;
    id qIdObj = q[@"id"];
    NSString *qId = (qIdObj && qIdObj != [NSNull null]) ? [NSString stringWithFormat:@"%@", qIdObj] : nil;
    NSString *qTitle = [q[@"title"] isKindOfClass:[NSString class]] ? q[@"title"] : @"(Başlıksız)";
    NSArray *choices = [q[@"choices"] isKindOfClass:[NSArray class]] ? q[@"choices"] : nil;

    if (!qId || qId.length == 0 || !choices || choices.count == 0) {
        FEW1NLog([NSString stringWithFormat:@"⚠️ Soru %lu/%lu atlandı (id veya seçenek yok): %@",
                  (unsigned long)(idx + 1), (unsigned long)questions.count, qTitle]);
        SubmitQuestionAtIndex(questions, idx + 1);
        return;
    }

    id rawChoice = choices.firstObject;
    if (![rawChoice isKindOfClass:[NSDictionary class]]) {
        SubmitQuestionAtIndex(questions, idx + 1);
        return;
    }
    NSDictionary *firstChoice = (NSDictionary *)rawChoice;
    id cIdObj = firstChoice[@"id"];
    NSString *cId = (cIdObj && cIdObj != [NSNull null]) ? [NSString stringWithFormat:@"%@", cIdObj] : nil;
    NSString *cTitle = [firstChoice[@"title"] isKindOfClass:[NSString class]] ? firstChoice[@"title"] : @"";
    if (!cId || cId.length == 0) {
        FEW1NLog([NSString stringWithFormat:@"⚠️ Soru %lu/%lu seçenek id yok: %@",
                  (unsigned long)(idx + 1), (unsigned long)questions.count, qTitle]);
        SubmitQuestionAtIndex(questions, idx + 1);
        return;
    }

    NSString *encodedQId = [qId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] ?: qId;
    NSString *answerURL = [NSString stringWithFormat:@"https://api-app.basaksehir.bel.tr/api/v2/question/%@/answer", encodedQId];
    FEW1NLog([NSString stringWithFormat:@"📤 Cevap gönderiliyor (%lu/%lu): %@ -> %@ (choiceId=%@)",
              (unsigned long)(idx + 1), (unsigned long)questions.count, qTitle, cTitle, cId]);

    NSMutableURLRequest *req = BuildApiRequest(answerURL, @"POST", @{ @"choiceId": cId });
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            FEW1NLog([NSString stringWithFormat:@"❌ Cevap gönderme hatası (%@): %@", qId, error.localizedDescription]);
        } else {
            NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            NSString *body = data ? ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"") : @"";
            FEW1NLog([NSString stringWithFormat:@"✅ Cevap Yanıtı (%ld): %@", (long)code, body]);
        }
        SubmitQuestionAtIndex(questions, idx + 1);
    }];
    [task resume];
}

static void RunCevaplaKazanFlow(void) {
    NSDictionary *headersSnapshot = nil;
    @synchronized(HeadersLock()) {
        headersSnapshot = gLatestApiHeaders;
    }
    if (!headersSnapshot || headersSnapshot.count == 0) {
        FEW1NLog(@"⚠️ Henüz API header yakalanamadı (Authorization için istek bekleniyor). Yine de v2/question deneniyor...");
    } else {
        FEW1NLog(@"🔍 Cevapla Kazan soruları çekiliyor (GET /api/v2/question)...");
    }

    NSMutableURLRequest *req = BuildApiRequest(@"https://api-app.basaksehir.bel.tr/api/v2/question", @"GET", nil);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            FEW1NLog([NSString stringWithFormat:@"❌ v2/question hatası: %@", error.localizedDescription]);
            return;
        }
        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        NSString *bodyStr = data ? ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"") : @"";
        FEW1NLog([NSString stringWithFormat:@"📋 v2/question (%ld): %@", (long)code, bodyStr]);

        if (!data || data.length == 0) return;
        NSError *jsonErr = nil;
        id jsonObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || ![jsonObj isKindOfClass:[NSDictionary class]]) {
            FEW1NLog([NSString stringWithFormat:@"⚠️ JSON çözümlenemedi: %@", jsonErr.localizedDescription ?: @"NSDictionary değil"]);
            return;
        }

        NSArray *questions = [jsonObj[@"questions"] isKindOfClass:[NSArray class]] ? jsonObj[@"questions"] : nil;
        if (!questions || questions.count == 0) {
            FEW1NLog(@"ℹ️ Aktif Cevapla Kazan sorusu yok (questions boş).");
            RefreshUserPoints();
            return;
        }

        NSMutableArray *titles = [NSMutableArray array];
        for (id item in questions) {
            if ([item isKindOfClass:[NSDictionary class]] && [item[@"title"] isKindOfClass:[NSString class]]) {
                [titles addObject:item[@"title"]];
            }
        }
        FEW1NLog([NSString stringWithFormat:@"🎯 %lu soru bulundu: %@",
                  (unsigned long)questions.count, [titles componentsJoinedByString:@" | "]]);
        SubmitQuestionAtIndex(questions, 0);
    }];
    [task resume];
}

static void few1n_alamofire_didReceiveResponse(id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLResponse *response, void (^completionHandler)(NSURLSessionResponseDisposition));
static void few1n_alamofire_didReceiveData(id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data);
static void few1n_alamofire_didCompleteWithError(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task, NSError *error);

static void HookSessionDelegateClassIfNeeded(Class delCls) {
    if (!delCls) return;
    static NSMutableSet *hookedClasses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hookedClasses = [NSMutableSet set];
    });
    @synchronized(hookedClasses) {
        NSString *clsName = NSStringFromClass(delCls);
        if ([hookedClasses containsObject:clsName]) return;
        [hookedClasses addObject:clsName];

        SwizzleInstanceMethod(delCls,
                              NSSelectorFromString(@"URLSession:dataTask:didReceiveResponse:completionHandler:"),
                              NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveResponse:completionHandler:"),
                              (IMP)few1n_alamofire_didReceiveResponse,
                              "v@:@@@@");
        SwizzleInstanceMethod(delCls,
                              NSSelectorFromString(@"URLSession:dataTask:didReceiveData:"),
                              NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveData:"),
                              (IMP)few1n_alamofire_didReceiveData,
                              "v@:@@@");
        SwizzleInstanceMethod(delCls,
                              NSSelectorFromString(@"URLSession:task:didCompleteWithError:"),
                              NSSelectorFromString(@"few1n_orig_URLSession:task:didCompleteWithError:"),
                              (IMP)few1n_alamofire_didCompleteWithError,
                              "v@:@@@");
    }
}

static id few1n_dataTaskWithRequestOnly(id self, SEL _cmd, NSURLRequest *request) {
    NSURLSession *sess = [self isKindOfClass:[NSURLSession class]] ? (NSURLSession *)self : nil;
    if (sess && sess.delegate) {
        HookSessionDelegateClassIfNeeded([sess.delegate class]);
    }
    LogOutgoingRequest(sess, request);
    SEL newSel = NSSelectorFromString(@"few1n_orig_dataTaskWithRequestOnly:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        return ((id (*)(id, SEL, NSURLRequest *))method_getImplementation(m))(self, _cmd, request);
    }
    return nil;
}

static id few1n_dataTaskWithRequest(id self, SEL _cmd, NSURLRequest *request, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
    NSURLSession *sess = [self isKindOfClass:[NSURLSession class]] ? (NSURLSession *)self : nil;
    if (sess && sess.delegate) {
        HookSessionDelegateClassIfNeeded([sess.delegate class]);
    }
    LogOutgoingRequest(sess, request);
    NSString *url = request.URL.absoluteString;

    void (^customHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSData *finalData = data;
        NSURLResponse *finalResp = response;
        NSError *finalErr = error;

        NSInteger mockCode = 200;
        NSData *mockPayload = ApplyMockPatchForURL(url, data, &mockCode);
        if (mockPayload) {
            finalData = mockPayload;
            finalErr = nil;
            NSURL *targetURL = request.URL ?: (response.URL ?: [NSURL URLWithString:@"https://api-app.basaksehir.bel.tr"]);
            finalResp = [[NSHTTPURLResponse alloc] initWithURL:targetURL
                                                    statusCode:mockCode
                                                   HTTPVersion:@"HTTP/1.1"
                                                  headerFields:@{@"Content-Type": @"application/json; charset=utf-8"}];
            if ([url.lowercaseString containsString:@"/pay/newtransaction"]) {
                BOOL isControl = NO;
                if (request.HTTPBody) {
                    NSString *bStr = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
                    if (bStr && [bStr containsString:@"\"isControl\":true"]) isControl = YES;
                }
                if (isControl) {
                    FEW1NLog(@"📷 [newTransaction URLSession] QR kontrol isteği (isControl: true) simüle edildi.");
                } else {
                    FEW1NLog(@"💸 [newTransaction URLSession] Ödeme işlemi onaylandı (isControl: false)! Başarı animasyonu tetikleniyor...");
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        UIViewController *payVC = FindActivePayViewController(nil);
                        if (payVC) {
                            TriggerLocalPaymentSuccessUI(payVC);
                        }
                    });
                }
            } else {
                FEW1NLog([NSString stringWithFormat:@"🎭 [Mock URLSession] %@ -> 5000 BaşakPara işlendi.", url]);
            }
        }

        if (ShouldLogURL(url)) {
            NSString *respStr = @"";
            if (finalData && finalData.length > 0) {
                NSString *utf8 = [[NSString alloc] initWithData:finalData encoding:NSUTF8StringEncoding];
                respStr = utf8 ?: [NSString stringWithFormat:@"<binary %lu bytes>", (unsigned long)finalData.length];
            }
            NSInteger statusCode = [finalResp isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)finalResp).statusCode : 0;
            FEW1NLog([NSString stringWithFormat:@"⬅️ RESP (%ld): %@\nBody: %@", (long)statusCode, url, respStr]);
        }
        if (completionHandler) {
            completionHandler(finalData, finalResp, finalErr);
        }
    };

    SEL newSel = NSSelectorFromString(@"few1n_orig_dataTaskWithRequest:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        return ((id (*)(id, SEL, NSURLRequest *, id))method_getImplementation(m))(self, _cmd, request, customHandler);
    }
    return nil;
}

static NSURLResponse *few1n_task_response(NSURLSessionTask *self, SEL _cmd) {
    SEL newSel = NSSelectorFromString(@"few1n_orig_response");
    Method m = class_getInstanceMethod([self class], newSel);
    NSURLResponse *origResp = m ? ((NSURLResponse *(*)(id, SEL))method_getImplementation(m))(self, _cmd) : nil;

    if (!gEnableMockPay) return origResp;

    NSString *url = self.originalRequest.URL.absoluteString ?: self.currentRequest.URL.absoluteString;
    if (ShouldMockURL(url)) {
        NSURL *targetURL = origResp.URL ?: (self.currentRequest.URL ?: [NSURL URLWithString:@"https://api-app.basaksehir.bel.tr"]);
        return [[NSHTTPURLResponse alloc] initWithURL:targetURL
                                           statusCode:200
                                          HTTPVersion:@"HTTP/1.1"
                                         headerFields:@{@"Content-Type": @"application/json; charset=utf-8"}];
    }
    return origResp;
}

static void few1n_alamofire_didReceiveResponse(id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLResponse *response, void (^completionHandler)(NSURLSessionResponseDisposition)) {
    NSString *url = dataTask.originalRequest.URL.absoluteString ?: dataTask.currentRequest.URL.absoluteString;
    NSURLResponse *forwardResponse = response;

    if (ShouldMockURL(url)) {
        NSURL *targetURL = response.URL ?: (dataTask.currentRequest.URL ?: [NSURL URLWithString:@"https://api-app.basaksehir.bel.tr"]);
        forwardResponse = [[NSHTTPURLResponse alloc] initWithURL:targetURL
                                                      statusCode:200
                                                     HTTPVersion:@"HTTP/1.1"
                                                    headerFields:@{@"Content-Type": @"application/json; charset=utf-8"}];
    }

    SEL newSel = NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveResponse:completionHandler:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL, id, id, id, id))method_getImplementation(m))(self, _cmd, session, dataTask, forwardResponse, completionHandler);
    }
}

static void few1n_alamofire_didReceiveData(id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data) {
    NSString *url = dataTask.originalRequest.URL.absoluteString ?: dataTask.currentRequest.URL.absoluteString;
    NSData *forwardData = data;

    NSInteger mockCode = 200;
    NSData *mockPayload = ApplyMockPatchForURL(url, data, &mockCode);
    if (mockPayload) {
        forwardData = mockPayload;
        if ([url.lowercaseString containsString:@"/pay/newtransaction"]) {
            BOOL isControl = NO;
            if (dataTask.originalRequest.HTTPBody) {
                NSString *bStr = [[NSString alloc] initWithData:dataTask.originalRequest.HTTPBody encoding:NSUTF8StringEncoding];
                if (bStr && [bStr containsString:@"\"isControl\":true"]) isControl = YES;
            }
            if (isControl) {
                FEW1NLog(@"📷 [newTransaction AF] QR kontrol isteği (isControl: true) simüle edildi.");
            } else {
                FEW1NLog(@"💸 [newTransaction AF] Ödeme işlemi onaylandı (isControl: false)! Başarı animasyonu tetikleniyor...");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIViewController *payVC = FindActivePayViewController(nil);
                    if (payVC) {
                        TriggerLocalPaymentSuccessUI(payVC);
                    }
                });
            }
        } else {
            FEW1NLog([NSString stringWithFormat:@"🎭 [AF Mock] 5000 BaşakPara enjekte edildi: %@", url ?: @"?"]);
        }
    }

    if (ShouldLogURL(url)) {
        NSInteger statusCode = [dataTask.response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)dataTask.response).statusCode : 200;
        NSString *respStr = @"";
        if (forwardData && forwardData.length > 0) {
            NSString *utf8 = [[NSString alloc] initWithData:forwardData encoding:NSUTF8StringEncoding];
            respStr = utf8 ?: [NSString stringWithFormat:@"<binary %lu bytes>", (unsigned long)forwardData.length];
        }
        FEW1NLog([NSString stringWithFormat:@"⬅️ AF RESP (%ld): %@\nBody: %@", (long)statusCode, url ?: @"?", respStr]);
    }

    SEL newSel = NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveData:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL, id, id, id))method_getImplementation(m))(self, _cmd, session, dataTask, forwardData);
    }
}

static void few1n_alamofire_didCompleteWithError(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task, NSError *error) {
    NSString *url = task.originalRequest.URL.absoluteString ?: task.currentRequest.URL.absoluteString;
    NSError *forwardError = error;

    if (error && ShouldMockURL(url)) {
        FEW1NLog([NSString stringWithFormat:@"🎭 [AF Mock Clean] Ağ hatası bastırıldı: %@", url ?: @"?"]);
        forwardError = nil;
    }

    SEL newSel = NSSelectorFromString(@"few1n_orig_URLSession:task:didCompleteWithError:");
    Method m = class_getInstanceMethod([self class], newSel);
    if (m) {
        ((void (*)(id, SEL, id, id, id))method_getImplementation(m))(self, _cmd, session, task, forwardError);
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

static BOOL ViewContainsErrorText(UIView *view) {
    if (!view) return NO;
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *t = [(UILabel *)view text].lowercaseString;
        if ([t containsString:@"ücret bilgisi"] || [t containsString:@"ucret bilgisi"] ||
            [t containsString:@"alınamadı"] || [t containsString:@"alinamadi"] ||
            [t containsString:@"tekrar tarayın"] || [t containsString:@"tekrar tarayin"] ||
            [t containsString:@"geçersiz qr"] || [t containsString:@"gecersiz qr"]) {
            return YES;
        }
    }
    for (UIView *sub in view.subviews) {
        if (ViewContainsErrorText(sub)) return YES;
    }
    return NO;
}

static void few1n_presentViewController(UIViewController *self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if ([vcToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)vcToPresent;
        NSString *title = alert.title ?: @"";
        NSString *msg = alert.message ?: @"";
        NSString *combined = [NSString stringWithFormat:@"%@ %@", title, msg].lowercaseString;
        if ([combined containsString:@"beklenmedik bir hata"] ||
            [combined containsString:@"yetersiz bakiye"] ||
            [combined containsString:@"unauthorized"] ||
            [combined containsString:@"hata oluştu"] ||
            [combined containsString:@"ücret bilgisi"] ||
            [combined containsString:@"ucret bilgisi"] ||
            [combined containsString:@"alınamadı"] ||
            [combined containsString:@"alinamadi"] ||
            [combined containsString:@"tekrar tarayın"] ||
            [combined containsString:@"tekrar tarayin"] ||
            [combined containsString:@"bulunamadı"] ||
            [combined containsString:@"bulunamadi"] ||
            [combined containsString:@"geçersiz qr"] ||
            [combined containsString:@"gecersiz qr"]) {
            FEW1NLog([NSString stringWithFormat:@"🛑 [Alert Suppressor] Hata uyarısı bastırıldı: '%@'", title.length > 0 ? title : msg]);
            if (completion) completion();
            return;
        }
    } else if (vcToPresent) {
        if (([vcToPresent isViewLoaded] && ViewContainsErrorText(vcToPresent.view)) ||
            ViewContainsErrorText(vcToPresent.view)) {
            FEW1NLog(@"🛑 [Custom VC Suppressor] 'Ücret bilgisi alınamadı' modalı engellendi!");
            if (completion) completion();
            return;
        }
    }
    SEL newSel = NSSelectorFromString(@"few1n_orig_presentViewController:animated:completion:");
    Method m = class_getInstanceMethod([UIViewController class], newSel);
    if (m) {
        ((void (*)(id, SEL, id, BOOL, id))method_getImplementation(m))(self, _cmd, vcToPresent, animated, completion);
    }
}

static void few1n_view_didMoveToWindow(UIView *self, SEL _cmd) {
    SEL newSel = NSSelectorFromString(@"few1n_orig_viewDidMoveToWindow");
    Method m = class_getInstanceMethod([UIView class], newSel);
    if (m) {
        ((void (*)(id, SEL))method_getImplementation(m))(self, _cmd);
    }
    if (self.window != nil && ViewContainsErrorText(self)) {
        FEW1NLog(@"🛑 [View Trap] 'Ücret bilgisi alınamadı' popup kartı yakalandı ve gizlendi!");
        self.hidden = YES;
        [self removeFromSuperview];
    }
}

static void few1n_label_setText(UILabel *self, SEL _cmd, NSString *text) {
    if ([text isKindOfClass:[NSString class]]) {
        NSString *lower = [text lowercaseString];
        if ([lower containsString:@"alınamadı"] ||
            [lower containsString:@"alinamadi"] ||
            [lower containsString:@"ücret bilgisi"] ||
            [lower containsString:@"ucret bilgisi"] ||
            [lower containsString:@"tekrar tarayın"] ||
            [lower containsString:@"tekrar tarayin"] ||
            [lower containsString:@"bulunamadı"] ||
            [lower containsString:@"bulunamadi"] ||
            [lower containsString:@"geçersiz qr"] ||
            [lower containsString:@"gecersiz qr"]) {
            FEW1NLog([NSString stringWithFormat:@"🎯 [UILabel Yakalandı] '%@' -> 'Ödenecek Tutar: 50,00 ₺' yapıldı.", text]);
            text = @"Ödenecek Tutar: 50,00 ₺";
            dispatch_async(dispatch_get_main_queue(), ^{
                EnableAllButtonsRecursively(self.superview ?: self);
            });
        }
    }
    SEL newSel = NSSelectorFromString(@"few1n_orig_setText:");
    Method m = class_getInstanceMethod([UILabel class], newSel);
    if (m) {
        ((void (*)(id, SEL, id))method_getImplementation(m))(self, _cmd, text);
    }
}

static void few1n_label_setAttributedText(UILabel *self, SEL _cmd, NSAttributedString *attrText) {
    if (attrText && [attrText.string isKindOfClass:[NSString class]]) {
        NSString *lower = [attrText.string lowercaseString];
        if ([lower containsString:@"alınamadı"] ||
            [lower containsString:@"alinamadi"] ||
            [lower containsString:@"ücret bilgisi"] ||
            [lower containsString:@"ucret bilgisi"] ||
            [lower containsString:@"tekrar tarayın"] ||
            [lower containsString:@"tekrar tarayin"] ||
            [lower containsString:@"bulunamadı"] ||
            [lower containsString:@"bulunamadi"] ||
            [lower containsString:@"geçersiz qr"] ||
            [lower containsString:@"gecersiz qr"]) {
            FEW1NLog([NSString stringWithFormat:@"🎯 [UILabel Attributed Yakalandı] '%@' -> 'Ödenecek Tutar: 50,00 ₺' yapıldı.", attrText.string]);
            attrText = [[NSAttributedString alloc] initWithString:@"Ödenecek Tutar: 50,00 ₺"
                                                       attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0],
                                                                    NSFontAttributeName: [UIFont boldSystemFontOfSize:16]}];
            dispatch_async(dispatch_get_main_queue(), ^{
                EnableAllButtonsRecursively(self.superview ?: self);
            });
        }
    }
    SEL newSel = NSSelectorFromString(@"few1n_orig_setAttributedText:");
    Method m = class_getInstanceMethod([UILabel class], newSel);
    if (m) {
        ((void (*)(id, SEL, id))method_getImplementation(m))(self, _cmd, attrText);
    }
}

static void CreateFEW1NFloatingUI(void);

static void few1n_viewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    SEL newSel = NSSelectorFromString(@"few1n_orig_viewDidAppear:");
    Method m = class_getInstanceMethod([UIViewController class], newSel);
    if (m) {
        ((void (*)(id, SEL, BOOL))method_getImplementation(m))(self, _cmd, animated);
    }

    if ([self isViewLoaded] && ViewContainsErrorText(self.view)) {
        FEW1NLog(@"🛑 [VC Auto-Dismiss] 'Ücret bilgisi alınamadı' modal sayfası çalışma anında kapatıldı!");
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        EnsureOverlayWindow();
        if (gOverlayWindow) {
            gOverlayWindow.hidden = NO;
            if (floatingBtn && floatingBtn.superview) {
                [floatingBtn.superview bringSubviewToFront:floatingBtn];
            }
            if (menuView && menuView.superview && !menuView.hidden) {
                [menuView.superview bringSubviewToFront:menuView];
            }
        }
        CreateFEW1NFloatingUI();
    });
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
    EnsureOverlayWindow();
    [UIView animateWithDuration:0.25 animations:^{
        menuView.hidden = !menuView.hidden;
        if (!menuView.hidden && gOverlayWindow && gOverlayWindow.rootViewController) {
            [gOverlayWindow.rootViewController.view bringSubviewToFront:menuView];
            [gOverlayWindow.rootViewController.view bringSubviewToFront:floatingBtn];
        }
    }];
}

@interface UIButton (FEW1NActions)
- (void)toggleMenu;
- (void)handlePan:(UIPanGestureRecognizer *)p;
- (void)openWalletRoute;
- (void)openQRRoute;
- (void)testLocalSuccessUI;
- (void)clearLogs;
- (void)runCevaplaKazan;
- (void)copyLogs;
- (void)toggleMockPay;
- (void)testNewTransaction;
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
- (void)runCevaplaKazan {
    RunCevaplaKazanFlow();
}
- (void)copyLogs {
    NSString *allText = capturedLogs.count > 0
        ? [capturedLogs componentsJoinedByString:@"\n--------------------\n"]
        : (networkLogView.text ?: @"");
    [UIPasteboard generalPasteboard].string = allText;
    FEW1NLog(@"📋 Loglar panoya kopyalandı.");
}
- (void)toggleMockPay {
    gEnableMockPay = !gEnableMockPay;
    UIButton *btn = (UIButton *)[menuView viewWithTag:777];
    if ([btn isKindOfClass:[UIButton class]]) {
        if (gEnableMockPay) {
            [btn setTitle:@"🎭 Mock: AÇIK" forState:UIControlStateNormal];
            btn.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:0.35 alpha:0.9];
        } else {
            [btn setTitle:@"🎭 Mock: KAPALI" forState:UIControlStateNormal];
            btn.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.85];
        }
    }
    FEW1NLog([NSString stringWithFormat:@"🎭 BaşakPara & newTransaction Mock: %@", gEnableMockPay ? @"AÇIK" : @"KAPALI"]);
}
- (void)testNewTransaction {
    FEW1NLog(@"⚡ [Test] /Pay/newTransaction isteği gönderiliyor...");
    NSDictionary *body = @{
        @"qr": @"FEW1N-PAY-QR-1337",
        @"isControl": @NO
    };
    NSMutableURLRequest *req = BuildApiRequest(@"https://api-app.basaksehir.bel.tr/api/v2/Pay/newTransaction", @"POST", body);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        NSString *bodyStr = data ? ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"") : @"";
        FEW1NLog([NSString stringWithFormat:@"🎯 [newTransaction Test Sonucu] HTTP %ld:\n%@", (long)code, bodyStr]);
    }];
    [task resume];
}
@end

static void CreateFEW1NFloatingUI(void) {
    EnsureOverlayWindow();
    if (!gOverlayWindow || !gOverlayWindow.rootViewController) return;
    UIView *container = gOverlayWindow.rootViewController.view;
    if (!container) return;

    if (!floatingBtn) {
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
    }

    if (floatingBtn.superview != container) {
        [floatingBtn removeFromSuperview];
        [container addSubview:floatingBtn];
    }
    [container bringSubviewToFront:floatingBtn];

    if (!menuView) {
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
        CGFloat width = screenW > 100 ? (screenW - 40) : 335;
        CGFloat height = MIN(screenH > 200 ? screenH - 120 : 545, 545);
        menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 95, width, height)];
        menuView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95];
        menuView.layer.cornerRadius = 16;
        menuView.layer.borderWidth = 1.5;
        menuView.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.8].CGColor;
        menuView.clipsToBounds = YES;
        menuView.hidden = YES;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, width - 80, 24)];
        title.text = @"⚡ FEW1N MOD MENU v1.0.9";
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
    btnWallet.frame = CGRectMake(16, 45, halfW, 34);
    btnWallet.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:0.85];
    [btnWallet setTitle:@"💳 Cüzdan Aç" forState:UIControlStateNormal];
    [btnWallet setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnWallet.layer.cornerRadius = 8;
    [btnWallet addTarget:floatingBtn action:@selector(openWalletRoute) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnWallet];

    UIButton *btnQR = [UIButton buttonWithType:UIButtonTypeSystem];
    btnQR.frame = CGRectMake(24 + halfW, 45, halfW, 34);
    btnQR.backgroundColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.2 alpha:0.85];
    [btnQR setTitle:@"📷 QR Aç" forState:UIControlStateNormal];
    [btnQR setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnQR.layer.cornerRadius = 8;
    [btnQR addTarget:floatingBtn action:@selector(openQRRoute) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnQR];

    UIButton *btnTestSuccess = [UIButton buttonWithType:UIButtonTypeSystem];
    btnTestSuccess.frame = CGRectMake(16, 85, halfW, 32);
    btnTestSuccess.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:0.35 alpha:0.9];
    [btnTestSuccess setTitle:@"✅ UI Başarı Test" forState:UIControlStateNormal];
    [btnTestSuccess setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnTestSuccess.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btnTestSuccess.layer.cornerRadius = 6;
    [btnTestSuccess addTarget:floatingBtn action:@selector(testLocalSuccessUI) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnTestSuccess];

    UIButton *btnClear = [UIButton buttonWithType:UIButtonTypeSystem];
    btnClear.frame = CGRectMake(24 + halfW, 85, halfW, 32);
    btnClear.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.85];
    [btnClear setTitle:@"🗑️ Log Temizle" forState:UIControlStateNormal];
    [btnClear setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClear.titleLabel.font = [UIFont systemFontOfSize:12];
    btnClear.layer.cornerRadius = 6;
    [btnClear addTarget:floatingBtn action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnClear];

    UIButton *btnSurvey = [UIButton buttonWithType:UIButtonTypeSystem];
    btnSurvey.frame = CGRectMake(16, 123, halfW, 32);
    btnSurvey.backgroundColor = [UIColor colorWithRed:0.55 green:0.32 blue:0.85 alpha:0.9];
    [btnSurvey setTitle:@"❓ Cevapla Kazan" forState:UIControlStateNormal];
    [btnSurvey setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnSurvey.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btnSurvey.layer.cornerRadius = 6;
    [btnSurvey addTarget:floatingBtn action:@selector(runCevaplaKazan) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnSurvey];

    UIButton *btnCopy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnCopy.frame = CGRectMake(24 + halfW, 123, halfW, 32);
    btnCopy.backgroundColor = [UIColor colorWithRed:0.18 green:0.45 blue:0.65 alpha:0.9];
    [btnCopy setTitle:@"📋 Kopyala" forState:UIControlStateNormal];
    [btnCopy setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnCopy.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btnCopy.layer.cornerRadius = 6;
    [btnCopy addTarget:floatingBtn action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnCopy];

    UIButton *btnMockPay = [UIButton buttonWithType:UIButtonTypeSystem];
    btnMockPay.frame = CGRectMake(16, 161, halfW, 32);
    btnMockPay.tag = 777;
    btnMockPay.backgroundColor = gEnableMockPay ? [UIColor colorWithRed:0.15 green:0.65 blue:0.35 alpha:0.9] : [UIColor colorWithWhite:0.25 alpha:0.85];
    [btnMockPay setTitle:gEnableMockPay ? @"🎭 Mock: AÇIK" : @"🎭 Mock: KAPALI" forState:UIControlStateNormal];
    [btnMockPay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnMockPay.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btnMockPay.layer.cornerRadius = 6;
    [btnMockPay addTarget:floatingBtn action:@selector(toggleMockPay) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnMockPay];

    UIButton *btnTestTx = [UIButton buttonWithType:UIButtonTypeSystem];
    btnTestTx.frame = CGRectMake(24 + halfW, 161, halfW, 32);
    btnTestTx.backgroundColor = [UIColor colorWithRed:0.85 green:0.45 blue:0.1 alpha:0.9];
    [btnTestTx setTitle:@"⚡ newTransaction" forState:UIControlStateNormal];
    [btnTestTx setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnTestTx.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btnTestTx.layer.cornerRadius = 6;
    [btnTestTx addTarget:floatingBtn action:@selector(testNewTransaction) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnTestTx];

    UILabel *logLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 199, width - 32, 18)];
    logLabel.text = @"📡 CANLI JSON AĞ TRAFİĞİ (Alamofire / v2/Pay / Question):";
    logLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:1.0 alpha:1.0];
    logLabel.font = [UIFont boldSystemFontOfSize:11];
    [menuView addSubview:logLabel];

    networkLogView = [[UITextView alloc] initWithFrame:CGRectMake(16, 221, width - 32, height - 233)];
    networkLogView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];
    networkLogView.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0];
    networkLogView.font = [UIFont fontWithName:@"Courier" size:11];
    networkLogView.editable = NO;
    networkLogView.layer.cornerRadius = 8;
    if (capturedLogs.count > 0) {
        networkLogView.text = [capturedLogs componentsJoinedByString:@"\n--------------------\n"];
    } else {
        networkLogView.text = @"[+] FEW1N Network Inspector v1.0.8 devrede...\n[+] BaşakPara & newTransaction Mock: AÇIK\n[+] JSON istekleri bekleniyor...";
    }
    [menuView addSubview:networkLogView];
    }

    if (menuView.superview != container) {
        [menuView removeFromSuperview];
        [container addSubview:menuView];
    }
    [container bringSubviewToFront:menuView];
    [container bringSubviewToFront:floatingBtn];
    gOverlayWindow.hidden = NO;
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

    // 1d. Swizzle NSURLSessionTask.response so Alamofire reads mocked 200 OK status
    Class taskCls = [NSURLSessionTask class];
    SwizzleInstanceMethod(taskCls,
                          @selector(response),
                          NSSelectorFromString(@"few1n_orig_response"),
                          (IMP)few1n_task_response,
                          "@@:");
    Class localTaskCls = NSClassFromString(@"__NSCFLocalDataTask");
    if (localTaskCls) {
        SwizzleInstanceMethod(localTaskCls,
                              @selector(response),
                              NSSelectorFromString(@"few1n_orig_response"),
                              (IMP)few1n_task_response,
                              "@@:");
    }

    // 1e. Swizzle Alamofire SessionDelegate delegate methods
    Class afDelegateCls = NSClassFromString(@"_TtC9Alamofire15SessionDelegate");
    if (afDelegateCls) {
        SwizzleInstanceMethod(afDelegateCls,
                              NSSelectorFromString(@"URLSession:dataTask:didReceiveResponse:completionHandler:"),
                              NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveResponse:completionHandler:"),
                              (IMP)few1n_alamofire_didReceiveResponse,
                              "v@:@@@@");
        SwizzleInstanceMethod(afDelegateCls,
                              NSSelectorFromString(@"URLSession:dataTask:didReceiveData:"),
                              NSSelectorFromString(@"few1n_orig_URLSession:dataTask:didReceiveData:"),
                              (IMP)few1n_alamofire_didReceiveData,
                              "v@:@@@");
        SwizzleInstanceMethod(afDelegateCls,
                              NSSelectorFromString(@"URLSession:task:didCompleteWithError:"),
                              NSSelectorFromString(@"few1n_orig_URLSession:task:didCompleteWithError:"),
                              (IMP)few1n_alamofire_didCompleteWithError,
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

    // 4. Swizzle PayAlertManager & Error Alert Suppressors
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

        // Dynamically find and suppress any additional error/alert class methods
        Class metaCls = object_getClass((id)alertCls);
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(metaCls, &methodCount);
        if (methods) {
            for (unsigned int i = 0; i < methodCount; i++) {
                SEL sel = method_getName(methods[i]);
                NSString *selName = NSStringFromSelector(sel);
                if ([selName containsString:@"Error"] || [selName containsString:@"Insufficient"] || [selName containsString:@"Fail"]) {
                    class_replaceMethod(metaCls, sel, (IMP)few1n_showGeneralErrorAlert, "v@:@");
                }
            }
            free(methods);
        }
    }

    // 4b. Global UIAlertController error suppressor
    SwizzleInstanceMethod([UIViewController class],
                          @selector(presentViewController:animated:completion:),
                          NSSelectorFromString(@"few1n_orig_presentViewController:animated:completion:"),
                          (IMP)few1n_presentViewController,
                          "v@:@B@");

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

    // 7. Swizzle UIViewController viewDidAppear: (keeps overlay window on top of camera/modals)
    SwizzleInstanceMethod([UIViewController class],
                          @selector(viewDidAppear:),
                          NSSelectorFromString(@"few1n_orig_viewDidAppear:"),
                          (IMP)few1n_viewDidAppear,
                          "v@:B");

    // 8. Swizzle UILabel setText: & setAttributedText: (intercepts 'Ücret bilgisi alınamadı')
    SwizzleInstanceMethod([UILabel class],
                          @selector(setText:),
                          NSSelectorFromString(@"few1n_orig_setText:"),
                          (IMP)few1n_label_setText,
                          "v@:@");

    SwizzleInstanceMethod([UILabel class],
                          @selector(setAttributedText:),
                          NSSelectorFromString(@"few1n_orig_setAttributedText:"),
                          (IMP)few1n_label_setAttributedText,
                          "v@:@");

    // 9. Swizzle UIView didMoveToWindow (traps and removes any error popup card)
    SwizzleInstanceMethod([UIView class],
                          @selector(didMoveToWindow),
                          NSSelectorFromString(@"few1n_orig_viewDidMoveToWindow"),
                          (IMP)few1n_view_didMoveToWindow,
                          "v@:");
}

// ----------------------------------------------------------------------------
// Constructor
// ----------------------------------------------------------------------------
__attribute__((constructor))
static void FEW1NInit(void) {
    FEW1NLog(@"⚡ FEW1N Basaksehirli Native Mod v1.0.9 yüklendi.");
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
