import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      vpnSettingProvider.select((state) => state.enable),
    );
    return ListItem.switchItem(
      title: const Text('VPN'),
      subtitle: Text(appLocalizations.vpnEnableDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(enable: value));
        },
      ),
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.tun),
      subtitle: Text(appLocalizations.tunDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith.tun(enable: value));
        },
      ),
    );
  }
}

class VpnBackendItem extends ConsumerWidget {
  const VpnBackendItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final backend = ref.watch(
      vpnSettingProvider.select((state) => state.backend),
    );
    return ListItem.options(
      title: const Text('VPN backend'),
      subtitle: Text(backend == 'zivpn' ? 'ZiVPN / UDPGW' : 'Clash / Mihomo'),
      delegate: OptionsDelegate<String>(
        title: 'VPN backend',
        value: backend,
        options: const ['clash', 'zivpn'],
        textBuilder: (value) =>
            value == 'zivpn' ? 'ZiVPN / UDPGW' : 'Clash / Mihomo',
        onChanged: (value) {
          if (value == null) return;
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(backend: value));
        },
      ),
    );
  }
}

class ZiVpnServerItem extends ConsumerWidget {
  const ZiVpnServerItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      vpnSettingProvider.select((state) => state.zivpnServer),
    );
    return ListItem.input(
      title: const Text('ZiVPN server'),
      subtitle: Text(value.isEmpty ? 'host/IP server' : value),
      delegate: InputDelegate(
        title: 'ZiVPN server',
        value: value,
        onChanged: (value) {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(zivpnServer: value ?? ''));
        },
      ),
    );
  }
}

class ZiVpnPortItem extends ConsumerWidget {
  const ZiVpnPortItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      vpnSettingProvider.select((state) => state.zivpnPortRange),
    );
    return ListItem.input(
      title: const Text('ZiVPN port/range'),
      subtitle: Text(value.isEmpty ? 'contoh: 443 atau 10000-20000' : value),
      delegate: InputDelegate(
        title: 'ZiVPN port/range',
        value: value,
        onChanged: (value) {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(zivpnPortRange: value ?? ''));
        },
      ),
    );
  }
}

class ZiVpnPasswordItem extends ConsumerWidget {
  const ZiVpnPasswordItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final hasValue = ref.watch(
      vpnSettingProvider.select((state) => state.zivpnPassword.isNotEmpty),
    );
    return ListItem.input(
      title: const Text('ZiVPN password'),
      subtitle: Text(hasValue ? 'tersimpan' : 'auth/password ZiVPN'),
      delegate: InputDelegate(
        title: 'ZiVPN password',
        value: ref.read(vpnSettingProvider).zivpnPassword,
        onChanged: (value) {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(zivpnPassword: value ?? ''));
        },
      ),
    );
  }
}

class ZiVpnObfsItem extends ConsumerWidget {
  const ZiVpnObfsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      vpnSettingProvider.select((state) => state.zivpnObfs),
    );
    return ListItem.input(
      title: const Text('ZiVPN obfs'),
      subtitle: Text(value.isEmpty ? 'obfs/sni sesuai akun ZiVPN' : value),
      delegate: InputDelegate(
        title: 'ZiVPN obfs',
        value: value,
        onChanged: (value) {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(zivpnObfs: value ?? ''));
        },
      ),
    );
  }
}

class ZiVpnUdpGwItem extends ConsumerWidget {
  const ZiVpnUdpGwItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      vpnSettingProvider.select((state) => state.zivpnEnableUdpGw),
    );
    return ListItem.switchItem(
      title: const Text('ZiVPN UDPGW'),
      subtitle: const Text('Forward UDP lewat udpgw seperti MiniZiVPN'),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(zivpnEnableUdpGw: value));
        },
      ),
    );
  }
}

class ZiVpnCoreCountItem extends ConsumerWidget {
  const ZiVpnCoreCountItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      vpnSettingProvider.select((state) => state.zivpnCoreCount),
    );
    return ListItem.options(
      title: const Text('ZiVPN cores'),
      subtitle: Text('$value local SOCKS core'),
      delegate: OptionsDelegate<int>(
        title: 'ZiVPN cores',
        value: value,
        options: const [1, 2, 3, 4],
        textBuilder: (value) => '$value core',
        onChanged: (value) {
          if (value == null) return;
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(zivpnCoreCount: value));
        },
      ),
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final allowBypass = ref.watch(
      vpnSettingProvider.select((state) => state.allowBypass),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.allowBypass),
      subtitle: Text(appLocalizations.allowBypassDesc),
      delegate: SwitchDelegate(
        value: allowBypass,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(allowBypass: value));
        },
      ),
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final systemProxy = ref.watch(
      vpnSettingProvider.select((state) => state.systemProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(systemProxy: value));
        },
      ),
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(systemProxy: value));
        },
      ),
    );
  }
}

class Ipv6Item extends ConsumerWidget {
  const Ipv6Item({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final ipv6 = ref.watch(vpnSettingProvider.select((state) => state.ipv6));
    return ListItem.switchItem(
      title: const Text('IPv6'),
      subtitle: Text(appLocalizations.ipv6InboundDesc),
      delegate: SwitchDelegate(
        value: ipv6,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(ipv6: value));
        },
      ),
    );
  }
}

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final autoSetSystemDns = ref.watch(
      networkSettingProvider.select((state) => state.autoSetSystemDns),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoSetSystemDns),
      delegate: SwitchDelegate(
        value: autoSetSystemDns,
        onChanged: (bool value) async {
          ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(autoSetSystemDns: value));
        },
      ),
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final stack = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.stack),
    );

    return ListItem.options(
      title: Text(appLocalizations.stackMode),
      subtitle: Text(stack.name),
      delegate: OptionsDelegate<TunStack>(
        value: stack,
        options: TunStack.values,
        textBuilder: (value) => value.name,
        onChanged: (value) {
          if (value == null) {
            return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith.tun(stack: value));
        },
        title: appLocalizations.stackMode,
      ),
    );
  }
}

class BypassDomainItem extends ConsumerWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final bypassDomain = ref.watch(
      networkSettingProvider.select((state) => state.bypassDomain),
    );
    return ListItem.open(
      title: Text(appLocalizations.bypassDomain),
      subtitle: Text(appLocalizations.bypassDomainDesc),
      delegate: OpenDelegate(
        blur: false,
        widget: ListInputPage(
          title: appLocalizations.bypassDomain,
          items: bypassDomain,
          titleBuilder: (item) => Text(item),
        ),
        onChanged: (items) {
          ref
              .read(networkSettingProvider.notifier)
              .update(
                (state) => state.copyWith(bypassDomain: List.from(items)),
              );
        },
      ),
    );
  }
}

class DNSHijackingItem extends ConsumerWidget {
  const DNSHijackingItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final dnsHijacking = ref.watch(
      vpnSettingProvider.select((state) => state.dnsHijacking),
    );
    return ListItem<RouteMode>.switchItem(
      title: Text(appLocalizations.dnsHijacking),
      delegate: SwitchDelegate(
        value: dnsHijacking,
        onChanged: (value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(dnsHijacking: value));
        },
      ),
    );
  }
}

class RouteModeItem extends ConsumerWidget {
  const RouteModeItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final routeMode = ref.watch(
      networkSettingProvider.select((state) => state.routeMode),
    );
    return ListItem<RouteMode>.options(
      title: Text(appLocalizations.routeMode),
      subtitle: Text(Intl.message('routeMode_${routeMode.name}')),
      delegate: OptionsDelegate<RouteMode>(
        title: appLocalizations.routeMode,
        options: RouteMode.values,
        onChanged: (RouteMode? value) {
          if (value == null) {
            return;
          }
          ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(routeMode: value));
        },
        textBuilder: (routeMode) => Intl.message('routeMode_${routeMode.name}'),
        value: routeMode,
      ),
    );
  }
}

class RouteAddressItem extends ConsumerWidget {
  const RouteAddressItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final bypassPrivate = ref.watch(
      networkSettingProvider.select(
        (state) => state.routeMode == RouteMode.bypassPrivate,
      ),
    );
    if (bypassPrivate) {
      return Container();
    }
    final routeAddress = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.routeAddress),
    );
    return ListItem.open(
      title: Text(appLocalizations.routeAddress),
      subtitle: Text(appLocalizations.routeAddressDesc),
      delegate: OpenDelegate(
        blur: false,
        maxWidth: 360,
        widget: ListInputPage(
          title: appLocalizations.routeAddress,
          items: routeAddress,
          titleBuilder: (item) => Text(item),
        ),
        onChanged: (items) {
          ref
              .read(patchClashConfigProvider.notifier)
              .update(
                (state) => state.copyWith.tun(routeAddress: List.from(items)),
              );
        },
      ),
    );
  }
}

final networkItems = [
  if (system.isAndroid) const VPNItem(),
  if (system.isAndroid)
    ...generateSection(
      title: 'VPN',
      items: [
        const VpnBackendItem(),
        const VpnSystemProxyItem(),
        const BypassDomainItem(),
        const AllowBypassItem(),
        const Ipv6Item(),
        const DNSHijackingItem(),
      ],
    ),
  ...generateSection(
    title: 'ZiVPN',
    items: [
      const ZiVpnServerItem(),
      const ZiVpnPortItem(),
      const ZiVpnPasswordItem(),
      const ZiVpnObfsItem(),
      const ZiVpnUdpGwItem(),
      const ZiVpnCoreCountItem(),
    ],
  ),
  if (system.isDesktop)
    ...generateSection(
      title: appLocalizations.system,
      items: [SystemProxyItem(), BypassDomainItem()],
    ),
  ...generateSection(
    title: appLocalizations.options,
    items: [
      if (system.isDesktop) const TUNItem(),
      if (system.isMacOS) const AutoSetSystemDnsItem(),
      const TunStackItem(),
      if (!system.isDesktop) ...[
        const RouteModeItem(),
        const RouteAddressItem(),
      ],
    ],
  ),
];

class NetworkListView extends StatelessWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context) {
    return generateListView(networkItems);
  }
}
