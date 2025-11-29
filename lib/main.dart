import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/supabase_config.dart';
import 'core/constants/constants.dart';

import 'theme/app_theme.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/forum_provider.dart';
import 'providers/ai_provider.dart';

import 'routes/app_routes.dart';

import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  CacheService.init(prefs);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        ChangeNotifierProvider(create: (_) => AuthProvider()),

        ChangeNotifierProvider(create: (_) => UserProvider()),

        ChangeNotifierProvider(create: (_) => ChatProvider()),

        ChangeNotifierProvider(create: (_) => ForumProvider()),

        ChangeNotifierProvider(create: (_) => AIProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'VisioSpark',
            debugShowCheckedModeBanner: false,

            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,

            initialRoute: AppConstants.splashRoute,

            routes: AppRoutes.routes,

            onGenerateRoute: AppRoutes.onGenerateRoute,

            scrollBehavior: const MaterialScrollBehavior().copyWith(
              physics: const BouncingScrollPhysics(),
            ),

            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(
                    mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.4),
                  ),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
