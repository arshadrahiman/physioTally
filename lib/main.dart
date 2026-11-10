import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/core/theme/theme_provider.dart';
import 'package:invoizo/modules/auth/controller/auth_controller.dart';
import 'package:invoizo/modules/auth/repository/auth_repository.dart';
import 'package:invoizo/modules/history/controller/history_controller.dart';
import 'package:invoizo/modules/history/repository/invoice_repository.dart';
import 'package:invoizo/modules/home/view/home_scaffold.dart';
import 'package:invoizo/modules/login/view/login_screen.dart';
import 'package:invoizo/modules/subscription/controller/subscription_controller.dart';
import 'package:invoizo/modules/subscription/repository/subscription_repository.dart';
import 'package:invoizo/modules/subscription/services/supabase_subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Initialize repositories
  final authRepo = AuthRepository();
  await authRepo.init();

  final subscriptionRepo = SubscriptionRepository();
  await subscriptionRepo.init();

  final invoiceRepo = InvoiceRepository();
  await invoiceRepo.init();

  // Initialize Supabase if credentials are provided
  await SupabaseSubscriptionService.initializeIfConfigured();

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        subscriptionRepositoryProvider.overrideWithValue(subscriptionRepo),
        invoiceRepositoryProvider.overrideWithValue(invoiceRepo),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'PhysioTally - Invoicing for Physiotherapists',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: authState.isLoggedIn ? const HomeScaffold() : const LoginScreen(),
    );
  }
}
