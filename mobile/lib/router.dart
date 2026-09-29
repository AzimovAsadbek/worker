import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/session.dart';
import 'core/providers.dart';
import 'core/widgets/common.dart';
import 'features/auth/name_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/phone_screen.dart';
import 'features/common/notifications_screen.dart';
import 'features/common/settings_screen.dart';
import 'features/company/add_member_screen.dart';
import 'features/company/company_profile_screen.dart';
import 'features/company/company_shell.dart';
import 'features/company/dashboard_screen.dart';
import 'features/company/disputes_screen.dart';
import 'features/company/member_detail_screen.dart';
import 'features/company/more_screen.dart';
import 'features/company/shift_review_screen.dart';
import 'features/company/shifts_screen.dart';
import 'features/company/sites_screen.dart';
import 'features/company/tasks_screens.dart';
import 'features/company/vacancies_screens.dart';
import 'features/company/workers_screen.dart';
import 'features/onboarding/create_company_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/worker/edit_profile_screen.dart';
import 'features/worker/jobs_screen.dart';
import 'features/worker/my_applications_screen.dart';
import 'features/worker/my_work_screen.dart';
import 'features/worker/profile_screen.dart';
import 'features/worker/shift_detail_screen.dart';
import 'features/worker/task_detail_screen.dart';
import 'features/worker/today_screen.dart';
import 'features/worker/vacancy_detail_screen.dart';
import 'features/worker/worker_shell.dart';

/// Bridges Riverpod session changes to GoRouter's refreshListenable.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (prev, next) {
      if (prev?.phase != next.phase || prev?.context != next.context || prev?.me?.hasName != next.me?.hasName || prev?.isNewUser != next.isNewUser) notifyListeners();
    });
  }
}

const _authPaths = {'/login', '/otp'};

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      switch (s.phase) {
        case SessionPhase.loading:
          return loc == '/splash' ? null : '/splash';
        case SessionPhase.loggedOut:
          return _authPaths.contains(loc) ? null : '/login';
        case SessionPhase.ready:
          if (!(s.me?.hasName ?? false)) return loc == '/name' ? null : '/name';
          final home = s.inCompanyMode ? '/company/dashboard' : '/worker/today';
          if (s.isNewUser && (s.me?.memberships.isEmpty ?? true)) {
            return loc == '/welcome' || loc == '/create-company' ? null : '/welcome';
          }
          if (loc == '/splash' || _authPaths.contains(loc) || loc == '/name' || loc == '/welcome') return home;
          if (loc.startsWith('/company') && !s.inCompanyMode) return '/worker/today';
          if (loc.startsWith('/worker') && s.inCompanyMode) return '/company/dashboard';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: LoadingView())),
      GoRoute(path: '/login', builder: (_, _) => const PhoneScreen()),
      GoRoute(path: '/otp', builder: (_, st) => OtpScreen(phone: st.extra as String? ?? '')),
      GoRoute(path: '/name', builder: (_, _) => const NameScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/create-company', builder: (_, _) => const CreateCompanyScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),

      // ───── worker ─────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => WorkerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/worker/today', builder: (_, _) => const TodayScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/worker/jobs', builder: (_, _) => const JobsScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/worker/work', builder: (_, st) => MyWorkScreen(initialTab: st.uri.queryParameters['tab'] == 'tasks' ? 1 : 0)),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/worker/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/vacancy/:id', builder: (_, st) => VacancyDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/applications', builder: (_, _) => const MyApplicationsScreen()),
      GoRoute(path: '/shift/:id', builder: (_, st) => ShiftDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/task/:id', builder: (_, st) => TaskDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),

      // ───── company (admin / manager / foreman) ─────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CompanyShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/company/dashboard', builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/company/workers', builder: (_, _) => const WorkersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/company/shifts', builder: (_, _) => const ShiftsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/company/more', builder: (_, _) => const MoreScreen())]),
        ],
      ),
      GoRoute(path: '/company/workers/add', builder: (_, _) => const AddMemberScreen()),
      GoRoute(path: '/company/workers/:id', builder: (_, st) => MemberDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/company/shift/:id', builder: (_, st) => ShiftReviewScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/company/task/:id', builder: (_, st) => TaskReviewScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/company/vacancy/:id', builder: (_, st) => VacancyApplicationsScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/company/application/:id', builder: (_, st) => ApplicationDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/company/more/sites', builder: (_, st) => SitesScreen(onboarding: st.uri.queryParameters['onboarding'] == '1')),
      GoRoute(path: '/company/more/sites/new', builder: (_, st) => SiteFormScreen(projectId: st.uri.queryParameters['projectId'] ?? '')),
      GoRoute(path: '/company/more/tasks', builder: (_, _) => const CompanyTasksScreen()),
      GoRoute(path: '/company/more/tasks/new', builder: (_, _) => const CreateTaskScreen()),
      GoRoute(path: '/company/more/vacancies', builder: (_, _) => const CompanyVacanciesScreen()),
      GoRoute(path: '/company/more/vacancies/new', builder: (_, _) => const CreateVacancyScreen()),
      GoRoute(path: '/company/more/disputes', builder: (_, _) => const DisputesScreen()),
      GoRoute(path: '/company/more/profile', builder: (_, _) => const CompanyProfileScreen()),
    ],
  );
});
