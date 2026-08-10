import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/config/api_configuration.dart';
import 'package:sosyo_bel/core/navigation/app_flow.dart';
import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/theme/app_theme.dart';
import 'package:sosyo_bel/features/auth/data/authentication_session_store.dart';
import 'package:sosyo_bel/features/auth/data/remote_auth_repository.dart';
import 'package:sosyo_bel/features/auth/domain/auth_repository.dart';
import 'package:sosyo_bel/features/application/data/remote_application_repository.dart';
import 'package:sosyo_bel/features/application/domain/application_repository.dart';
import 'package:sosyo_bel/features/home/data/remote_work_items_repository.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';

/// Uygulamanın tema, yönlendirme ve başlangıç ekranını tanımlayan kök widget'ı.
class SosyoBelApp extends StatefulWidget {
  const SosyoBelApp({
    this.authRepository,
    this.applicationRepository,
    this.workItemsRepository,
    super.key,
  });

  /// Testlerin gerçek sunucuya çıkmadan kontrollü auth davranışı vermesini sağlar.
  final AuthRepository? authRepository;
  final ApplicationRepository? applicationRepository;
  final WorkItemsRepository? workItemsRepository;

  @override
  State<SosyoBelApp> createState() => _SosyoBelAppState();
}

class _SosyoBelAppState extends State<SosyoBelApp> {
  late final AuthRepository _authRepository;
  late final ApplicationRepository _applicationRepository;
  late final WorkItemsRepository _workItemsRepository;

  @override
  void initState() {
    super.initState();
    final remoteRepositories =
        widget.authRepository == null ||
            widget.applicationRepository == null ||
            widget.workItemsRepository == null
        ? _createRemoteRepositories()
        : null;
    _authRepository =
        widget.authRepository ?? remoteRepositories!.authRepository;
    _applicationRepository =
        widget.applicationRepository ??
        remoteRepositories!.applicationRepository;
    _workItemsRepository =
        widget.workItemsRepository ?? remoteRepositories!.workItemsRepository;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sosyo-Bel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AppFlow(
        authRepository: _authRepository,
        applicationRepository: _applicationRepository,
        workItemsRepository: _workItemsRepository,
      ),
    );
  }

  _AppRepositories _createRemoteRepositories() {
    final sessionStore = SecureAuthenticationSessionStore.platform();
    final apiClient = ApiClient(
      configuration: ApiConfiguration.fromEnvironment(),
      tokenStore: sessionStore,
    );
    return _AppRepositories(
      authRepository: RemoteAuthRepository(
        apiClient: apiClient,
        sessionStore: sessionStore,
      ),
      applicationRepository: RemoteApplicationRepository(apiClient),
      workItemsRepository: RemoteWorkItemsRepository(apiClient),
    );
  }
}

class _AppRepositories {
  const _AppRepositories({
    required this.authRepository,
    required this.applicationRepository,
    required this.workItemsRepository,
  });

  final AuthRepository authRepository;
  final ApplicationRepository applicationRepository;
  final WorkItemsRepository workItemsRepository;
}
