import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/supabase_service.dart';

class SalesConciergeLauncher extends StatefulWidget {
  const SalesConciergeLauncher({super.key, required this.child});

  final Widget child;

  @override
  State<SalesConciergeLauncher> createState() => _SalesConciergeLauncherState();
}

class _SalesConciergeLauncherState extends State<SalesConciergeLauncher>
    with SingleTickerProviderStateMixin {
  static const _seenKey = 'nile_tropical_concierge_seen_v1';

  String get _visitorSeenKey {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) return '${_seenKey}_user_$userId';
    } catch (_) {}
    return '${_seenKey}_guest';
  }

  late final AnimationController _controller;
  Timer? _welcomeTimer;
  bool _open = false;
  bool _firstVisit = false;

  static const _questions = <_ConciergePrompt>[
    _ConciergePrompt('Find something for my skin', Icons.spa_outlined),
    _ConciergePrompt('Show me products under UGX 10,000', Icons.payments_outlined),
    _ConciergePrompt('Tell me about Shea Butter', Icons.eco_outlined),
    _ConciergePrompt('I need sanitizer for my office', Icons.clean_hands_outlined),
    _ConciergePrompt('What does Nile Tropical sell?', Icons.storefront_outlined),
    _ConciergePrompt('How can I contact Nile Tropical?', Icons.call_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      lowerBound: 0,
      upperBound: 1,
    );
    _prepareWelcome();
  }

  Future<void> _prepareWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_visitorSeenKey) ?? false;
    if (!mounted) return;
    setState(() => _firstVisit = !seen);
    if (!seen) {
      _welcomeTimer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() => _open = true);
        _controller.forward();
        prefs.setBool(_visitorSeenKey, true);
      });
    }
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    setState(() => _open = false);
    _controller.reverse();
  }

  void _ask(String prompt) {
    context.push('/concierge', extra: prompt);
    _close();
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: 18,
          child: SafeArea(
            top: false,
            left: false,
            child: _buildLauncher(context),
          ),
        ),
      ],
    );
  }

  Widget _buildLauncher(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width < 430 ? width - 32 : 360.0;
    final path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    if (path.startsWith('/admin') || path == '/login' || path == '/signup' || path == '/concierge') {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open)
            SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutCubic,
              ),
              axisAlignment: 1,
              child: FadeTransition(
                opacity: _controller,
                child: Container(
                  width: panelWidth,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: NileColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: NileColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: NileColors.primary.withValues(alpha: 0.16),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _welcomePanel(context),
                ),
              ),
            ),
          _bubbleButton(context),
        ],
      ),
    );
  }

  Widget _welcomePanel(BuildContext context) {
    final day = DateTime.now().day;
    final offset = day % _questions.length;
    final prompts = List<_ConciergePrompt>.generate(
      _questions.length,
      (i) => _questions[(i + offset) % _questions.length],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 430),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 10, 14),
            color: NileColors.primary,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.auto_awesome, color: NileColors.primary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nile Tropical Concierge',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'I’m here whenever you need me.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hide',
                  onPressed: _close,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _firstVisit
                    ? 'Welcome to Nile Tropical 👋'
                    : 'What can I help you find?',
                style: NileTypography.titleMedium,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ask me about products, Shea Butter, prices, the company, wholesale, markets or how to contact us.',
                style: TextStyle(
                  color: NileColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              children: [
                ...prompts.map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Material(
                      color: NileColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => _ask(q.text),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(q.icon, size: 18, color: NileColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  q.text,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 17,
                                color: NileColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbleButton(BuildContext context) {
    return Semantics(
      button: true,
      label: _open ? 'Hide Nile Tropical Concierge' : 'Open Nile Tropical Concierge',
      child: Material(
        color: NileColors.primary,
        elevation: 7,
        shadowColor: NileColors.primary.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(
              horizontal: _open ? 14 : 15,
              vertical: 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open ? Icons.keyboard_arrow_down : Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
                if (!_open) ...[
                  const SizedBox(width: 7),
                  const Text(
                    'Need help?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConciergePrompt {
  const _ConciergePrompt(this.text, this.icon);

  final String text;
  final IconData icon;
}
