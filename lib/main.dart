import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'utils/app_colors.dart';
import 'screens/auth/login_screen.dart';

import 'bindings/initial_binding.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Online Exam App',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(), // Global dep injection
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.text, fontFamily: 'Roboto'),
          bodyMedium: TextStyle(color: AppColors.text, fontFamily: 'Roboto'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const LoginScreen())
      ],
    );
  }
}
