import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/state/auth_provider.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final api = ref.watch(apiClientProvider);
    final roleLabel = authState.role?.label ?? 'Meetday';

    return Scaffold(
      appBar: AppBar(
        title: Text(roleLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good to have you here.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${roleLabel.toLowerCase()} workspace is ready for the next step.',
              style: const TextStyle(color: Color(0xFF667085), height: 1.45),
            ),
            const SizedBox(height: 24),
            FutureBuilder<bool>(
              future: api.checkConnection(),
              builder: (context, snapshot) {
                final isConnected = snapshot.data == true;
                final isChecking =
                    snapshot.connectionState == ConnectionState.waiting;
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(
                      isConnected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_queue_rounded,
                      color: isConnected
                          ? const Color(0xFF12B76A)
                          : const Color(0xFF98A2B3),
                    ),
                    title: const Text('Meetday backend'),
                    subtitle: Text(
                      isChecking
                          ? 'Checking connection...'
                          : isConnected
                          ? 'Connected'
                          : 'Unavailable',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Communities'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
