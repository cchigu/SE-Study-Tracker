import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/session_store.dart';

/// Sign in / create account when signed out; account info + sign out when signed in.
class ProfileScreen extends StatelessWidget {
  final SessionStore store;
  const ProfileScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snap) {
          final user = snap.data;
          return user == null ? _SignInForm(store: store) : _AccountView(user: user, store: store);
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ signed in

class _AccountView extends StatelessWidget {
  final User user;
  final SessionStore store;
  const _AccountView({required this.user, required this.store});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your sessions stay safe in your account and come back when you sign in again. '
          'They will be removed from this phone until then.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.displayName;
    final email = user.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(child: AccountAvatar(user: user, radius: 44)),
        const SizedBox(height: 16),
        if (name != null && name.isNotEmpty)
          Text(name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        Text(email, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final n = store.sessions.length;
            return Card(
              child: ListTile(
                leading: Icon(Icons.cloud_done, color: theme.colorScheme.primary),
                title: const Text('Synced to the cloud'),
                subtitle: Text('$n ${n == 1 ? 'session' : 'sessions'} saved to your account'),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          onPressed: () => _signOut(context),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- signed out

class _SignInForm extends StatefulWidget {
  final SessionStore store;
  const _SignInForm({required this.store});

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false; // false = sign in, true = create account
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() => _run(() async {
        final email = _email.text.trim();
        final password = _password.text;
        if (email.isEmpty || password.isEmpty) {
          throw FirebaseAuthException(code: 'missing-fields');
        }
        final auth = FirebaseAuth.instance;
        if (_creating) {
          await auth.createUserWithEmailAndPassword(email: email, password: password);
        } else {
          await auth.signInWithEmailAndPassword(email: email, password: password);
        }
      });

  Future<void> _google() => _run(() async {
        try {
          await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
        } on FirebaseAuthException catch (e) {
          // Closing the Google window isn't an error worth showing.
          if (e.code.contains('cancel')) return;
          rethrow;
        }
      });

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Type your email above first, then tap "Forgot password?".');
      return;
    }
    await _run(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    });
  }

  String _friendly(FirebaseAuthException e) => switch (e.code) {
        'missing-fields' => 'Enter your email and password.',
        'invalid-email' => "That email address doesn't look right.",
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account with that email already exists. Try signing in.',
        'weak-password' => 'Pick a password with at least 6 characters.',
        'network-request-failed' => 'No internet connection.',
        'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
        _ => e.message ?? 'Something went wrong (${e.code}).',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.cloud_sync_outlined, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          _creating ? 'Create an account' : 'Sign in to sync',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Your study time is saved on this phone. Sign in to back it up to the cloud '
          'and keep it if you change phones. Sessions you already logged will be uploaded.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),

        // Google
        FilledButton.tonalIcon(
          icon: const Icon(Icons.g_mobiledata, size: 32),
          label: const Text('Continue with Google'),
          onPressed: _busy ? null : _google,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or use email', style: theme.textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),

        // Email + password
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _submitEmail(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            helperText: _creating ? 'At least 6 characters' : null,
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        if (!_creating)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _forgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _submitEmail,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(_creating ? 'Create account' : 'Sign in'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _creating = !_creating;
                    _error = null;
                  }),
          child: Text(_creating
              ? 'Already have an account? Sign in'
              : "Don't have an account? Create one"),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ shared widgets

/// Round avatar: Google photo if there is one, otherwise the first letter.
class AccountAvatar extends StatelessWidget {
  final User user;
  final double radius;
  const AccountAvatar({super.key, required this.user, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = user.photoURL;
    final source = (user.displayName?.isNotEmpty ?? false) ? user.displayName! : (user.email ?? '?');
    final initial = source.isEmpty ? '?' : source[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: photo == null ? null : NetworkImage(photo),
      child: Text(initial,
          style: TextStyle(fontSize: radius * 0.9, color: scheme.onPrimaryContainer)),
    );
  }
}

/// The profile icon for the top-right of each tab.
class AccountButton extends StatelessWidget {
  final SessionStore store;
  const AccountButton({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        return IconButton(
          tooltip: user == null ? 'Sign in' : 'Profile',
          icon: user == null
              ? const Icon(Icons.account_circle_outlined, size: 30)
              : AccountAvatar(user: user, radius: 15),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(store: store)),
          ),
        );
      },
    );
  }
}
