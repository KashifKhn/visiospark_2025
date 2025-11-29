import 'package:flutter/material.dart';
import '../core/constants/constants.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/change_password_screen.dart';

import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/chat/new_chat_screen.dart';

import '../screens/forum/forum_list_screen.dart';
import '../screens/forum/post_detail_screen.dart';
import '../screens/forum/create_post_screen.dart';
import '../screens/forum/edit_post_screen.dart';
import '../models/forum_model.dart';

import '../screens/ai/ai_chat_screen.dart';

import '../screens/settings/settings_screen.dart';

import '../screens/static/about_screen.dart';
import '../screens/static/privacy_policy_screen.dart';
import '../screens/static/terms_screen.dart';
import '../screens/static/support_screen.dart';

import '../screens/events/events_list_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/events/my_events_screen.dart';
import '../screens/events/event_form_screen.dart';
import '../screens/events/event_registrations_screen.dart';
import '../screens/events/event_feedback_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes {
    return {
      AppConstants.splashRoute: (context) => const SplashScreen(),
      AppConstants.loginRoute: (context) => const LoginScreen(),
      AppConstants.registerRoute: (context) => const RegisterScreen(),
      AppConstants.forgotPasswordRoute: (context) => const ForgotPasswordScreen(),
      AppConstants.homeRoute: (context) => const HomeScreen(),
      AppConstants.dashboardRoute: (context) => const DashboardScreen(),
      AppConstants.profileRoute: (context) => const ProfileScreen(),
      AppConstants.editProfileRoute: (context) => const EditProfileScreen(),
      AppConstants.changePasswordRoute: (context) => const ChangePasswordScreen(),
      AppConstants.chatListRoute: (context) => const ChatListScreen(),
      AppConstants.forumRoute: (context) => const ForumListScreen(),
      AppConstants.createPostRoute: (context) => const CreatePostScreen(),
      AppConstants.aiChatRoute: (context) => const AIChatScreen(),
      AppConstants.settingsRoute: (context) => const SettingsScreen(),
      AppConstants.aboutRoute: (context) => const AboutScreen(),
      AppConstants.privacyPolicyRoute: (context) => const PrivacyPolicyScreen(),
      AppConstants.termsRoute: (context) => const TermsScreen(),
      AppConstants.supportRoute: (context) => const SupportScreen(),
      
      // Event routes (simple ones without arguments)
      AppConstants.eventsRoute: (context) => const EventsListScreen(),
      AppConstants.myEventsRoute: (context) => const MyEventsScreen(),
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.chatRoomRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args != null && args['roomId'] != null) {
          return MaterialPageRoute(
            builder: (context) => const ChatRoomScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (context) => const ChatRoomScreen(),
        );

      case AppConstants.postDetailRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            postId: args?['postId'] ?? '',
          ),
        );

      case AppConstants.newChatRoute:
        return MaterialPageRoute(
          builder: (context) => const NewChatScreen(),
        );

      case '/forum/edit':
        final post = settings.arguments as ForumPostModel?;
        if (post != null) {
          return MaterialPageRoute(
            builder: (context) => EditPostScreen(post: post),
          );
        }
        return null;

      // Event routes with arguments
      case AppConstants.eventDetailRoute:
        final eventId = settings.arguments as String?;
        if (eventId != null) {
          return MaterialPageRoute(
            builder: (context) => EventDetailScreen(eventId: eventId),
          );
        }
        return null;

      case AppConstants.createEventRoute:
        return MaterialPageRoute(
          builder: (context) => const EventFormScreen(),
        );

      case AppConstants.editEventRoute:
        final eventId = settings.arguments as String?;
        if (eventId != null) {
          return MaterialPageRoute(
            builder: (context) => EventFormScreen(eventId: eventId),
          );
        }
        return null;

      case AppConstants.eventRegistrationsRoute:
        final eventId = settings.arguments as String?;
        if (eventId != null) {
          return MaterialPageRoute(
            builder: (context) => EventRegistrationsScreen(eventId: eventId),
          );
        }
        return null;

      case AppConstants.eventFeedbackRoute:
        final eventId = settings.arguments as String?;
        if (eventId != null) {
          return MaterialPageRoute(
            builder: (context) => EventFeedbackScreen(eventId: eventId),
          );
        }
        return null;

      default:
        final builder = routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(builder: builder);
        }
        
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found: ${settings.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
