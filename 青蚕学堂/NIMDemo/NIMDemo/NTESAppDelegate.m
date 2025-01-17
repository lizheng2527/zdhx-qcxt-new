 //
//  AppDelegate.m
//  NIMDemo
//
//  Created by ght on 15-1-21.
//  Copyright (c) 2015年 Netease. All rights reserved.
//

#import "NTESAppDelegate.h"
#import "NTESLoginViewController.h"
#import "UIView+Toast.h"

#import "NTESMainTabController.h"

#import "NIMKit.h"
#import "NTESSDKConfigDelegate.h"

#import "NTESBundleSetting.h"
#import <UserNotifications/UserNotifications.h>


#import "NSString+NTES.h"
#import <UIView+Toast.h>
#import <SDWebImageManager.h>
#import <BaiduMapAPI_Base/BMKMapManager.h>
#import "WXApi.h"
#import <ShareSDK/ShareSDK.h>
#import <ShareSDKUI/ShareSDK+SSUI.h>
#import <ShareSDKConnector/ShareSDKConnector.h>
//集成蒲公英
#import <PgySDK/PgyManager.h>
#import <PgyUpdate/PgyUpdateManager.h>
#import "JPUSHService.h"
//导入JSpatch
#import <JSPatchPlatform/JSPatch.h>

// iOS10注册APNs所需头 件
#import <UserNotifications/UserNotifications.h>
#import "TYHLoginAjaxHandler.h"
#import "TYHLoginInfoModel.h"

@import PushKit;

NSString *NTESNotificationLogout = @"NTESNotificationLogout";
@interface NTESAppDelegate ()<NIMLoginManagerDelegate,PKPushRegistryDelegate,BMKGeneralDelegate>

@property (nonatomic,strong) NTESSDKConfigDelegate *sdkConfigDelegate;

@end

@implementation NTESAppDelegate
{
    BMKMapManager* _mapManager;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self languageSetting];
    // 获取BaseURL
    [self initData];
    
    [self setupNIMSDK];
    [self setupServices];
    [self registerPushService];
    [self commonInitListenEvents];
    
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window makeKeyAndVisible];
    [application setStatusBarStyle:UIStatusBarStyleLightContent];

    [self setupMainViewController];
    [self setNav];
        
    [self initBaiduMap];
    [self setupServices];
    [self initPGYUpdate];
    
    
    //     [JSPatch testScriptInBundle]; //本地测试
    
    //    [JSPatch startWithAppKey:@"d4230c8c18ddd9db"];
    //    [JSPatch setupRSAPublicKey:@"-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDbjxT8ybTJCylCgCNVPAgofIuA\nNR9TqDjBrleJpJj3d7p6Vnr+83PmLCdr7n26W+kwF75eZERb64k69CfTFBNz+zWj\nDQLGfHTaToYAy8FmHl9sjLP0r35+Ybcn6opR2o71tdsaWrL3wMVFUKCb03SKLEnK\n5DRYJ6fT83RZ8qogSwIDAQAB\n-----END PUBLIC KEY-----"];
    //        [JSPatch sync]; //放在applicationDidBecomeActive里 .
    
    

    DDLogInfo(@"launch with options %@",launchOptions);
    return YES;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[NIMSDK sharedSDK] loginManager] removeDelegate:self];
}


#pragma mark - ApplicationDelegate
- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSInteger count = [[[NIMSDK sharedSDK] conversationManager] allUnreadCount];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:count];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[NIMSDK sharedSDK] updateApnsToken:deviceToken];
    DDLogInfo(@"didRegisterForRemoteNotificationsWithDeviceToken:  %@", deviceToken);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo{
    DDLogInfo(@"receive remote notification:  %@", userInfo);
}



- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    DDLogError(@"fail to get apns token :%@",error);
}

#pragma mark PKPushRegistryDelegate
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type
{
    if ([type isEqualToString:PKPushTypeVoIP])
    {
        [[NIMSDK sharedSDK] updatePushKitToken:credentials.token];
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    DDLogInfo(@"receive payload %@ type %@",payload.dictionaryPayload,type);
    NSNumber *badge = payload.dictionaryPayload[@"aps"][@"badge"];
    if ([badge isKindOfClass:[NSNumber class]])
    {
        [UIApplication sharedApplication].applicationIconBadgeNumber = [badge integerValue];
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type
{
    DDLogInfo(@"registry %@ invalidate %@",registry,type);
}


#pragma mark - openURL

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {

    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString*, id> *)options
{

    return YES;
}



#pragma mark - misc
- (void)registerPushService
{
    if (@available(iOS 11.0, *))
    {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (!granted)
            {
                [[UIApplication sharedApplication].keyWindow makeToast:@"请开启推送功能否则无法收到推送通知" duration:2.0 position:CSToastPositionCenter];
            }
        }];
    }
    else
    {
        UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types
                                                                                 categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    
    //pushkit
    PKPushRegistry *pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    pushRegistry.delegate = self;
    pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];

}


- (void)setupMainViewController
{
     [self setupLoginViewController];
    
//
//        NTESMainTabController *mainTab = [[NTESMainTabController alloc] initWithNibName:nil bundle:nil];
//        self.window.rootViewController = mainTab;
//
//        NSString  *userName = [[NSUserDefaults standardUserDefaults]valueForKey:USER_DEFAULT_LOGINNAME];
//        NSString  *password = [[NSUserDefaults standardUserDefaults]valueForKey:USER_DEFAULT_PASSWORD];
//        NSString  *userID = [[NSUserDefaults standardUserDefaults]valueForKey:USER_DEFAULT_USERID];
//        NSString *organizationID = [[NSUserDefaults standardUserDefaults]valueForKey:USER_DEFAULT_ORIGANIZATION_ID];
//
//        dispatch_async(dispatch_queue_create("test.queue", DISPATCH_QUEUE_CONCURRENT), ^{
//            TYHLoginAjaxHandler *handler = [TYHLoginAjaxHandler new];
//            [handler submitLoginStatusWithLoginName:userName PassWord:password UserID:userID terminalStatus:@"1"];
//            [handler LoginWithUserName:userName.length?userName:@"" Password:password.length?password:@"" OrganizationID:organizationID.length?organizationID:@"" andStatus:^(BOOL successful, TYHLoginInfoModel *userInfo) {
//                [[NSUserDefaults standardUserDefaults]setValue:userInfo.token forKey:USER_DEFAULT_TOKEN];
//                [[NSUserDefaults standardUserDefaults]setValue:userInfo.appCenterUrl forKey:USER_DEFAULT_appCenterUrl];
//                [[NSUserDefaults standardUserDefaults]synchronize];
//            } failure:^(NSError *error) {
//
//            }];
//        });
}

- (void)commonInitListenEvents
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(logout:)
                                                 name:NTESNotificationLogout
                                               object:nil];
    
    [[[NIMSDK sharedSDK] loginManager] addDelegate:self];
}

- (void)setupLoginViewController
{
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
    NTESLoginViewController *loginController = [[NTESLoginViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:loginController];
    self.window.rootViewController = nav;
}


#pragma mark - logic impl
- (void)setupServices
{

}

- (void)setupNIMSDK
{
    
}




#pragma mark - MyAdd
-(void)initBaiduMap
{
    _mapManager = [[BMKMapManager alloc]init];
    BOOL ret = [_mapManager start:@"0D67ZwQE78ogWS5sgEH4N7MzjmZgRoWa" generalDelegate:self];
    if (!ret) {
        NSLog(@"manager start failed!");
    }
    //微信登陆的时候需要初始化
    [ShareSDK registerApp:@"1751edfc17c20"
     
          activePlatforms:@[
                            @(SSDKPlatformTypeWechat)
                            ]
                 onImport:^(SSDKPlatformType platformType)
     {
         switch (platformType)
         {
             case SSDKPlatformTypeWechat:
                 [ShareSDKConnector connectWeChat:[WXApi class]];
                 break;
             default:
                 break;
         }
     }
          onConfiguration:^(SSDKPlatformType platformType, NSMutableDictionary *appInfo)
     {
         switch (platformType)
         {
             case SSDKPlatformTypeWechat:
                 [appInfo SSDKSetupWeChatByAppId:@"wx126f677630d917ce"
                                       appSecret:@"30e2548186f407a05894708cffd9a836"];
                 break;
             default:
                 break;
         }
     }];
}

-(void)initPGYUpdate
{
    [[PgyManager sharedPgyManager] startManagerWithAppId:@"4c4fea2b3a584b01bfde13507a436ac0"];
    //启动更新检查SDK
    [[PgyUpdateManager sharedPgyManager] startManagerWithAppId:@"4c4fea2b3a584b01bfde13507a436ac0"];
    [NSThread sleepForTimeInterval:1.0];
    [[PgyUpdateManager sharedPgyManager] checkUpdate];
    [[PgyManager sharedPgyManager] setEnableFeedback:NO];
}

- (void)registerAPNs
{
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    //    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationType types = UIUserNotificationTypeNone;
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types
                                                                             categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    
    
}

#pragma mark - 内存警告处理
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    // 1.取消正在下载的操作
    [manager cancelAll];
    // 2.清除内存缓存
    [manager.imageCache clearMemory];
}


-(void)languageSetting
{
    NSArray *languages = [NSLocale preferredLanguages];
    NSString *language = [languages objectAtIndex:0];
    if ([language hasPrefix:@"zh"]) {//检测开头匹配，是否为中文
        [[NSUserDefaults standardUserDefaults] setObject:@"zh-Hans" forKey:@"appLanguage"];//App语言设置为中文
    }else{//其他语言
        [[NSUserDefaults standardUserDefaults] setObject:@"en" forKey:@"appLanguage"];//App语言设置为英文
    }
}

-(void)initData
{
    
//    http://114.115.146.60/center
    
    if (![[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULT_BASEURL]) {
        [[NSUserDefaults standardUserDefaults]setValue:@"http://114.115.146.60/center/" forKey:USER_DEFAULT_BASEURL];
        
        [[NSUserDefaults standardUserDefaults]setBool:NO forKey:USER_DEFAULT_FIRST_LOGIN];
        [[NSUserDefaults standardUserDefaults]synchronize];
    }
}

-(void)v3MessageAction:(NSNotification *)notification{
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"NewV3PushMessage" object:nil];
    
}

- (void)setNav
{
    UINavigationBar *bar = [UINavigationBar appearance];
    //设置字体颜色
    
    bar.barTintColor = [UIColor TabBarColorGreen];
    
    bar.tintColor = [UIColor whiteColor];
    
    [bar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
}


@end
