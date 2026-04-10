import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/settings/widgets/api_keys_section.dart';
import 'package:yap/features/settings/widgets/general_section.dart';
import 'package:yap/features/settings/widgets/history_section.dart';
import 'package:yap/features/settings/widgets/log_section.dart';
import 'package:yap/features/settings/widgets/profiles_section.dart';

/// Full settings screen with tabbed sections.
///
/// All changes are saved immediately — there is no explicit save button.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['General', 'API Keys', 'Profiles', 'History', 'Log'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              GeneralSection(),
              ApiKeysSection(),
              ProfilesSection(),
              HistorySection(),
              LogSection(),
            ],
          ),
        ),
      ],
    );
  }
}
