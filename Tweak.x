#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============================================================================
// FEW1N Başakşehirli Mod - Floating UI & In-App Network Inspector
// ============================================================================

static UIButton *floatingBtn = nil;
static UIView *menuView = nil;
static UITextView *networkLogView = nil;
static NSMutableArray *capturedLogs = nil;

// ----------------------------------------------------------------------------
// Log Helper
// ----------------------------------------------------------------------------
static void FEW1NLog(NSString *text) {
    if (!capturedLogs) {
        capturedLogs = [NSMutableArray new];
    }
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterNoStyle
                                                         timeStyle:NSDateFormatterMediumStyle];
    NSString *entry = [NSString stringWithFormat:@"[%@] %@", timestamp, text];
    [capturedLogs insertObject:entry atIndex:0];
    if (capturedLogs.count > 100) {
        [capturedLogs removeLastObject];
    }
    if (networkLogView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            networkLogView.text = [capturedLogs componentsJoinedByString:@"\n--------------------\n"];
        });
    }
}

// ----------------------------------------------------------------------------
// Network Interceptor: Hook NSURLSession dataTaskWithRequest:
// ----------------------------------------------------------------------------
%hook NSURLSession

- (id)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *url = request.URL.absoluteString;
    NSString *method = request.HTTPMethod;

    if ([url containsString:@"Pay"] || [url containsString:@"Duty"] || [url containsString:@"basaksehir"]) {
        NSString *bodyStr = @"";
        if (request.HTTPBody) {
            bodyStr = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        }
        FEW1NLog([NSString stringWithFormat:@"➡️ REQ: %@ %@\nBody: %@", method, url, bodyStr]);
    }

    void (^customHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([url containsString:@"Pay"] || [url containsString:@"Duty"] || [url containsString:@"basaksehir"]) {
            NSString *respStr = @"";
            if (data) {
                respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            FEW1NLog([NSString stringWithFormat:@"⬅️ RESP (%ld): %@\nBody: %@", (long)statusCode, url, respStr]);
        }
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };

    return %orig(request, customHandler);
}

%end

// ----------------------------------------------------------------------------
// Hook: SideMenuViewModel - Menüde BaşakPara'yı her zaman görünür kıl
// ----------------------------------------------------------------------------
%hook _TtC12basaksehirli17SideMenuViewModel

- (BOOL)isBasakParaVisible {
    return YES;
}

- (BOOL)isBasakPayVisible {
    return YES;
}

%end

// ----------------------------------------------------------------------------
// Hook: PayBalanceView - Arayüz Bakiye Metnini Sabitleme
// ----------------------------------------------------------------------------
%hook _TtC12basaksehirli14PayBalanceView

- (void)layoutSubviews {
    %orig;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)sub;
            if ([lbl.text containsString:@"₺"] || [lbl.text containsString:@"0,00"]) {
                lbl.text = @"500,00 ₺";
            }
        }
    }
}

%end

// ----------------------------------------------------------------------------
// Hook: PayAlertManager - "Yetersiz Bakiye" Uyarısını Susturma
// ----------------------------------------------------------------------------
%hook _TtC12basaksehirli15PayAlertManager

+ (void)showInsufficientBalance:(id)arg1 {
    FEW1NLog(@"[Hook] Insufficient Balance alert engellendi.");
    return;
}

+ (void)showGeneralErrorAlert:(id)arg1 {
    FEW1NLog(@"[Hook] General Error alert engellendi.");
    return;
}

%end

// ----------------------------------------------------------------------------
// Hook: PayViewController - Ödeme Butonuna Basıldığında Başarılı Saydırma
// ----------------------------------------------------------------------------
%hook _TtC12basaksehirli17PayViewController

- (void)paymentModalPaymentButtonTapped {
    FEW1NLog(@"🎯 paymentModalPaymentButtonTapped tetiklendi! Doğrudan Payment Successful akışına yönlendiriliyor.");
    
    // Doğrudan uygulamanın kendi Payment Successful fonksiyonu tetiklenir
    if ([self respondsToSelector:@selector(paymentSuccessful)]) {
        [self performSelector:@selector(paymentSuccessful)];
    } else {
        // Alternatif selector denemeleri
        SEL sel = NSSelectorFromString(@"paymentSuccessful");
        if ([self respondsToSelector:sel]) {
            [self performSelector:sel];
        } else {
            %orig;
        }
    }
}

%end

// ----------------------------------------------------------------------------
// Hook: VideoDutyViewController - Video Görevlerini Anında Tamamlama
// ----------------------------------------------------------------------------
%hook _TtC12basaksehirli23VideoDutyViewController

- (void)playerView:(id)player didChangeToState:(NSInteger)state {
    // YouTube state: 1 (Playing), 3 (Buffering) -> 0 (Ended)
    if (state == 1 || state == 3) {
        FEW1NLog(@"[VideoDuty] Oynatma başladı, anında state: 0 (bitti) gönderiliyor.");
        %orig(player, 0);
        return;
    }
    %orig(player, state);
}

%end

// ----------------------------------------------------------------------------
// UI: Floating FEW1N Menu
// ----------------------------------------------------------------------------
static void ToggleMenu() {
    if (!menuView) return;
    [UIView animateWithDuration:0.25 animations:^{
        menuView.hidden = !menuView.hidden;
    }];
}

static void CreateFEW1NFloatingUI() {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { keyWindow = w; break; }
    }
    if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    if (!keyWindow || floatingBtn) return;

    // 1. Floating Action Button
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

    // Drag gesture
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:floatingBtn action:@selector(handlePan:)];
    [floatingBtn addGestureRecognizer:pan];

    // 2. Menu Window View
    CGFloat width = keyWindow.bounds.size.width - 40;
    CGFloat height = 480;
    menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, width, height)];
    menuView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95];
    menuView.layer.cornerRadius = 16;
    menuView.layer.borderWidth = 1.5;
    menuView.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.8].CGColor;
    menuView.clipsToBounds = YES;
    menuView.hidden = YES;

    // Title Bar
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, width - 80, 24)];
    title.text = @"⚡ FEW1N MOD MENU - BAŞAKŞEHİRLİ";
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

    // Action Buttons
    UIButton *btnWallet = [UIButton buttonWithType:UIButtonTypeSystem];
    btnWallet.frame = CGRectMake(16, 45, (width - 40)/2, 36);
    btnWallet.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:0.8];
    [btnWallet setTitle:@"💳 Cüzdan Aç" forState:UIControlStateNormal];
    [btnWallet setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnWallet.layer.cornerRadius = 8;
    [btnWallet addTarget:floatingBtn action:@selector(openWalletRoute) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnWallet];

    UIButton *btnQR = [UIButton buttonWithType:UIButtonTypeSystem];
    btnQR.frame = CGRectMake(24 + (width - 40)/2, 45, (width - 40)/2, 36);
    btnQR.backgroundColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.2 alpha:0.8];
    [btnQR setTitle:@"📷 QR Aç" forState:UIControlStateNormal];
    [btnQR setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnQR.layer.cornerRadius = 8;
    [btnQR addTarget:floatingBtn action:@selector(openQRRoute) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnQR];

    // Clear Log Button
    UIButton *btnClear = [UIButton buttonWithType:UIButtonTypeSystem];
    btnClear.frame = CGRectMake(16, 90, width - 32, 28);
    btnClear.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.8];
    [btnClear setTitle:@"🗑️ Ağ Loglarını Temizle" forState:UIControlStateNormal];
    [btnClear setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClear.titleLabel.font = [UIFont systemFontOfSize:12];
    btnClear.layer.cornerRadius = 6;
    [btnClear addTarget:floatingBtn action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:btnClear];

    // Network Log Area
    UILabel *logLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 125, width - 32, 20)];
    logLabel.text = @"📡 CANLI AĞ TRAFİĞİ (REST / v2/Pay):";
    logLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:1.0 alpha:1.0];
    logLabel.font = [UIFont boldSystemFontOfSize:12];
    [menuView addSubview:logLabel];

    networkLogView = [[UITextView alloc] initWithFrame:CGRectMake(16, 150, width - 32, height - 165)];
    networkLogView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];
    networkLogView.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0];
    networkLogView.font = [UIFont fontWithName:@"Courier" size:11];
    networkLogView.editable = NO;
    networkLogView.layer.cornerRadius = 8;
    networkLogView.text = @"[+] FEW1N Network Inspector devrede...\n[+] İstekler bekleniyor...";
    [menuView addSubview:networkLogView];

    [keyWindow addSubview:menuView];
    [keyWindow addSubview:floatingBtn];
}

// Category for floating button actions
@interface UIButton (FEW1NActions)
- (void)toggleMenu;
- (void)handlePan:(UIPanGestureRecognizer *)p;
- (void)openWalletRoute;
- (void)openQRRoute;
- (void)clearLogs;
@end

@implementation UIButton (FEW1NActions)

- (void)toggleMenu {
    ToggleMenu();
}

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

- (void)clearLogs {
    [capturedLogs removeAllObjects];
    networkLogView.text = @"[+] Loglar temizlendi.";
}

@end

// ----------------------------------------------------------------------------
// Entrypoint Constructor
// ----------------------------------------------------------------------------
%ctor {
    FEW1NLog(@"⚡ FEW1N Basaksehirli Tweak yüklendi.");
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CreateFEW1NFloatingUI();
        });
    }];
}
