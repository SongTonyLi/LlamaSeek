import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reins/Pages/chat_page/chat_page.dart';
import 'package:reins/Pages/openwebui_page.dart';
import 'package:reins/Widgets/chat_app_bar.dart';
import 'package:reins/Widgets/chat_drawer.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ReinsMainPage extends StatelessWidget {
  const ReinsMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(
        keys: ['serverMode', 'openwebuiAddress'],
      ),
      builder: (context, box, _) {
        final serverMode = box.get('serverMode', defaultValue: 'local');
        final openwebuiAddress = box.get('openwebuiAddress');

        if (serverMode == 'openwebui' && openwebuiAddress != null) {
          return const OpenWebuiPage();
        }

        if (ResponsiveBreakpoints.of(context).isMobile) {
          return const _ReinsMobileMainPage();
        } else {
          return const _ReinsLargeMainPage();
        }
      },
    );
  }
}

class _ReinsMobileMainPage extends StatelessWidget {
  const _ReinsMobileMainPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: ChatAppBar(),
      body: SafeArea(child: ChatPage()),
      drawer: ChatDrawer(),
    );
  }
}

class _ReinsLargeMainPage extends StatelessWidget {
  const _ReinsLargeMainPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            ChatDrawer(),
            Expanded(child: ChatPage()),
          ],
        ),
      ),
    );
  }
}
