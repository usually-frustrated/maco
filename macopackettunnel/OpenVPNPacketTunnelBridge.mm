#import "OpenVPNPacketTunnelBridge.h"
#import <os/log.h>

#include <client/ovpncli.cpp>
#include <openvpn/crypto/data_epoch.cpp>
#include <openvpn/tun/client/tunprop.hpp>

#include <atomic>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <sys/socket.h>

using namespace openvpn;

namespace {

static NSString *const OpenVPNPacketTunnelErrorDomain = @"frustrated.maco.packet-tunnel";

static os_log_t OpenVPNLog()
{
    static os_log_t log = os_log_create("frustrated.maco.app.packet-tunnel", "OpenVPN");
    return log;
}

static NSError *BridgeError(NSString *message, NSInteger code = 1)
{
    return [NSError errorWithDomain:OpenVPNPacketTunnelErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSString *NSStringFromStdString(const std::string &value)
{
    return [[NSString alloc] initWithBytes:value.data()
                                    length:value.size()
                                  encoding:NSUTF8StringEncoding] ?: @"";
}

static std::string StdStringFromNSString(NSString *value)
{
    if (!value) {
        return {};
    }

    return std::string(value.UTF8String ?: "");
}

static NSString *IPv4MaskFromPrefix(int prefixLength)
{
    uint32_t mask = prefixLength <= 0 ? 0 : 0xffffffffu << (32 - std::min(prefixLength, 32));
    return [NSString stringWithFormat:@"%u.%u.%u.%u",
                                      (mask >> 24) & 0xff,
                                      (mask >> 16) & 0xff,
                                      (mask >> 8) & 0xff,
                                      mask & 0xff];
}

static NSArray<NEIPv4Route *> *BuildIPv4Routes(const std::vector<std::pair<std::string, int>> &routes, BOOL defaultRoute)
{
    NSMutableArray<NEIPv4Route *> *result = [NSMutableArray arrayWithCapacity:routes.size() + (defaultRoute ? 1 : 0)];
    if (defaultRoute) {
        [result addObject:[NEIPv4Route defaultRoute]];
    }
    for (const auto &[address, prefixLength] : routes) {
        NEIPv4Route *route = [[NEIPv4Route alloc] initWithDestinationAddress:NSStringFromStdString(address)
                                                                   subnetMask:IPv4MaskFromPrefix(prefixLength)];
        if (route) {
            [result addObject:route];
        }
    }
    return result;
}

static NSArray<NEIPv6Route *> *BuildIPv6Routes(const std::vector<std::pair<std::string, int>> &routes, BOOL defaultRoute)
{
    NSMutableArray<NEIPv6Route *> *result = [NSMutableArray arrayWithCapacity:routes.size() + (defaultRoute ? 1 : 0)];
    if (defaultRoute) {
        [result addObject:[NEIPv6Route defaultRoute]];
    }
    for (const auto &[address, prefixLength] : routes) {
        NEIPv6Route *route = [[NEIPv6Route alloc] initWithDestinationAddress:NSStringFromStdString(address)
                                                           networkPrefixLength:@(prefixLength)];
        if (route) {
            [result addObject:route];
        }
    }
    return result;
}

static NEPacketTunnelNetworkSettings *BuildNetworkSettings(
    NSString *remoteAddress,
    int mtu,
    const std::vector<std::pair<std::string, int>> &ipv4Addresses,
    const std::vector<std::pair<std::string, int>> &ipv6Addresses,
    const std::vector<std::pair<std::string, int>> &ipv4Routes,
    const std::vector<std::pair<std::string, int>> &ipv6Routes,
    const std::vector<std::pair<std::string, int>> &excludedIPv4Routes,
    const std::vector<std::pair<std::string, int>> &excludedIPv6Routes,
    BOOL routeAllIPv4,
    BOOL routeAllIPv6,
    const std::vector<std::string> &dnsServers,
    const std::vector<std::string> &dnsSearchDomains)
{
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:remoteAddress ?: @""];
    if (mtu > 0) {
        settings.MTU = @(mtu);
    }

    if (!ipv4Addresses.empty()) {
        NSMutableArray<NSString *> *addresses = [NSMutableArray arrayWithCapacity:ipv4Addresses.size()];
        NSMutableArray<NSString *> *masks = [NSMutableArray arrayWithCapacity:ipv4Addresses.size()];
        for (const auto &[address, prefixLength] : ipv4Addresses) {
            [addresses addObject:NSStringFromStdString(address)];
            [masks addObject:IPv4MaskFromPrefix(prefixLength)];
        }
        NEIPv4Settings *ipv4 = [[NEIPv4Settings alloc] initWithAddresses:addresses subnetMasks:masks];
        ipv4.includedRoutes = BuildIPv4Routes(ipv4Routes, routeAllIPv4);
        ipv4.excludedRoutes = BuildIPv4Routes(excludedIPv4Routes, NO);
        settings.IPv4Settings = ipv4;
    } else if (routeAllIPv4 || !ipv4Routes.empty()) {
        NEIPv4Settings *ipv4 = [[NEIPv4Settings alloc] initWithAddresses:@[] subnetMasks:@[]];
        ipv4.includedRoutes = BuildIPv4Routes(ipv4Routes, routeAllIPv4);
        ipv4.excludedRoutes = BuildIPv4Routes(excludedIPv4Routes, NO);
        settings.IPv4Settings = ipv4;
    }

    if (!ipv6Addresses.empty()) {
        NSMutableArray<NSString *> *addresses = [NSMutableArray arrayWithCapacity:ipv6Addresses.size()];
        NSMutableArray<NSNumber *> *prefixLengths = [NSMutableArray arrayWithCapacity:ipv6Addresses.size()];
        for (const auto &[address, prefixLength] : ipv6Addresses) {
            [addresses addObject:NSStringFromStdString(address)];
            [prefixLengths addObject:@(prefixLength)];
        }
        NEIPv6Settings *ipv6 = [[NEIPv6Settings alloc] initWithAddresses:addresses networkPrefixLengths:prefixLengths];
        ipv6.includedRoutes = BuildIPv6Routes(ipv6Routes, routeAllIPv6);
        ipv6.excludedRoutes = BuildIPv6Routes(excludedIPv6Routes, NO);
        settings.IPv6Settings = ipv6;
    } else if (routeAllIPv6 || !ipv6Routes.empty()) {
        NEIPv6Settings *ipv6 = [[NEIPv6Settings alloc] initWithAddresses:@[] networkPrefixLengths:@[]];
        ipv6.includedRoutes = BuildIPv6Routes(ipv6Routes, routeAllIPv6);
        ipv6.excludedRoutes = BuildIPv6Routes(excludedIPv6Routes, NO);
        settings.IPv6Settings = ipv6;
    }

    if (!dnsServers.empty()) {
        NSMutableArray<NSString *> *serverList = [NSMutableArray arrayWithCapacity:dnsServers.size()];
        for (const auto &server : dnsServers) {
            [serverList addObject:NSStringFromStdString(server)];
        }
        NEDNSSettings *dns = [[NEDNSSettings alloc] initWithServers:serverList];
        if (!dnsSearchDomains.empty()) {
            NSMutableArray<NSString *> *searchDomains = [NSMutableArray arrayWithCapacity:dnsSearchDomains.size()];
            for (const auto &domain : dnsSearchDomains) {
                [searchDomains addObject:NSStringFromStdString(domain)];
            }
            dns.searchDomains = searchDomains;
        }
        settings.DNSSettings = dns;
    }

    return settings;
}

struct PacketTunnelSetupState {
    void setErrorText(std::string text)
    {
        std::lock_guard<std::mutex> lock(mutex);
        errorText = std::move(text);
    }

    std::string currentErrorText()
    {
        std::lock_guard<std::mutex> lock(mutex);
        return errorText;
    }

    std::mutex mutex;
    std::atomic<bool> finished{false};
    std::string errorText;
};

class PacketTunnelSettingsBuilder final : public TunBuilderBase {
  public:
    PacketTunnelSettingsBuilder(OpenVPNPacketTunnelBridge *bridge,
                                NSString *remoteAddress,
                                std::shared_ptr<PacketTunnelSetupState> setupState)
        : bridge_(bridge),
          remoteAddress_(remoteAddress),
          setupState_(std::move(setupState))
    {
    }

    bool tun_builder_new() override
    {
        ipv4Addresses_.clear();
        ipv6Addresses_.clear();
        ipv4Routes_.clear();
        ipv6Routes_.clear();
        dnsServers_.clear();
        dnsSearchDomains_.clear();
        routeAllIPv4_ = false;
        routeAllIPv6_ = false;
        mtu_ = 0;
        return true;
    }

    bool tun_builder_set_layer(int layer) override
    {
        return layer == 3;
    }

    bool tun_builder_set_remote_address(const std::string &address, bool) override
    {
        remoteAddress_ = NSStringFromStdString(address);
        return true;
    }

    bool tun_builder_add_address(const std::string &address,
                                 int prefix_length,
                                 const std::string &,
                                 bool ipv6,
                                 bool) override
    {
        if (ipv6) {
            ipv6Addresses_.emplace_back(address, prefix_length);
        } else {
            ipv4Addresses_.emplace_back(address, prefix_length);
        }
        return true;
    }

    bool tun_builder_set_route_metric_default(int) override
    {
        return true;
    }

    bool tun_builder_reroute_gw(bool ipv4, bool ipv6, unsigned int) override
    {
        routeAllIPv4_ = routeAllIPv4_ || ipv4;
        routeAllIPv6_ = routeAllIPv6_ || ipv6;
        return true;
    }

    bool tun_builder_add_route(const std::string &address,
                               int prefix_length,
                               int,
                               bool ipv6) override
    {
        if (ipv6) {
            ipv6Routes_.emplace_back(address, prefix_length);
        } else {
            ipv4Routes_.emplace_back(address, prefix_length);
        }
        return true;
    }

    bool tun_builder_exclude_route(const std::string &address,
                                   int prefix_length,
                                   int,
                                   bool ipv6) override
    {
        if (ipv6) {
            excludedIPv6Routes_.emplace_back(address, prefix_length);
        } else {
            excludedIPv4Routes_.emplace_back(address, prefix_length);
        }
        return true;
    }

    bool tun_builder_set_dns_options(const DnsOptions &dns) override
    {
        for (const auto &[priority, server] : dns.servers) {
            (void)priority;
            for (const auto &address : server.addresses) {
                dnsServers_.push_back(address.address);
            }
        }
        for (const auto &domain : dns.search_domains) {
            dnsSearchDomains_.push_back(domain.to_string());
        }
        return true;
    }

    bool tun_builder_set_mtu(int mtu) override
    {
        mtu_ = mtu;
        return true;
    }

    bool tun_builder_set_session_name(const std::string &) override
    {
        return true;
    }

    bool tun_builder_add_proxy_bypass(const std::string &) override
    {
        return true;
    }

    bool tun_builder_set_proxy_auto_config_url(const std::string &) override
    {
        return true;
    }

    bool tun_builder_set_proxy_http(const std::string &, int) override
    {
        return true;
    }

    bool tun_builder_set_proxy_https(const std::string &, int) override
    {
        return true;
    }

    bool tun_builder_add_wins_server(const std::string &) override
    {
        return true;
    }

    bool tun_builder_set_allow_family(int, bool) override
    {
        return true;
    }

    bool tun_builder_set_allow_local_dns(bool) override
    {
        return true;
    }

    int tun_builder_establish() override
    {
        if (!bridge_) {
            return -1;
        }

        __block NSError *settingsError = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        NEPacketTunnelNetworkSettings *settings = BuildNetworkSettings(
            remoteAddress_,
            mtu_,
            ipv4Addresses_,
            ipv6Addresses_,
            ipv4Routes_,
            ipv6Routes_,
            excludedIPv4Routes_,
            excludedIPv6Routes_,
            routeAllIPv4_,
            routeAllIPv6_,
            dnsServers_,
            dnsSearchDomains_);

        [bridge_ applyTunnelSettings:settings completion:^(NSError * _Nullable error) {
            settingsError = error;
            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC));
        if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
            setupState_->setErrorText("Timed out applying tunnel settings.");
            setupState_->finished.store(true);
            return -1;
        }

        if (settingsError) {
            setupState_->setErrorText(settingsError.localizedDescription.UTF8String ?: "Failed to apply tunnel settings.");
            setupState_->finished.store(true);
            return -1;
        }

        setupState_->finished.store(true);
        return 0;
    }

  private:
    OpenVPNPacketTunnelBridge *bridge_ = nil;
    NSString *remoteAddress_ = @"";
    std::shared_ptr<PacketTunnelSetupState> setupState_;
    std::vector<std::pair<std::string, int>> ipv4Addresses_;
    std::vector<std::pair<std::string, int>> ipv6Addresses_;
    std::vector<std::pair<std::string, int>> ipv4Routes_;
    std::vector<std::pair<std::string, int>> ipv6Routes_;
    std::vector<std::pair<std::string, int>> excludedIPv4Routes_;
    std::vector<std::pair<std::string, int>> excludedIPv6Routes_;
    std::vector<std::string> dnsServers_;
    std::vector<std::string> dnsSearchDomains_;
    bool routeAllIPv4_ = false;
    bool routeAllIPv6_ = false;
    int mtu_ = 0;
};

class PacketFlowTunClient final : public TunClient {
  public:
    PacketFlowTunClient(openvpn_io::io_context &ioContext,
                        TunClientParent &parent,
                        NEPacketTunnelFlow *packetFlow,
                        OpenVPNPacketTunnelBridge *bridge,
                        ExternalTun::Config config,
                        NSString *remoteAddress,
                        std::shared_ptr<PacketTunnelSetupState> setupState)
        : ioContext_(ioContext),
          parent_(parent),
          packetFlow_(packetFlow),
          bridge_(bridge),
          config_(std::move(config)),
          state_(new TunProp::State()),
          setupState_(std::move(setupState)),
          remoteAddress_(remoteAddress)
    {
    }

    ~PacketFlowTunClient() override
    {
        stop();
    }

    void tun_start(const OptionList &opt, TransportClient &transcli, CryptoDCSettings &) override
    {
        if (started_) {
            return;
        }

        started_ = true;
        parent_.tun_pre_tun_config();

        try {
            PacketTunnelSettingsBuilder builder(bridge_, remoteAddress_, setupState_);
            if (!builder.tun_builder_new()) {
                throw std::runtime_error("packet tunnel builder reset failed");
            }

            const IP::Addr serverAddress = transcli.server_endpoint_addr();
            TunProp::configure_builder(&builder,
                                       state_.get(),
                                       config_.stats.get(),
                                       serverAddress,
                                       config_.tun_prop,
                                       opt,
                                       nullptr,
                                       false);

            if (builder.tun_builder_establish() < 0) {
                throw std::runtime_error(setupState_->currentErrorText().empty() ? "packet tunnel setup failed" : setupState_->currentErrorText());
            }

            beginReadLoop();
            parent_.tun_connected();
        } catch (const std::exception &e) {
            stop();
            parent_.tun_error(Error::TUN_SETUP_FAILED, e.what());
        }
    }

    bool tun_send(BufferAllocated &buf) override
    {
        if (stopped_ || !packetFlow_) {
            return false;
        }

        const NSUInteger length = static_cast<NSUInteger>(buf.size());
        NSData *packet = [NSData dataWithBytes:buf.c_data() length:length];
        NSInteger protocol = ((buf.size() > 0) && ((buf.c_data()[0] >> 4) == 6)) ? AF_INET6 : AF_INET;
        [packetFlow_ writePackets:@[packet] withProtocols:@[@(protocol)]];
        return true;
    }

    std::string tun_name() const override
    {
        return "packet-tunnel";
    }

    std::string vpn_ip4() const override
    {
        return state_->vpn_ip4_addr.specified() ? state_->vpn_ip4_addr.to_string() : "";
    }

    std::string vpn_ip6() const override
    {
        return state_->vpn_ip6_addr.specified() ? state_->vpn_ip6_addr.to_string() : "";
    }

    std::string vpn_gw4() const override
    {
        return state_->vpn_ip4_gw.specified() ? state_->vpn_ip4_gw.to_string() : "";
    }

    std::string vpn_gw6() const override
    {
        return state_->vpn_ip6_gw.specified() ? state_->vpn_ip6_gw.to_string() : "";
    }

    int vpn_mtu() const override
    {
        return state_->mtu;
    }

    void set_disconnect() override
    {
        stopped_ = true;
    }

    void stop() override
    {
        stopped_ = true;
    }

    void adjust_mss(int) override
    {
    }

  private:
    void beginReadLoop()
    {
        if (stopped_ || !packetFlow_) {
            return;
        }

        PacketFlowTunClient *client = this;
        [packetFlow_ readPacketsWithCompletionHandler:^(NSArray<NSData *> *packets, NSArray<NSNumber *> *) {
            if (client->stopped_) {
                return;
            }

            for (NSData *packet in packets) {
                const auto *bytes = static_cast<const unsigned char *>(packet.bytes);
                BufferAllocated buf(bytes, packet.length, 0);
                openvpn_io::post(ioContext_, [client, packet = std::move(buf)]() mutable {
                    if (!client->stopped_) {
                        client->parent_.tun_recv(packet);
                    }
                });
            }

            client->beginReadLoop();
        }];
    }

    openvpn_io::io_context &ioContext_;
    TunClientParent &parent_;
    NEPacketTunnelFlow *packetFlow_ = nil;
    OpenVPNPacketTunnelBridge *bridge_ = nil;
    ExternalTun::Config config_;
    TunProp::State::Ptr state_;
    std::shared_ptr<PacketTunnelSetupState> setupState_;
    NSString *remoteAddress_ = @"";
    std::atomic<bool> stopped_{false};
    bool started_ = false;
};

class PacketFlowTunClientFactory final : public TunClientFactory {
  public:
    PacketFlowTunClientFactory(OpenVPNPacketTunnelBridge *bridge,
                               NEPacketTunnelFlow *packetFlow,
                               ExternalTun::Config config,
                               NSString *remoteAddress,
                               std::shared_ptr<PacketTunnelSetupState> setupState)
        : bridge_(bridge),
          packetFlow_(packetFlow),
          config_(std::move(config)),
          remoteAddress_(remoteAddress),
          setupState_(std::move(setupState))
    {
    }

    ~PacketFlowTunClientFactory() override = default;

    TunClient::Ptr new_tun_client_obj(openvpn_io::io_context &io_context,
                                      TunClientParent &parent,
                                      TransportClient *) override
    {
        return TunClient::Ptr(new PacketFlowTunClient(io_context,
                                                      parent,
                                                      packetFlow_,
                                                      bridge_,
                                                      config_,
                                                      remoteAddress_,
                                                      setupState_));
    }

    bool supports_epoch_data() override
    {
        return true;
    }

  private:
    OpenVPNPacketTunnelBridge *bridge_ = nil;
    NEPacketTunnelFlow *packetFlow_ = nil;
    ExternalTun::Config config_;
    NSString *remoteAddress_ = @"";
    std::shared_ptr<PacketTunnelSetupState> setupState_;
};

class PacketTunnelOpenVPNClient final : public ClientAPI::OpenVPNClient {
  public:
    PacketTunnelOpenVPNClient(OpenVPNPacketTunnelBridge *bridge,
                              NSString *profileConfigContent,
                              NSString *profileID,
                              NSString *username,
                              NSString *password,
                              NSString *response,
                              NEPacketTunnelFlow *packetFlow,
                              std::shared_ptr<PacketTunnelSetupState> setupState)
        : bridge_(bridge),
          profileConfigContent_(profileConfigContent),
          profileID_(profileID),
          username_(username),
          password_(password),
          response_(response),
          packetFlow_(packetFlow),
          setupState_(std::move(setupState))
    {
    }

    ~PacketTunnelOpenVPNClient() override
    = default;

    bool pause_on_connection_timeout() override
    {
        return false;
    }

    bool socket_protect(openvpn_io::detail::socket_type, std::string, bool) override
    {
        return true;
    }

    void event(const ClientAPI::Event &ev) override
    {
        os_log(OpenVPNLog(), "event name=%{public}s info=%{public}s error=%d fatal=%d",
               ev.name.c_str(), ev.info.c_str(), ev.error, ev.fatal);
        if (ev.error && ev.fatal && !setupState_->finished.load()) {
            setupState_->setErrorText(ev.info);
            setupState_->finished.store(true);
        }
    }

    void log(const ClientAPI::LogInfo &info) override
    {
        os_log(OpenVPNLog(), "log: %{public}s", info.text.c_str());
    }

    void external_pki_cert_request(ClientAPI::ExternalPKICertRequest &) override
    {
    }

    void external_pki_sign_request(ClientAPI::ExternalPKISignRequest &) override
    {
    }

    void acc_event(const ClientAPI::AppCustomControlMessageEvent &) override
    {
    }

    TunClientFactory *new_tun_factory(const ExternalTun::Config &conf, const OptionList &) override
    {
        tunFactory_.reset(new PacketFlowTunClientFactory(bridge_,
                                                         packetFlow_,
                                                         conf,
                                                         @"",
                                                         setupState_));
        return tunFactory_.get();
    }

    ClientAPI::Status start()
    {
        ClientAPI::Status status;
        @autoreleasepool {
            NSString *content = profileConfigContent_ ?: @"";

            ClientAPI::OpenVPNClientHelper helper;
            const auto merged = helper.merge_config_string(StdStringFromNSString(content));
            if (!merged.errorText.empty()) {
                status.error = true;
                status.message = merged.errorText;
                setupState_->setErrorText(status.message);
                setupState_->finished.store(true);
                return status;
            }

            ClientAPI::Config config;
            config.content = merged.profileContent;
            config.guiVersion = "maco 0.1.0";

            const auto eval = eval_config(config);
            if (eval.error) {
                status.error = true;
                status.message = eval.message;
                setupState_->setErrorText(status.message);
                setupState_->finished.store(true);
                return status;
            }

            if (!eval.autologin) {
                if (username_.length == 0 || password_.length == 0) {
                    status.error = true;
                    status.message = "Username and password are required.";
                    setupState_->setErrorText(status.message);
                    setupState_->finished.store(true);
                    return status;
                }

                ClientAPI::ProvideCreds creds;
                creds.username = StdStringFromNSString(username_);
                creds.password = StdStringFromNSString(password_);
                // response_ holds the TOTP/static-challenge answer.
                // OpenVPN3 expects this in creds.response, NOT appended to the password.
                if (response_.length > 0) {
                    creds.response = StdStringFromNSString(response_);
                }
                const auto provided = provide_creds(creds);
                if (provided.error) {
                    status.error = true;
                    status.message = provided.message;
                    setupState_->setErrorText(status.message);
                    setupState_->finished.store(true);
                    return status;
                }
            }
        }

        return status;
    }

    std::shared_ptr<PacketTunnelSetupState> setupState() const
    {
        return setupState_;
    }

  private:
    OpenVPNPacketTunnelBridge *bridge_ = nil;
    NSString *profileConfigContent_ = @"";
    NSString *profileID_ = @"";
    NSString *username_ = @"";
    NSString *password_ = @"";
    NSString *response_ = @"";
    NEPacketTunnelFlow *packetFlow_ = nil;
    std::shared_ptr<PacketTunnelSetupState> setupState_;
    std::unique_ptr<PacketFlowTunClientFactory> tunFactory_;
};

} // namespace

@interface OpenVPNPacketTunnelBridge ()
- (void)applyTunnelSettings:(NEPacketTunnelNetworkSettings *)settings
                 completion:(OpenVPNPacketTunnelSettingsCompletion)completion;
@end

@implementation OpenVPNPacketTunnelBridge {
    NSString *_profileConfigContent;
    NSUUID *_profileID;
    NSString *_username;
    NSString *_password;
    NSString *_response;
    OpenVPNPacketTunnelSettingsApplier _applySettings;
    std::unique_ptr<PacketTunnelOpenVPNClient> _client;
    std::thread _worker;
    std::mutex _stateMutex;
    std::shared_ptr<PacketTunnelSetupState> _setupState;
}

- (instancetype)initWithProfileConfigContent:(NSString *)profileConfigContent
                               profileID:(NSUUID *)profileID
                                username:(nullable NSString *)username
                                password:(nullable NSString *)password
                                response:(nullable NSString *)response
{
    self = [super init];
    if (self) {
        _profileConfigContent = [profileConfigContent copy];
        _profileID = [profileID copy];
        _username = [username copy];
        _password = [password copy];
        _response = [response copy];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (void)startWithPacketFlow:(NEPacketTunnelFlow *)packetFlow
              applySettings:(OpenVPNPacketTunnelSettingsApplier)applySettings
                 completion:(void (^)(NSError * _Nullable error))completion
{
    if (!applySettings) {
        completion(BridgeError(@"Tunnel settings callback is missing."));
        return;
    }

    _applySettings = [applySettings copy];
    _setupState = std::make_shared<PacketTunnelSetupState>();
    _client = std::make_unique<PacketTunnelOpenVPNClient>(self,
                                                          _profileConfigContent,
                                                          _profileID.UUIDString,
                                                          _username,
                                                          _password,
                                                          _response,
                                                          packetFlow,
                                                          _setupState);

    ClientAPI::Status status = _client->start();
    if (status.error) {
        completion(BridgeError(NSStringFromStdString(status.message)));
        return;
    }

        _worker = std::thread([client = _client.get(), setupState = _setupState]() mutable {
            ClientAPI::Status connectStatus = client->connect();
            os_log(OpenVPNLog(), "connect() returned: error=%d message=%{public}s",
                   connectStatus.error, connectStatus.message.c_str());
            if (!setupState->finished.load() && !setupState->currentErrorText().empty()) {
                setupState->finished.store(true);
            }
            if (connectStatus.error && !setupState->finished.load()) {
                setupState->setErrorText(connectStatus.message);
                setupState->finished.store(true);
            }
        });

    const CFTimeInterval startTime = CFAbsoluteTimeGetCurrent();
    while (!_setupState->finished.load()) {
        if ((CFAbsoluteTimeGetCurrent() - startTime) > 120.0) {
            [self stop];
            completion(BridgeError(@"Timed out waiting for tunnel startup."));
            return;
        }
        [NSThread sleepForTimeInterval:0.01];
    }

    if (!_setupState->currentErrorText().empty()) {
        [self stop];
        completion(BridgeError(NSStringFromStdString(_setupState->currentErrorText())));
        return;
    }

    completion(nil);
}

- (void)stop
{
    if (_client) {
        _client->stop();
    }

    if (_worker.joinable()) {
        _worker.join();
    }
}

- (void)applyTunnelSettings:(NEPacketTunnelNetworkSettings *)settings
                 completion:(OpenVPNPacketTunnelSettingsCompletion)completion
{
    if (!_applySettings) {
        completion(BridgeError(@"Tunnel settings callback is missing."));
        return;
    }

    _applySettings(settings, completion);
}

@end
