import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/profile_screen.dart';

/// Avatar del usuario para la esquina superior derecha. Abre el perfil.
class ProfileAvatarButton extends StatelessWidget {
  final VoidCallback? onReturn;

  const ProfileAvatarButton({super.key, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final path = userProvider.profileImagePath;
    ImageProvider? avatarImage;

    if (path.isNotEmpty) {
      if (path.startsWith('http')) {
        avatarImage = NetworkImage(path);
      } else {
        final file = File(path);
        if (file.existsSync()) avatarImage = FileImage(file);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16.0, left: 8.0),
      child: Tooltip(
        message: 'Mi perfil',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => onReturn?.call());
          },
          child: avatarImage != null
              ? CircleAvatar(radius: 18, backgroundImage: avatarImage)
              : userProvider.getDefaultAvatar(radius: 18, color: Colors.white),
        ),
      ),
    );
  }
}
