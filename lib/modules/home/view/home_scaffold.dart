import 'package:flutter/material.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/modules/billform/view/billform_screen.dart';
import 'package:invoizo/modules/history/view/history_screen.dart';
import 'package:invoizo/modules/profile/view/profile_screen.dart';

class HomeScaffold extends StatefulWidget {
  final int initialIndex;
  const HomeScaffold({super.key, this.initialIndex = 0});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    PhysioBillForm(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long, color: AppTheme.primaryTeal),
            label: 'Generate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared_outlined),
            activeIcon: Icon(Icons.folder_shared, color: AppTheme.primaryTeal),
            label: 'Receipts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge_outlined),
            activeIcon: Icon(Icons.badge, color: AppTheme.primaryTeal),
            label: 'Practice',
          ),
        ],
      ),
    );
  }
}
