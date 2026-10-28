import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'providers/customer_provider.dart';
import 'providers/order_provider.dart';
import 'providers/ledger_provider.dart';
import 'screens/splash/splash_screen.dart'; // سپلیش اسکرین کا امپورٹ

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // فائر بیس کی انیشلائزیشن (Firebase Initialization)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // گاہکوں کا ڈیٹا شروع میں ہی فیچ (fetch) کرنے کے لیے
        ChangeNotifierProvider(
          create: (_) => CustomerProvider()..fetchCustomers(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LedgerProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
          ),
          scaffoldBackgroundColor: AppColors.lightBg,
          appBarTheme: const AppBarTheme(
            toolbarHeight: 53.0,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
        // آغاز سپلیش اسکرین (Splash Screen) سے ہوگا
        home: const SplashScreen(),
      ),
    );
  }
}