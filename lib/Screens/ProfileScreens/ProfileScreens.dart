import 'package:cached_network_image/cached_network_image.dart';
import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/legal_urls.dart';
import 'package:chess_cash/Providers/ProfileProvider/ProfileProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/changePasswordScreen.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class Profilescreens extends StatefulWidget {
  const Profilescreens({super.key});

  @override
  State<Profilescreens> createState() => _ProfilescreensState();
}

class _ProfilescreensState extends State<Profilescreens> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<ProfileProvider>(context, listen: false);
      await provider.fetchUserProfile();
      if (!mounted) return;
      if (_nameController.text.isEmpty) {
        _nameController.text = provider.name ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<ProfileProvider>(
          builder: (context, profile, _) {
            if (profile.isLoading && profile.name == null) {
              return const Center(child: Loader());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: ColorResources.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ColorResources.primary,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: ColorResources.elevatedSurface,
                            backgroundImage: (profile.profileImageUrl ?? '')
                                    .isNotEmpty
                                ? CachedNetworkImageProvider(
                                    profile.profileImageUrl!)
                                : const AssetImage(
                                        'assets/images/pawn_image.jpg')
                                    as ImageProvider,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () async {
                              await profile.updateProfileImage();
                              await profile.fetchUserProfile();
                            },
                            child: const CircleAvatar(
                              radius: 14,
                              backgroundColor: ColorResources.primary,
                              child: Icon(
                                Icons.photo_camera,
                                size: 14,
                                color: ColorResources.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name ?? 'Player',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ColorResources.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ColorResources.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _EloPill('${profile.eloRating} Elo'),
                              const SizedBox(width: 8),
                              Text(
                                '${profile.gamesPlayed} games',
                                style: const TextStyle(
                                  color: ColorResources.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _GroupLabel('DISPLAY NAME'),
                _Group(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Username',
                              isDense: true,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await profile.updateUserDetails(
                              newName: _nameController.text.trim(),
                            );
                            await profile.fetchUserProfile();
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 22),
                const _GroupLabel('ACCOUNT'),
                _Group(children: [
                  _RowTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change password',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  _RowTile(
                    icon: Icons.ios_share_rounded,
                    title: 'Invite friends',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming Soon')),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 22),
                const _GroupLabel('PRIVACY'),
                _Group(children: [
                  _RowTile(
                    icon: Icons.policy_outlined,
                    title: 'Privacy policy',
                    onTap: () => launchUrl(
                      Uri.parse(LegalUrls.privacyPolicy),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  _RowTile(
                    icon: Icons.help_outline,
                    title: 'Account deletion help',
                    onTap: () => launchUrl(
                      Uri.parse(LegalUrls.accountDeletion),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ]),
                const SizedBox(height: 28),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => _confirmLogout(profile),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorResources.textPrimary,
                      side: const BorderSide(color: ColorResources.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Log out',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _confirmDelete(profile),
                  child: const Text(
                    'Delete account',
                    style: TextStyle(
                      color: ColorResources.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmLogout(ProfileProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppConstants.confirmLogout),
        content: const Text(AppConstants.sureLogOut),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppConstants.cancel),
          ),
          TextButton(
            onPressed: () => provider.logout(context),
            child: const Text(
              AppConstants.logout,
              style: TextStyle(color: ColorResources.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ProfileProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteAccount(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: ColorResources.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EloPill extends StatelessWidget {
  final String text;
  const _EloPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColorResources.primary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: ColorResources.accentSoft,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: ColorResources.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorResources.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorResources.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 52,
                color: ColorResources.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _RowTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ColorResources.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ColorResources.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: ColorResources.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
