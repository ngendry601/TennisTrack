import 'package:flutter/material.dart';

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