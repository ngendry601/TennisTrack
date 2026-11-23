import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppBar_Perso extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback onProfilePressed;
  const AppBar_Perso({
    super.key,
    required this.title,
    required this.onProfilePressed,
    this.actions = const [],
  });

  @override
  State<AppBar_Perso> createState() => _AppBar_PersoState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppBar_PersoState extends State<AppBar_Perso> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppBar_Perso oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.headerGradient),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
        // Le logo est foncé : son fond clair le garde lisible sur l'en-tête.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            semanticLabel: 'Logo TennisTrack',
          ),
        ),
      ),
      leadingWidth: 54,
      centerTitle: true,
      title: Text(widget.title),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: widget.onProfilePressed,
        ),
        ...widget.actions,
      ],
    );
  }
}
