//
//  KJRouterHandler.m
//  KJBaseHandler
//
//  Created by 杨科军 on 2020/10/20.
//  https://github.com/yangKJ/KJBaseHandler

#import "KJRouterHandler.h"
@implementation NSURL (KJRouter)
/// 解析获取参数
- (NSDictionary*)kj_analysisParameterGetQuery{
    NSMutableDictionary *parm = [NSMutableDictionary dictionary];
    NSURLComponents *URLComponents = [[NSURLComponents alloc] initWithString:self.absoluteString];
    [URLComponents.queryItems enumerateObjectsUsingBlock:^(NSURLQueryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [parm setObject:obj.value forKey:obj.name];
    }];
    return parm;
}
@end
@interface KJRouterHandler ()
@property(nonatomic,strong)NSMutableDictionary<NSString *,NSMutableArray *>*routerDict;
@end
@implementation KJRouterHandler
static KJRouterHandler *router = nil;
NS_INLINE NSString *keyFromURL(NSURL *URL){
    return URL ? [NSString stringWithFormat:@"%@://%@%@",URL.scheme,URL.host,URL.path] : nil;
}
/// 注册路由URL
+ (void)kj_routerRegisterWithURL:(NSURL*)URL Block:(kRouterBlock)block{
    if (![self kj_reasonableURL:URL]) return;
    NSString *key = keyFromURL(URL) ?: @"kDefaultRouterKey";
    @synchronized (self) {
        router = [[self alloc]init];
        router.routerDict = [NSMutableDictionary dictionary];
    }
    if (router.routerDict[key]) {
        [router.routerDict[key] addObject:block];
    }else{
        router.routerDict[key] = [NSMutableArray arrayWithObject:block];
    }
}
/// 移除路由URL
+ (void)kj_routerRemoveWithURL:(NSURL*)URL{
    if (![self kj_reasonableURL:URL]) return;
    NSString *key = keyFromURL(URL) ?: @"kDefaultRouterKey";
    if (router.routerDict[key]) [router.routerDict removeObjectForKey:key];
    router.routerDict = nil;
    router = nil;
}
/// 执行跳转处理
+ (void)kj_routerTransferWithURL:(NSURL*)URL source:(UIViewController*)vc{
    [self kj_routerTransferWithURL:URL source:vc completion:nil];
}
+ (void)kj_routerTransferWithURL:(NSURL*)URL source:(UIViewController*)vc completion:(void(^)(UIViewController*))completion{
    if (![self kj_reasonableURL:URL] || ![NSThread isMainThread]) return;
    NSMutableArray<NSArray*>* keys = [NSMutableArray array];
    NSString *currentKey = keyFromURL(URL);
    if (currentKey) [keys addObject:@[currentKey]];
    __block UIViewController *__vc = nil;
    __weak __typeof(&*self) weakself = self;
    [keys enumerateObjectsUsingBlock:^(NSArray * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray *temps = [weakself kj_effectiveWithKeys:obj];
        __vc = [weakself kj_getTargetViewControllerWith:temps URL:URL source:vc?:weakself.topViewController];
        *stop = !!__vc;
    }];
    if (__vc == nil) return;
    if (completion) completion(__vc);
}

+ (BOOL)kj_reasonableURL:(NSURL*)URL{
    if (!URL) {
        NSAssert(URL, @"URL can not be nil");
        return NO;
    }
    if ([URL.scheme length] <= 0) {
        NSAssert([URL.scheme length] > 0, @"URL.scheme can not be nil");
        return NO;
    }
    if ([URL.host length] <= 0) {
        NSAssert([URL.host length] > 0, @"URL.host can not be nil");
        return NO;
    }
    if ([URL.absoluteString isEqualToString:@""]) {
        NSAssert(![URL.absoluteString isEqualToString:@""], @"URL.absoluteString can not be nil");
        return NO;
    }
    return YES;
}
+ (NSArray*)kj_effectiveWithKeys:(NSArray*)keys{
    if (!keys || ![keys count]) return nil;
    NSMutableArray *temps = [NSMutableArray array];
    for (NSString *key in keys) {
        if(router.routerDict[key] && [router.routerDict[key] count] > 0) {
            [temps addObjectsFromArray:router.routerDict[key]];
        }
    }
    return temps.mutableCopy;
}
+ (UIViewController*)kj_getTargetViewControllerWith:(NSArray*)blocks URL:(NSURL*)URL source:(UIViewController*)vc{
    if (!blocks || ![blocks count]) return nil;
    __block UIViewController *__vc = nil;
    [blocks enumerateObjectsUsingBlock:^(kRouterBlock _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj) {
            __vc = obj(URL,vc);
            if (__vc == nil) *stop = YES;
        }
    }];
    return __vc;
}
+ (UIViewController*)topViewController{
    UIWindow *window = ({
        UIWindow *window;
        if (@available(iOS 13.0, *)) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }else{
            window = [UIApplication sharedApplication].keyWindow;
        }
        window;
    });
    return [self topViewControllerForRootViewController:window.rootViewController];
}
+ (UIViewController*)topViewControllerForRootViewController:(UIViewController*)rootViewController{
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController*)rootViewController;
        return [self topViewControllerForRootViewController:navigationController.viewControllers.lastObject];
    }
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController*)rootViewController;
        return [self topViewControllerForRootViewController:tabBarController.selectedViewController];
    }
    if (rootViewController.presentedViewController) {
        return [self topViewControllerForRootViewController:rootViewController.presentedViewController];
    }
    if ([rootViewController isViewLoaded] && rootViewController.view.window) {
        return rootViewController;
    }
    return nil;
}

@end
