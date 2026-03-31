import 'dart:async';
import 'package:chottu_link/chottu_link.dart';
import 'package:chottu_link/dynamic_link/cl_dynamic_link_behaviour.dart';
import 'package:chottu_link/dynamic_link/cl_dynamic_link_parameters.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/navigation.dart';
import 'package:novopharma/screens/notifications_screen.dart';

import 'package:novopharma/screens/actualites_screen.dart';
import 'package:novopharma/screens/formations_screen.dart';
import 'package:novopharma/screens/sales_history_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/badges_screen.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/screens/manual_sale_screen.dart';
import 'package:novopharma/screens/goal_details_screen.dart';
import 'package:novopharma/screens/actualite_details_screen.dart';
import 'package:novopharma/screens/formation_details_screen.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/models/blog_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChottuLinkService {
  static final ChottuLinkService _instance = ChottuLinkService._internal();
  factory ChottuLinkService() => _instance;
  ChottuLinkService._internal();

  void initialize() {
    // Listen for incoming links (handles both cold start and background/foreground)
    ChottuLink.onLinkReceived.listen((String link) {
      if (link.isNotEmpty) {
        debugPrint('[ChottuLinkService] Received link: $link');
        handleDeepLink(link);
      }
    });

    // Also listen with metadata for more robust handling
    ChottuLink.onLinkReceivedWithMeta.listen((resolvedLink) {
      debugPrint(
        '[ChottuLinkService] Received link with meta: ${resolvedLink.link}',
      );
      if (resolvedLink.link != null && resolvedLink.link!.isNotEmpty) {
        handleDeepLink(resolvedLink.link!);
      }
    });
  }

  Future<void> handleDeepLink(String link) async {
    debugPrint('[ChottuLinkService] Processing deep link: $link');
    final Uri uri = Uri.parse(link);
    final String path = uri.path;
    final Map<String, String> queryParams = uri.queryParameters;

    debugPrint('[ChottuLinkService] Query parameters received: $queryParams');

    final BuildContext? context = appNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('[ChottuLinkService] Context is null, delaying...');
      Future.delayed(
        const Duration(milliseconds: 500),
        () => handleDeepLink(link),
      );
      return;
    }

    // Normalize path by removing trailing slash if exists
    String normalizedPath = path.startsWith('/') ? path : '/$path';
    if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
    }
    
    debugPrint('[ChottuLinkService] Normalized path: $normalizedPath');

    // --- ROUTING LOGIC ---
    // Handle: /formation/id/{id} (New format)
    if (normalizedPath.startsWith('/formation/id/')) {
      final formationId = normalizedPath.split('/').last;
      Navigator.pushNamed(context, '/formation/$formationId');
    }
    // Handle: /formation or /formations
    else if (normalizedPath == '/formation' || normalizedPath == '/formations') {
      final id = queryParams['id'];
      if (id != null && id.isNotEmpty) {
        debugPrint('[ChottuLinkService] Redirecting to formation detail with id: $id');
        Navigator.pushNamed(context, '/formation/$id');
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const FormationsScreen()),
          (route) => false,
        );
      }
    } else if (normalizedPath == '/goals' || normalizedPath == '/goal') {
      final id = queryParams['id'];
      if (id != null && id.isNotEmpty) {
        debugPrint('[ChottuLinkService] Redirecting to goal detail with id: $id');
        try {
          final doc = await FirebaseFirestore.instance.collection('goals').doc(id).get();
          if (doc.exists && context.mounted) {
            final goal = Goal.fromFirestore(doc);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GoalDetailsScreen(goal: goal)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GoalsScreen()),
            );
          }
        } catch (e) {
          debugPrint('Error navigating to goal: $e');
        }
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GoalsScreen()),
        );
      }
    } else if (normalizedPath == '/manual-sale' || normalizedPath == '/manual-sales') {
      final productId = queryParams['product-id'] ?? queryParams['product_id'] ?? queryParams['id'];
      if (productId != null && productId.isNotEmpty) {
        debugPrint('[ChottuLinkService] Redirecting from manual-sale to product detail: $productId');
        Navigator.pushNamed(
          context,
          '/product',
          arguments: {'id': productId},
        );
      } else {
        Navigator.pushNamed(context, '/manual-sale');
      }
    } else if (normalizedPath == '/badges' || normalizedPath == '/badge') {
      final id = queryParams['id'];
      Navigator.pushNamed(
        context,
        '/badges',
        arguments: {'id': id},
      );
    } else if (normalizedPath == '/actualite' || normalizedPath == '/actualites') {
      final id = queryParams['id'];
      if (id != null && id.isNotEmpty) {
        debugPrint('[ChottuLinkService] Redirecting to actualite detail with id: $id');
        try {
          final doc = await FirebaseFirestore.instance.collection('blogPosts').doc(id).get();
          if (doc.exists && context.mounted) {
            final post = BlogPost.fromFirestore(doc);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ActualiteDetailsScreen(actualite: post)),
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const ActualitesScreen()),
              (route) => false,
            );
          }
        } catch (e) {
          debugPrint('Error navigating to actualite: $e');
        }
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ActualitesScreen()),
          (route) => false,
        );
      }
    } else if (normalizedPath == '/leaderboard') {
      Navigator.pushNamed(context, '/leaderboard');
    } else if (normalizedPath == '/notifications') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
      );
    } else if (normalizedPath == '/history' || normalizedPath == '/sales-history') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
        (route) => false,
      );
    } else if (normalizedPath == '/pluxee-credits') {
      Navigator.pushNamed(context, '/rewards');
    } else if (normalizedPath == '/profile') {
      Navigator.pushNamed(context, '/profile');
    } else if (normalizedPath == '/product' || normalizedPath.startsWith('/product/')) {
      final id = normalizedPath.startsWith('/product/')
          ? normalizedPath.split('/').last
          : queryParams['id'];
      final sku = queryParams['sku'];
      Navigator.pushNamed(
        context,
        '/product',
        arguments: {'id': id, 'sku': sku},
      );
    } else {
      debugPrint('[ChottuLinkService] Unknown deep link: $normalizedPath');
    }
  }

  /// Generate a unique, short dynamic link in the format:
  /// https://novopharma.chottu.link/formation/id/{formationId}
  Future<String?> createFormationLink(String formationId) async {
    final completer = Completer<String?>();

    try {
      ChottuLink.createDynamicLink(
        parameters: CLDynamicLinkParameters(
          link: Uri.parse(
            "https://novopharma.chottu.link/formation/id/$formationId",
          ),
          domain: "novopharma.chottu.link",
          androidBehaviour: CLDynamicLinkBehaviour.app,
          iosBehaviour: CLDynamicLinkBehaviour.app,
          socialTitle: "Nouvelle Formation disponible !",
          socialDescription: "Veuillez consulter les détails de la formation.",
          socialImageUrl: "https://novopharma.chottu.link/assets/logo.png",
        ),
        onSuccess: (shortLink) {
          debugPrint('[ChottuLinkService] Link Generated: $shortLink');
          completer.complete(shortLink);
        },
        onError: (error) {
          debugPrint('[ChottuLinkService] Link Error: ${error.message}');
          completer.complete(null);
        },
      );
    } catch (e) {
      debugPrint('[ChottuLinkService] Exception: $e');
      completer.complete(null);
    }

    return completer.future;
  }
}
