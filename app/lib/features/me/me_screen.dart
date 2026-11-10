import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';
import '../browser/browser_screen.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_screen.dart';

/// 「我的」tab：设置、同步、卡片浏览的集中入口 + 关于。
///
/// 首页 AppBar 之前挤着 6 个图标，其中浏览/统计/设置属于低频操作，
/// 收进这里后首页只保留"添加"和"导入"两个常驻动作。
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = 'v${info.version}+${info.buildNumber}');
    } catch (_) {
      // 读取失败则不显示版本号，不影响功能。
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: InkPage(
        padding: const EdgeInsets.fromLTRB(
            InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s8),
        children: [
          _brandCard(p),
          const SizedBox(height: InkTokens.s5),
          InkSection(
            title: '学习',
            padding: const EdgeInsets.only(bottom: InkTokens.s2),
          ),
          InkCard(
            raise: false,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _entry(
                  icon: Icons.tune,
                  title: '学习设置',
                  hint: '每日上限与期望保持率',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                _divider(p),
                _entry(
                  icon: Icons.style_outlined,
                  title: '浏览卡片',
                  hint: '搜索、挂起、删除',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BrowserScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: InkTokens.s5),
          InkSection(
            title: '数据',
            padding: const EdgeInsets.only(bottom: InkTokens.s2),
          ),
          InkCard(
            raise: false,
            padding: EdgeInsets.zero,
            child: _entry(
              icon: Icons.sync_outlined,
              title: '多设备同步',
              hint: '连接自建服务端，跨设备合并进度',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              ),
            ),
          ),
          const SizedBox(height: InkTokens.s6),
          Center(
            child: Text(
              '跬步 Onestep  $_version\n本地优先，数据在你手中',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.7, color: p.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandCard(InkPalette p) {
    return InkCard(
      raise: false,
      borderColor: p.primary.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(InkTokens.s5),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.primary,
              borderRadius: BorderRadius.circular(InkTokens.rButton),
            ),
            alignment: Alignment.center,
            child: const Text(
              '跬',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: InkTokens.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('不积跬步，无以至千里',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink1)),
                const SizedBox(height: 3),
                Text('每天进步一点点',
                    style: TextStyle(fontSize: 12.5, color: p.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(InkPalette p) => Divider(height: 1, thickness: 1, color: p.line, indent: InkTokens.s4, endIndent: InkTokens.s4);

  Widget _entry({
    required IconData icon,
    required String title,
    required String hint,
    required VoidCallback onTap,
  }) {
    final p = InkPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkTokens.s4, vertical: InkTokens.s4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: p.primaryPale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: p.primary),
            ),
            const SizedBox(width: InkTokens.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(hint, style: TextStyle(fontSize: 12.5, color: p.ink3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: p.ink3),
          ],
        ),
      ),
    );
  }
}
