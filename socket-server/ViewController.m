//
//  ViewController.m
//  socket-server
//
//  Created by hzzhangshuangli on 2017/9/25.
//  Copyright © 2017年 hzzhangshuangli. All rights reserved.
//

#import "ViewController.h"
#import "Masonry.h"
#import "GCDAsyncSocket.h"

// ip get
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

@interface ViewController()

@property(nonatomic) IBOutlet UITextField *portF;
@property(nonatomic) IBOutlet UITextField *messageTF;
@property(nonatomic) IBOutlet UITextView *showContentMessageTV;

//服务器socket（开放端口，监听客户端socket的链接）

@property(nonatomic) GCDAsyncSocket *serverSocket;
//保护客户端socket
@property(nonatomic) GCDAsyncSocket *clientSocket;
@end
@implementation ViewController

#pragma mark -服务器socket Delegate

- (void)socket:(GCDAsyncSocket*)sock didAcceptNewSocket:(GCDAsyncSocket*)newSocket{
    //保存客户端的socket
    self.clientSocket= newSocket;
    [self showMessageWithStr:@"链接成功"];
    [self showMessageWithStr:[NSString stringWithFormat:@"服务器地址：%@ 端口：%d", newSocket.connectedHost, newSocket.connectedPort]];
    [self.clientSocket readDataWithTimeout:-1 tag:0];
}

//收到消息

- (void)socket:(GCDAsyncSocket*)sock didReadData:(NSData*)data withTag:(long)tag{
    NSString*text = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [self showMessageWithStr:text];
    [self.clientSocket readDataWithTimeout:-1 tag:0];
}

//发送消息

- (IBAction)sendMessage:(id)sender {
    NSData *data = [self.messageTF.text dataUsingEncoding:NSUTF8StringEncoding];
    //withTimeout -1:无穷大，一直等
    //tag:消息标记
    [self.clientSocket writeData:data withTimeout:-1 tag:0];
}

//开始监听

- (IBAction)startReceive:(id)sender {
    //2、开放哪一个端口
    NSError  *error =nil;
    BOOL result = [self.serverSocket acceptOnPort:self.portF.text.integerValue error:&error];
    if(result && error ==nil) {
        //开放成功
        NSString *text = [NSString stringWithFormat:@"端口%@开放成功", self.portF.text ];
        [self showMessageWithStr:text];
    }
}

//接受消息,socket是客户端socket，表示从哪一个客户端读取消息

- (IBAction)ReceiveMessage:(id)sender {
    [self.clientSocket readDataWithTimeout:11 tag:0];
}

- (void)showMessageWithStr:(NSString*)str{
    self.showContentMessageTV.text= [self.showContentMessageTV.text stringByAppendingFormat:@"%@\n",str];
    
}

#pragma mark - 获取设备当前网络IP地址
- (NSString *)getMyIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en1"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
}

- (NSString *)getIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    NSLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         NSLog(@"%@",address);
         //筛选出IP地址格式
         if([self isValidatIP:address]) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}

- (BOOL)isValidatIP:(NSString *)ipAddress {
    if (ipAddress.length == 0) {
        return NO;
    }
    NSString *urlRegEx = @"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
    
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:urlRegEx options:0 error:&error];
    
    if (regex != nil) {
        NSTextCheckingResult *firstMatch=[regex firstMatchInString:ipAddress options:0 range:NSMakeRange(0, [ipAddress length])];
        
        if (firstMatch) {
            NSRange resultRange = [firstMatch rangeAtIndex:0];
            NSString *result=[ipAddress substringWithRange:resultRange];
            //输出结果
            NSLog(@"%@",result);
            return YES;
        }
    }
    return NO;
}

- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self uiSetup];
    
    // Do any additional setup after loading the view, typically from a nib.
    // 1、初始化服务器socket，在主线程力回调
    self.serverSocket= [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)uiSetup {
  
    UILabel *port = [[UILabel alloc] initWithFrame:CGRectMake(20, 30, 60, 30)];
    port.text = @"端口";
    [self.view addSubview:port];
    UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(20, 65, 60, 30)];
    msg.text = @"消息";
    [self.view addSubview:msg];
    
    UIButton *startListen = [[UIButton alloc] initWithFrame:CGRectMake(130, 30, 90, 30)];
    [self.view addSubview:startListen];
    [startListen setTitle:@"开始监听" forState:UIControlStateNormal];
    [startListen setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [startListen addTarget:self action:@selector(startReceive:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *sendMsg= [[UIButton alloc] initWithFrame:CGRectMake(220, 30, 70, 30)];
    [self.view addSubview:sendMsg];
    [sendMsg setTitle:@"发消息" forState:UIControlStateNormal];
    [sendMsg setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [sendMsg addTarget:self action:@selector(sendMessage:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *receiveMsg = [[UIButton alloc] initWithFrame:CGRectMake(220, 60, 70, 30)];
    [self.view addSubview:receiveMsg];
    [receiveMsg setTitle:@"接消息" forState:UIControlStateNormal];
    [receiveMsg setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [receiveMsg addTarget:self action:@selector(ReceiveMessage:) forControlEvents:UIControlEventTouchUpInside];
    
    self.portF = [[UITextField alloc] initWithFrame:CGRectMake(60, 30, 60, 30)];
    self.portF.layer.borderColor = [[UIColor blackColor]CGColor];
    self.portF.layer.cornerRadius=8.0f;
    self.portF.layer.borderWidth= 1.0f;
    self.messageTF = [[UITextField alloc] initWithFrame:CGRectMake(60, 65, 150, 30)];
    self.messageTF.layer.borderColor = [[UIColor blackColor]CGColor];
    self.messageTF.layer.cornerRadius=8.0f;
    self.messageTF.layer.borderWidth= 1.0f;
    self.showContentMessageTV = [[UITextView alloc] initWithFrame:CGRectMake(20, 100, 300, 300)];
    self.showContentMessageTV.layer.backgroundColor =[[UIColor grayColor]CGColor];
    self.showContentMessageTV.text = [self getMyIPAddress];
    //[self getIPAddress:true];
    [self.view addSubview:self.portF];
    [self.view addSubview:self.messageTF];
    [self.view addSubview:self.showContentMessageTV];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

