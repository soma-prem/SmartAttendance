import 'dart:convert';

import 'package:flutter/material.dart';

class SidebarProfileHeader extends StatelessWidget {
  final String pnr;
  final String displayName;
  final String? subtitle;
  final String? profilePhotoBase64;
  final String? backgroundPhotoBase64;
  final String? staticAvatarAssetPath;
  final bool staticAvatarRect;
  final bool disableBackgroundImage;
  final bool isSavingPhoto;
  final bool isSavingBackground;
  final VoidCallback? onEditPhoto;
  final VoidCallback? onEditBackground;
  final bool showEditButtons;

  const SidebarProfileHeader({
    super.key,
    required this.pnr,
    required this.displayName,
    this.subtitle,
    this.profilePhotoBase64,
    this.backgroundPhotoBase64,
    this.staticAvatarAssetPath,
    this.staticAvatarRect = false,
    this.disableBackgroundImage = false,
    this.isSavingPhoto = false,
    this.isSavingBackground = false,
    this.onEditPhoto,
    this.onEditBackground,
    this.showEditButtons = false,
  });

  ImageProvider? _decodeBase64Image(String? b64) {
    if (b64 == null || b64.trim().isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  ImageProvider? _profileImageProvider() {
    final b64 = profilePhotoBase64;
    return _decodeBase64Image(b64);
  }

  ImageProvider? _backgroundImageProvider() {
    return _decodeBase64Image(backgroundPhotoBase64);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileProvider = _profileImageProvider();
    final bgProvider = _backgroundImageProvider();

    // Slightly taller to avoid tiny bottom overflows on some devices/font scales.
    const headerHeight = 262.0;
    const bgHeight = 125.0;
    const avatarRadius = 46.0;
    const rectAvatarWidth = 132.0;
    const rectAvatarHeight = 62.0;

    final avatarHeight = staticAvatarRect ? rectAvatarHeight : avatarRadius * 2;
    final avatarOverlap = staticAvatarRect ? rectAvatarHeight / 2 : avatarRadius;
    final avatarTop = bgHeight - (avatarHeight / 2);

    return SizedBox(
      height: headerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bgHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: disableBackgroundImage
                            ? theme.primaryColor
                            : const Color(0xFF0F172A),
                      ),
                      child: disableBackgroundImage
                          ? const SizedBox.shrink()
                          : (bgProvider != null
                              ? Image(
                                  image: bgProvider,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/images/sidebar_bg.png',
                                  fit: BoxFit.cover,
                                )),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            (disableBackgroundImage
                                    ? theme.primaryColor
                                    : Colors.black)
                                .withValues(alpha: 0.12),
                            (disableBackgroundImage
                                    ? theme.primaryColor
                                    : Colors.black)
                                .withValues(alpha: 0.38),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showEditButtons &&
                      (onEditBackground != null || isSavingBackground))
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _EditCircleButton(
                        isBusy: isSavingBackground,
                        onTap: isSavingBackground ? null : onEditBackground,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: bgHeight - 20,
            left: 14,
            right: 14,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: EdgeInsets.fromLTRB(14, avatarOverlap + 18, 14, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName.trim().isEmpty ? 'User' : displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'PNR: $pnr',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: avatarTop,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!staticAvatarRect)
                    CircleAvatar(
                      radius: avatarRadius + 3,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor:
                            theme.primaryColor.withValues(alpha: 0.12),
                        backgroundImage: profileProvider,
                        child: profileProvider == null
                            ? Icon(
                                Icons.person,
                                size: 46,
                                color: theme.primaryColor,
                              )
                            : null,
                      ),
                    )
                  else
                    Container(
                      width: rectAvatarWidth + 8,
                      height: rectAvatarHeight + 8,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.08),
                          ),
                          child: (staticAvatarAssetPath ?? '').trim().isNotEmpty
                              ? Image.asset(
                                  staticAvatarAssetPath!.trim(),
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (showEditButtons && (onEditPhoto != null || isSavingPhoto))
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _EditCircleButton(
                        isBusy: isSavingPhoto,
                        onTap: isSavingPhoto ? null : onEditPhoto,
                        backgroundColor: theme.primaryColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCircleButton extends StatelessWidget {
  final bool isBusy;
  final VoidCallback? onTap;
  final Color backgroundColor;

  const _EditCircleButton({
    required this.isBusy,
    required this.onTap,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: isBusy
            ? const Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.camera_alt,
                size: 18,
                color: Colors.white,
              ),
      ),
    );
  }
}
