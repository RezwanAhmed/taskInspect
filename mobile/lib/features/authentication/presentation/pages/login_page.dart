import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/authentication/domain/entities/unsynced_changes.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';

/// Email and password sign-in. Errors from the [AuthBloc] are shown under
/// the field they belong to, or above the button.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  /// The delete dialog is open (a second tap must not open another).
  bool _confirming = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_confirming) {
      return;
    }
    FocusScope.of(context).unfocus();
    final bloc = context.read<AuthBloc>();
    if (bloc.state case Unauthenticated(unsynced: final unsynced?) when unsynced.belongToAnother(_email.text)) {
      _confirming = true;
      final confirmed = await _confirmDelete(unsynced);
      _confirming = false;
      if (!confirmed || !mounted) {
        return;
      }
    }
    if (bloc.state case Unauthenticated(isSubmitting: true)) {
      return;
    }
    bloc.add(LoginRequested(email: _email.text, password: _password.text));
  }

  /// Signing in with another account deletes the unsynced changes of the
  /// previous one (privacy first), so ask first.
  Future<bool> _confirmDelete(UnsyncedChanges unsynced) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete unsynced changes?'),
        content: Text('${_changes(unsynced.count)} of ${unsynced.ownerName} ${unsynced.count == 1 ? 'is' : 'are'} '
            'not synced yet. Signing in with another account deletes them from this device.\n\n'
            'To keep them, sign in as ${unsynced.ownerName} first and wait until they are synced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete and sign in'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static String _changes(int count) => count == 1 ? '1 change' : '$count changes';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final current = state is Unauthenticated ? state : const Unauthenticated();
                  final submitting = current.isSubmitting;
                  String? errorFor(String field) => current.errorField == field ? current.errorMessage : null;
                  final generalError = current.errorField == null ? current.errorMessage : null;
                  return AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.fact_check_outlined, size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('Sign in', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text('to TaskInspect', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 32),
                        if (current.unsynced case final unsynced?) ...[
                          Card(
                            key: const Key('login-unsynced'),
                            color: theme.colorScheme.errorContainer,
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: const Icon(Icons.cloud_upload_outlined),
                              title: Text('${_changes(unsynced.count)} not synced yet'),
                              subtitle: Text('Sign in as ${unsynced.ownerName} to keep them. '
                                  'Signing in with another account deletes them.'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          key: const Key('login-email'),
                          controller: _email,
                          enabled: !submitting,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(labelText: 'Email', errorText: errorFor('email')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('login-password'),
                          controller: _password,
                          enabled: !submitting,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            errorText: errorFor('password'),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (generalError != null) ...[
                          Text(
                            generalError,
                            key: const Key('login-error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 16),
                        ],
                        FilledButton(
                          key: const Key('login-submit'),
                          onPressed: submitting ? null : _submit,
                          child: submitting
                              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
