import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/home_page.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
