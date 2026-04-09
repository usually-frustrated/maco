import NetworkExtension

// Entry point for the Network Extension system extension process.
// This hands control to the NetworkExtension framework, which instantiates
// PacketTunnelProvider when the VPN tunnel is started.
autoreleasepool {
    NEProvider.startSystemExtensionMode()
}
