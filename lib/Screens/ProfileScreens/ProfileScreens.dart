import 'package:cached_network_image/cached_network_image.dart';
import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Providers/ProfileProvider/ProfileProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/changePasswordScreen.dart';
import 'package:chess_cash/Screens/LeaderBoard/EloLeaderBoard.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Profilescreens extends StatefulWidget {
  const Profilescreens({super.key});

  @override
  State<Profilescreens> createState() => _ProfilescreensState();
}

class _ProfilescreensState extends State<Profilescreens> {
  TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProfileProvider>(context, listen: false);
      provider.fetchUserProfile().then((_) {
        _nameController = TextEditingController(text: provider.name ?? '');
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showLogoutConfirmationDialog(ProfileProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppConstants.confirmLogout),
          content: const Text(AppConstants.sureLogOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppConstants.cancel),
            ),
            TextButton(
              onPressed: () {
                provider.logout(context);
              },
              child: const Text(
                AppConstants.logout,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppConstants.profile),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () => push(context, const EloLeaderboard()),
              child: const Icon(Icons.leaderboard),
            ),
          )
        ],
        backgroundColor: ColorResources.primaryColor,
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          if (profileProvider.isLoading) {
            return const Center(child: Loader());
          }

          // Ensure controller always reflects current name from provider
          _nameController.text = profileProvider.name ?? '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 66,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profileProvider.profileImageUrl ?? '',
                              fit: BoxFit.cover,
                              width: 132,
                              height: 132,
                              placeholder: (context, url) => Image.asset(
                                'assets/images/pawn_image.jpg',
                                fit: BoxFit.cover,
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () async {
                              await profileProvider.updateProfileImage();
                              await profileProvider.fetchUserProfile();
                            },
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.edit,
                                  size: 15, color: ColorResources.primaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Helper.heightSizedBox(26),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: AppConstants.userName,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Helper.heightSizedBox(8),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(
                        text: profileProvider.email ?? ''),
                    decoration: const InputDecoration(
                      labelText: AppConstants.email,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () async {
                      await profileProvider.updateUserDetails(
                        newName: _nameController.text.trim(),
                      );
                      await profileProvider.fetchUserProfile();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: ColorResources.secondaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppConstants.updateProfile,
                        style: TextStyle(color: ColorResources.secondaryColor),
                      ),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: ColorResources.secondaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Change Password',
                        style: TextStyle(color: ColorResources.secondaryColor),
                      ),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming Soon')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: ColorResources.secondaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppConstants.inviteFriends,
                        style: TextStyle(color: ColorResources.secondaryColor),
                      ),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () => _showLogoutConfirmationDialog(profileProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        AppConstants.logout,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Delete Account"),
                          content: const Text(
                              "Are you sure you want to delete your account?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Provider.of<ProfileProvider>(context,
                                        listen: false)
                                    .deleteAccount(context);
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white),
                              child: const Text(
                                "Delete",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        AppConstants.deleteAccount,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
