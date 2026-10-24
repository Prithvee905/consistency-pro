import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TextEditingController? _name;
  bool _busy = false;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(okMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    _name ??= TextEditingController(text: store.displayName);
    final url = '$kShareBaseUrl/u/${store.slug}';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile and sharing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name (shown on share cards)',
            ),
            onChanged: store.setDisplayName,
          ),
          const SizedBox(height: 28),
          Text('Public streak page', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Get a link you can put in your Instagram bio or send to friends. '
            'It shows only your name, your habit names, streaks and the days you logged. '
            'Never your location and never your task titles. You can switch it off anytime.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (!store.cloud.ready)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Public links need the Firebase setup (see README). Everything else works without it.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          if (store.published) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(url, style: theme.textTheme.titleSmall),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: url));
                      messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Share.share('Follow my streaks: $url'),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: _busy || !store.cloud.ready
                ? null
                : () => _run(store.publish,
                    store.published ? 'Public page updated' : 'Public page is live'),
            child: Text(store.published ? 'Update my public page' : 'Create public link'),
          ),
          if (store.published) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _run(store.unpublish, 'Public page removed'),
              child: const Text('Stop sharing'),
            ),
          ],
          const SizedBox(height: 32),
          Text('Alarms', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'If alarms arrive late, allow notifications and "Alarms & reminders" for this app in your phone settings, '
            'and turn off battery optimisation for it.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => store.notifications.requestPermissions(),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Check alarm permission'),
          ),
          const SizedBox(height: 32),
          Text(
            'Your habits, tasks and logs are stored on this phone only.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
