#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^OpenVPNPacketTunnelSettingsCompletion)(NSError * _Nullable error);
typedef void (^OpenVPNPacketTunnelSettingsApplier)(NEPacketTunnelNetworkSettings *settings,
                                                    OpenVPNPacketTunnelSettingsCompletion completion);

@interface OpenVPNPacketTunnelBridge : NSObject
- (instancetype)initWithProfileConfigContent:(NSString *)profileConfigContent
                               profileID:(NSUUID *)profileID
                                username:(nullable NSString *)username
                                password:(nullable NSString *)password
                                response:(nullable NSString *)response;

- (void)applyTunnelSettings:(NEPacketTunnelNetworkSettings *)settings
                 completion:(OpenVPNPacketTunnelSettingsCompletion)completion;

- (void)startWithPacketFlow:(NEPacketTunnelFlow *)packetFlow
              applySettings:(OpenVPNPacketTunnelSettingsApplier)applySettings
                 completion:(void (^)(NSError * _Nullable error))completion;

- (void)stop;
@end

NS_ASSUME_NONNULL_END
